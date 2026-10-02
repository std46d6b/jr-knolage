---
title: "Бюджеты дедлайнов в цепочке вызовов"
description: "Как распределять latency budget между HTTP, RPC, БД и ретраями, не продлевая жизнь запроса."
tags:
  - go
  - context
  - timeout
  - distributed-systems
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Бюджеты дедлайнов в цепочке вызовов

Deadline budget — оставшееся время до обещанного caller срока. Он относится к **полному** критическому пути: admission, очередям, serialization, сеть, downstream, retries и response. Локальный timeout не создаёт дополнительное время: если у входящего запроса 200 ms, вызов БД с timeout 1 s всё равно должен завершиться максимум через 200 ms.

## Зачем это на интервью

«Поставим timeout 5 секунд везде» создаёт непредсказуемую хвостовую latency и каскадную перегрузку. Хороший ответ связывает SLO, критический путь, retries и concurrency: медленная зависимость не должна удерживать тысячи goroutine до собственного большого timeout.

## Минимум для E4

- [ ] Получать входной deadline из `ctx.Deadline()` и не увеличивать его в child context.
- [ ] Оставлять reserve на ответ, cleanup и fallback; не отдавать весь budget одному downstream.
- [ ] Передавать один ctx в `http`, gRPC и `database/sql` APIs, которые его поддерживают.
- [ ] Выполнять retry только при retryable ошибке, идемпотентной операции и оставшемся времени.
- [ ] Различать queueing timeout, connect/TLS timeout и total operation deadline.

## Углубление для E5/Senior

E5 задаёт endpoint SLO и error budget, измеряет p50/p95/p99 каждого segment и умеет отказать рано (admission control), когда остатка недостаточно для полезной работы. Для fan-out он учитывает max latency ветвей, отменяет проигравшие ветки и ограничивает concurrency. Retry budget отдельный: повтор не должен удваивать нагрузку на уже деградировавший dependency.

## Ключевые понятия

| Термин              | Смысл                              | Решение                                     |
| ------------------- | ---------------------------------- | ------------------------------------------- |
| End-to-end deadline | Обещание caller                    | Верхняя граница всей работы                 |
| Remaining budget    | `deadline - now`                   | Основа решения, начинать ли downstream call |
| Per-hop cap         | Лимит конкретной зависимости       | `min(remaining-reserve, policy cap)`        |
| Reserve             | Время для encode/response/fallback | Защита от useless work в конце запроса      |
| Retry budget        | Доля времени/попыток на повтор     | Ограничивает amplification                  |

### Вычисление дочернего лимита

```go
package budget

import (
	"context"
	"errors"
	"time"
)

var ErrInsufficientBudget = errors.New("insufficient deadline budget")

func Child(ctx context.Context, cap, reserve time.Duration) (context.Context, context.CancelFunc, error) {
	deadline, ok := ctx.Deadline()
	if !ok {
		child, cancel := context.WithTimeout(ctx, cap)
		return child, cancel, nil
	}
	remaining := time.Until(deadline)
	if remaining <= reserve {
		return nil, nil, ErrInsufficientBudget
	}
	limit := min(cap, remaining-reserve)
	return context.WithTimeout(ctx, limit)
}
```

В Go 1.21 встроенная `min` работает для `time.Duration`. Функция не обязана создавать новый context, если policy не требует отдельного cap; главное — не заменить parent. Caller обязан вызвать returned cancel. Отсутствующий deadline не означает «бесконечно ждать»: boundary обычно вводит безопасный process policy timeout.

### Retry с budget-aware backoff

```go
func Retry(ctx context.Context, attempt func(context.Context) error) error {
	for n := 0; n < 3; n++ {
		if err := attempt(ctx); err == nil {
			return nil
		} else if ctx.Err() != nil {
			return ctx.Err()
		}
		backoff := time.Duration(25*(1<<n)) * time.Millisecond
		if deadline, ok := ctx.Deadline(); ok && time.Until(deadline) <= backoff+10*time.Millisecond {
			return ErrInsufficientBudget
		}
		timer := time.NewTimer(backoff)
		select {
		case <-ctx.Done():
			if !timer.Stop() { <-timer.C }
			return ctx.Err()
		case <-timer.C:
		}
	}
	return errors.New("retry attempts exhausted")
}
```

Imports: `context`, `errors`, `time`. В реальной реализации классифицируйте error: retry 4xx, validation error или unknown non-idempotent POST может создать дубликат. При timeout результат предыдущей попытки неизвестен, поэтому idempotency key и server contract важнее цикла retry.

## Типовые вопросы

1. **Почему child timeout не должен быть дольше parent?**
   - Работа больше не нужна после caller deadline и будет удерживать ресурсы; context всё равно отменит child при parent deadline.
2. **Как выбрать timeout для БД?**
   - Из end-to-end SLO и измеренного пути с reserve, а не из произвольного круглого числа.
3. **Когда лучше fail fast?**
   - Когда remaining budget меньше ожидаемого минимального времени полезной операции или dependency уже перегружен.
4. **Почему ретраи ухудшают outage?**
   - Они увеличивают RPS и очередь у деградировавшего сервиса; нужен лимит, jitter и retry budget.
5. **Как fan-out влияет на deadline?**
   - Ответ ждёт slowest required branch; параллельные вызовы не получают независимые полные бюджеты.
6. **Отличается ли client timeout от deadline?**
   - Client timeout часто охватывает всю HTTP операцию экземпляра клиента; context выражает deadline конкретного caller и распространяется дальше.

## Практика

- [ ] Постройте endpoint с budget 300 ms, cache и database fallback.
  - Критерии приёмки: cache получает короткий cap, БД не стартует при недостатке остатка, response reserve покрыт тестом с fake clock/контролируемой задержкой.
- [ ] Добавьте retry для идемпотентного GET.
  - Критерии приёмки: retry прекращается на cancel, не выполняется без времени на backoff, в метрике видны attempts и outcome без cardinality по URL.

## Частые ошибки и ловушки

- Применять одинаковый timeout на каждом hop и складывать худшие случаи последовательно.
- Запускать retry после `ctx.Err()` или не останавливать timer при cancel.
- Передавать deadline header как доверенный без ограничения серверной политикой.
- Считать, что timeout автоматически прекращает SQL query: драйвер и сервер должны поддерживать context cancellation.

## Связанные темы

[[course/02-go/04-context-lifecycle|Context и жизненный цикл]] · [[course/02-go/04-context-lifecycle/02-cancellation-deadlines-causes|Отмена, дедлайны и причины]] · [[course/02-go/04-context-lifecycle/05-goroutine-resource-leaks|Утечки goroutine]] · [[course/08-system-design|System Design]]

## Источники

- [Go `context.Deadline`](https://pkg.go.dev/context#Context) — semantics deadline propagation.
- [Google SRE: Addressing Cascading Failures](https://sre.google/sre-book/addressing-cascading-failures/) — timeouts, retries и overload.
- [AWS Builders Library: Timeouts, retries, and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) — practical retry policy.
- [Go `database/sql` QueryContext](https://pkg.go.dev/database/sql#DB.QueryContext) — context-aware database calls.
