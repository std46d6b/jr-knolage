---
title: Semaphore и rate limiting в Go
description: "Ограничение параллелизма и частоты запросов: разные гарантии, алгоритмы и безопасная отмена ожидания."
tags:
  - go
  - concurrency
  - rate-limiting
  - interview
status: complete
difficulty: e5
created: 2026-10-02
updated: 2026-10-02
aliases:
  - Лимиты нагрузки в Go
draft: false
---

# Semaphore и rate limiting в Go

## Зачем это на интервью

Вопрос «ограничьте до N запросов» часто намеренно неоднозначен. Semaphore ограничивает **одновременную** работу, rate limiter — **число событий за время**. Сильный кандидат уточняет контракт: burst, ключ лимита, поведение при превышении, распределённость и deadline ожидания.

## Минимум для E4

Semaphore имеет N permits. Захват permit перед защищаемой работой и освобождение после неё ограничивают concurrency, но не RPS: десять быстрых задач при лимите 2 могут все пройти за одну секунду.

Канал ёмкости N — простой semaphore, если acquisition учитывает context. Освобождение обязано выполняться через `defer` только после успешного acquire.

```go
package limit

import "context"

type Semaphore chan struct{}

func NewSemaphore(n int) Semaphore {
	if n <= 0 {
		panic("semaphore limit must be positive")
	}
	return make(Semaphore, n)
}

func (s Semaphore) Acquire(ctx context.Context) error {
	select {
	case s <- struct{}{}:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (s Semaphore) Release() {
	<-s
}

func Process(ctx context.Context, sem Semaphore, task func(context.Context) error) error {
	if err := sem.Acquire(ctx); err != nil {
		return err
	}
	defer sem.Release()
	return task(ctx)
}
```

Для локального rate limit используйте `golang.org/x/time/rate`. `rate.NewLimiter(r, burst)` допускает в среднем `r` событий/секунду и начальный/накопленный burst. `Wait(ctx)` ждёт token с учётом отмены; `Allow()` не ждёт и сразу говорит, можно ли пропустить запрос.

```go
package limit

import (
	"context"

	"golang.org/x/time/rate"
)

func Call(ctx context.Context, limiter *rate.Limiter, fn func(context.Context) error) error {
	if err := limiter.Wait(ctx); err != nil {
		return err
	}
	return fn(ctx)
}
```

## Углубление для E5/Senior

Rate limiting — policy, поэтому задайте идентичность: global, tenant, API key, IP или endpoint; часть ключей небезопасна/неточна за proxy. Выберите реакцию: ожидание до deadline, `429 Too Many Requests` с `Retry-After`, деградация или очередь. Ограничитель после аутентификации обычно точнее, но ранний лимит защищает инфраструктуру до дорогой проверки.

Token bucket допускает controlled burst, leaky bucket сглаживает выходной поток, fixed window прост, но даёт двойной burst на границе окна; sliding window точнее, но дороже. Локальный in-memory limiter работает на один процесс. При нескольких репликах он даёт приблизительный общий лимит; глобальный лимит требует координации (например Redis/Lua) и доступной стратегии при недоступности хранилища. Не обещайте точную глобальную квоту, если фактически есть только per-instance лимит.

Semaphore защищает ограниченный ресурс: DB connections, файловые дескрипторы, CPU-тяжёлые задачи. Лимит должен быть согласован с pool downstream; иначе application queue лишь увеличит latency. Снимайте метрики rejected/wait duration/in-flight и не скрывайте перегрузку бесконечным ожиданием.

## Ключевые понятия

| Механизм        | Ограничивает                | Пример                       |
| --------------- | --------------------------- | ---------------------------- |
| Semaphore       | in-flight операции          | не более 20 параллельных RPC |
| Token bucket    | среднюю скорость + burst    | 100 req/s, burst 20          |
| Bounded queue   | накопление перед обработкой | не более 500 jobs в памяти   |
| Connection pool | открытые соединения         | не более 10 DB connections   |

## Типовые вопросы

1. **Почему semaphore не rate limiter?**
   - Semaphore возвращает permit после конца работы; при быстрой работе частота может быть очень высокой. Rate limiter выдаёт tokens во времени.
2. **Что означает burst у token bucket?**
   - Максимум накопленных tokens, которые можно потратить мгновенно после простоя. Он определяет допустимый краткий всплеск.
3. **Где ставить limiter в HTTP?**
   - Зависит от цели: глобальный до дорогой обработки, per-user после идентификации. Ответ должен учитывать доверенные proxy headers и стоимость auth.
4. **Как обработать превышение лимита?**
   - Для интерактивного HTTP обычно `429` и информация о retry; для фоновой работы — bounded wait/requeue/backoff, но не бесконечный сон.
5. **Почему нельзя просто делать `time.Sleep(time.Second / n)`?**
   - Плохо поддерживает burst, конкуренцию, cancellation и изменение лимита; несколько goroutine легко обходят общий темп.
6. **Как сделать лимит на несколько реплик?**
   - Использовать общий согласованный счётчик/алгоритм в Redis или gateway и определить поведение при его отказе. Локальный limiter не создаёт глобальную гарантию.

## Практика

- [ ] Ограничьте 100 I/O-задач semaphore на 5. Критерии: счётчик `inFlight` никогда не больше 5, отменённая задача не удерживает permit, `-race` чистый.
- [ ] Напишите HTTP middleware с `rate.Limiter`. Критерии: burst тестируется отдельно от steady rate, превышение возвращает 429, клиентская отмена не оставляет ожидающую goroutine.
- [ ] Сравните fixed window и token bucket на запросах вокруг границы секунды. Критерии: показан boundary burst и сформулирован выбор алгоритма.
- [ ] Спроектируйте distributed quota. Критерии: указан ключ, атомарность инкремента, TTL/window, отказ Redis и допустимое отклонение лимита.

## Частые ошибки и ловушки

- Делать `Release` после неуспешного acquire: это ломает инвариант permits.
- Создавать новый limiter на каждый HTTP request: он никогда не ограничит поток.
- Не ставить deadline ожидания и превращать overload в огромную очередь latency.
- Путать per-client и global limiter или доверять `X-Forwarded-For` без доверенной proxy-конфигурации.
- Считать, что `rate.Limiter` автоматически распределён между pod-ами.

## Связанные темы

[[course/02-go|Go]] · [[course/02-go/03-concurrency/07-fanout-fanin-worker-pool|Worker pool]] · [[course/02-go/03-concurrency/08-pipelines-cancellation|Pipelines и cancellation]] · [[course/08-system-design|System Design]]

## Источники

- [golang.org/x/time/rate](https://pkg.go.dev/golang.org/x/time/rate)
- [context package](https://pkg.go.dev/context)
- [Go Wiki: Rate Limiting](https://go.dev/wiki/RateLimiting)
- [HTTP 429 Too Many Requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/429)
