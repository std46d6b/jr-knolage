---
title: "Context: назначение и propagation"
description: "Контракт context.Context, правила передачи по стеку вызовов и границы между запросом, процессом и фоновой задачей."
tags:
  - go
  - context
  - cancellation
  - concurrency
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Context: назначение и propagation

`context.Context` неизменно несёт три вещи: сигнал отмены через `Done()`, время окончания через `Deadline()` и request-scoped значения через `Value()`. Производный context наследует отмену, дедлайн и values родителя. Это дерево направлено от владельца операции к дочерним операциям; потомок не может отменить родителя.

## Зачем это на интервью

В production один HTTP-запрос часто вызывает cache, БД и несколько RPC. Интервьюер ждёт, что кандидат передаст один контекст через весь путь, не потеряет client cancellation и не запустит работу, которая переживёт её владельца случайно.

## Минимум для E4

- [ ] Принимать `ctx context.Context` первым параметром, не `nil`; если API не имеет смысла без контекста, документировать это.
- [ ] Передавать полученный `ctx` дальше, а не заменять его на `Background`/`TODO`.
- [ ] Использовать `context.Background()` только как root процесса/явно независимой операции, `TODO()` — временно при миграции.
- [ ] Проверять cancellation в CPU-bound цикле и при отправке/получении channel.
- [ ] Передавать `r.Context()` в код HTTP handler и контекст RPC в downstream API.

## Углубление для E5/Senior

Propagation — часть контракта границы. Transport извлекает trace/auth metadata из входящего запроса по доверенным правилам, service передаёт `ctx` явно, а adapter использует API с суффиксом `Context` (`QueryContext`, `Do`, gRPC call). Для detached delivery E5 создаёт новую durable job с явными полями и новым process context, а не сохраняет request context после возврата handler.

## Ключевые понятия

| Элемент         | Значение                                       | Правило                                          |
| --------------- | ---------------------------------------------- | ------------------------------------------------ |
| Root context    | `Background`, неотменяемый корень              | Создаёт `main`, тест или явная long-lived задача |
| Derived context | Потомок `WithCancel/Timeout/...`               | Его creator вызывает cancel                      |
| `Done()`        | Channel, закрываемый при отмене                | Наблюдают через `select`; не закрывают вручную   |
| `Err()`         | `Canceled` или `DeadlineExceeded` после `Done` | Удобен для классификации результата              |
| Propagation     | Наследование вниз по дереву                    | Не заменяйте контекст между слоями               |

### Cooperative cancellation

```go
package jobs

import (
	"context"
	"fmt"
)

func Sum(ctx context.Context, values []int) (int, error) {
	total := 0
	for _, v := range values {
		select {
		case <-ctx.Done():
			return 0, fmt.Errorf("sum canceled: %w", ctx.Err())
		default:
		}
		total += v
	}
	return total, nil
}
```

`default` делает проверку неблокирующей. Для работы, которая ждёт result channel, cancellation должна быть отдельной веткой `select`; иначе worker может завершиться, но caller зависнет в receive. Не создавайте goroutine только ради проверки `Done`: это добавляет lifetime, который надо завершать.

### Граница HTTP

```go
package api

import (
	"context"
	"encoding/json"
	"net/http"
)

type Finder interface {
	Find(ctx context.Context, id string) (any, error)
}

func GetUser(f Finder) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		user, err := f.Find(r.Context(), r.PathValue("id"))
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		_ = json.NewEncoder(w).Encode(user)
	}
}
```

`r.Context()` отменяется, когда client connection закрыта, запрос отменён HTTP/2 или handler вернулся. Не запускайте из handler goroutine с этим `ctx`, если она должна жить дольше ответа: передайте в очередь данные задания и обработайте отдельно.

## Типовые вопросы

1. **Почему `Context` передают параметром, а не полем struct?**
   - Его lifetime относится к конкретной операции. Поле делает переиспользование объекта опасным и скрывает, какой запрос владеет работой.
2. **Можно ли передать `nil`?**
   - Нет: API `context` требует non-nil; вызывающий использует `context.TODO()`/`Background()` на нужной границе.
3. **Отменяет ли child parent?**
   - Нет. Отмена родителя распространяется вниз; child управляет только своим поддеревом.
4. **Что будет, если handler вернул response?**
   - Его `r.Context()` отменяется; downstream работа, которая всё ещё использует его, должна завершиться.
5. **Как отменить CPU-bound функцию?**
   - Добавить регулярные cooperative checks `ctx.Done()` на разумной гранулярности; отмена не прерывает произвольную инструкцию.
6. **Почему нельзя сохранять `ctx` для retry завтра?**
   - Его deadline/cancel и values принадлежат исходному запросу; сохраняют сериализованные данные job, не context.

## Практика

- [ ] Добавьте `ctx` в цепочку handler → use case → repository.
  - Критерии приёмки: тест отменяет root context и repository получает отмену; ни один слой не создаёт `Background`; ошибки обёрнуты с операцией.
- [ ] Напишите pipeline generator → worker → sink.
  - Критерии приёмки: каждый send/receive выбирает `ctx.Done`; остановка consumer завершает producer; goroutine count стабилен в повторном тесте.

## Частые ошибки и ловушки

- Принимать context не первым аргументом или прятать его в options struct.
- Использовать `Background` в repository «чтобы запрос точно записался»: это меняет business guarantee без решения владельца.
- Полагать, что cancel прерывает third-party библиотеку, которая не принимает `ctx`.
- Передавать входящий context в async job после ответа.

## Связанные темы

[[course/02-go/04-context-lifecycle|Context и жизненный цикл]] · [[course/02-go/04-context-lifecycle/02-cancellation-deadlines-causes|Отмена и дедлайны]] · [[course/02-go/04-context-lifecycle/04-context-values|Значения Context]] · [[course/01-foundations/04-http-web|HTTP и веб]]

## Источники

- [Пакет `context`](https://pkg.go.dev/context) — правила передачи и API.
- [Effective Go: Contexts](https://go.dev/blog/context) — rationale и tree cancellation.
- [Go `net/http.Request.Context`](https://pkg.go.dev/net/http#Request.Context) — lifecycle request context.
- [Go `database/sql` Context](https://pkg.go.dev/database/sql) — context-aware запросы к БД.
