---
title: "Отмена, дедлайны и причины завершения"
description: "WithCancel, WithTimeout, WithDeadline и WithCancelCause: правильное владение cancel и классификация исхода."
tags:
  - go
  - context
  - timeout
  - errors
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Отмена, дедлайны и причины завершения

`WithCancel` даёт ручную отмену, `WithDeadline` и `WithTimeout` добавляют время окончания, а `WithCancelCause` сохраняет прикладную причину. Все возвращают context и функцию освобождения: вызывайте её через `defer` сразу после успешного создания. Это освобождает таймер и removes child из дерева, даже когда работа закончилась раньше deadline.

## Зачем это на интервью

Timeout — не универсальная обработка ошибок. Нужен ответ, кто отменяет операцию, как caller отличает deadline от бизнес-ошибки, почему нельзя ретраить всё подряд и как сохранить observability без сравнения текста error.

## Минимум для E4

- [ ] Выбирать `WithCancel` для явного stop, `WithTimeout` для относительного лимита, `WithDeadline` для известного absolute времени.
- [ ] Всегда вызывать `cancel`, не передавать его вниз как право отменять чужую работу.
- [ ] Использовать `errors.Is(err, context.Canceled)` и `errors.Is(err, context.DeadlineExceeded)`.
- [ ] Читать `context.Cause(ctx)` для причины, заданной `CancelCauseFunc`; не ожидать её как return error операции автоматически.
- [ ] Не превращать отмену в успешный результат и не ретраить request после истёкшего caller deadline.

## Углубление для E5/Senior

Причина отмены — диагностический signal, а не транспорт бизнес-данных. E5 задаёт bounded taxonomy (`ErrDrain`, `ErrQuota`, `ErrDependencyUnavailable`), сохраняет error chain и метрики исходов. Он понимает, что deadline родителя побеждает дочерний более поздний deadline; `WithDeadlineCause` позволяет объяснить timeout, но не даёт дочерней операции больше времени, чем у caller.

## Ключевые понятия

| Constructor        | Когда использовать              | Нюанс                                                      |
| ------------------ | ------------------------------- | ---------------------------------------------------------- |
| `WithCancel`       | Владелец знает событие stop     | `cancel()` возвращает `context.Canceled`                   |
| `WithTimeout`      | Лимит относительно current time | Эквивалент `WithDeadline(now + d)`                         |
| `WithDeadline`     | Внешний absolute deadline       | Удобен при передаче deadline между boundary                |
| `WithCancelCause`  | Нужна различимая причина stop   | Вызывают `cancel(cause)`; `ctx.Err()` всё равно `Canceled` |
| `WithTimeoutCause` | Нужна причина именно timeout    | Returned `CancelFunc` не принимает error                   |

### Отмена с причиной

```go
package batch

import (
	"context"
	"errors"
	"fmt"
)

var ErrDraining = errors.New("service is draining")

func Run(parent context.Context, stop <-chan struct{}) error {
	ctx, cancel := context.WithCancelCause(parent)
	defer cancel(nil)

	go func() {
		select {
		case <-stop:
			cancel(ErrDraining)
		case <-ctx.Done():
		}
	}()

	<-ctx.Done()
	return fmt.Errorf("batch stopped: %w", context.Cause(ctx))
}
```

В настоящем коде goroutine должна иметь явный lifetime: здесь она выходит в обеих ветках. `cancel(nil)` задаёт обычную cancellation cause; первая причина отмены context выигрывает. Не запускайте такую watcher-goroutine, если событие можно обработать в основном `select`.

### Внешняя операция и классификация

```go
func fetch(ctx context.Context, client *http.Client, url string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	resp, err := client.Do(req)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			return fmt.Errorf("fetch timed out: %w", err)
		}
		return fmt.Errorf("fetch: %w", err)
	}
	defer resp.Body.Close()
	return nil
}
```

Imports: `context`, `errors`, `fmt`, `net/http`. У `http.Client` можно задать общий `Timeout`, но это грубый upper bound всего запроса; обычно request `ctx` выражает caller budget. Не создавайте новый долгий timeout внутри `fetch`, если caller уже задал deadline.

## Типовые вопросы

1. **`cancel()` обязателен при timeout?**
   - Да, если операция закончилась раньше: иначе timer и parent-child ссылка живут до deadline.
2. **Что вернёт `ctx.Err()` после `cancel(ErrDraining)`?**
   - `context.Canceled`; конкретная причина доступна через `context.Cause(ctx)`.
3. **Что происходит с deadline child, если parent раньше?**
   - Child завершится при отмене/дедлайне parent; поздний child deadline не расширяет budget.
4. **Можно ли вызвать cancel несколько раз?**
   - Можно, он idempotent; у cause context первая причина сохраняется.
5. **Нужно ли логировать cancellation как error уровня 500?**
   - Обычно нет: client cancel и expected drain — нормальные outcomes; уровень и метрика зависят от политики.
6. **Почему `time.After` хуже для scoped timeout?**
   - Он не распространяет отмену вниз и легко оставляет отдельные таймеры/ветки; context выражает ownership операции.

## Практика

- [ ] Оберните RPC в `WithTimeoutCause`.
  - Критерии приёмки: success path вызывает cancel; тест различает caller cancel и локальный timeout через `errors.Is`/`Cause`; метрика содержит class outcome без URL/PII.
- [ ] Реализуйте остановку worker pool с причиной drain.
  - Критерии приёмки: workers прекращают брать новую работу; in-flight работа видит cancellation; `Wait` не блокируется после deadline.

## Частые ошибки и ловушки

- Сравнивать `err == context.DeadlineExceeded`, когда ошибка была обёрнута.
- Создавать timeout в цикле и откладывать `cancel` до конца огромной функции.
- Давать библиотеке право отменить context caller.
- Использовать cause как замену typed domain error или как место для секретных данных.

## Связанные темы

[[course/02-go/04-context-lifecycle|Context и жизненный цикл]] · [[course/02-go/04-context-lifecycle/03-deadline-budgets|Бюджеты дедлайнов]] · [[course/02-go/04-context-lifecycle/06-service-shutdown|Shutdown сервиса]] · [[course/02-go/02-concurrency|Конкурентность Go]]

## Источники

- [Go `context` constructors](https://pkg.go.dev/context#WithCancelCause) — contracts `With*Cause`.
- [Go `errors.Is`](https://pkg.go.dev/errors#Is) — безопасная классификация wrapped errors.
- [Go `net/http.Client`](https://pkg.go.dev/net/http#Client) — взаимодействие client timeout и context.
- [Go issue 51365 / context causes proposal](https://github.com/golang/go/issues/51365) — мотивация API causes.
