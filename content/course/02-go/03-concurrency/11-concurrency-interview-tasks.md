---
title: Concurrency-задачи на интервью Go
description: Методика решения и набор типовых задач по goroutine, каналам, mutex, cancellation и ограничению нагрузки.
tags:
  - go
  - concurrency
  - live-coding
  - interview
status: complete
difficulty: e5
created: 2026-10-02
updated: 2026-10-02
aliases:
  - Concurrency live coding Go
draft: false
---

# Concurrency-задачи на интервью Go

## Зачем это на интервью

В concurrency live coding оценивают не скорость печати, а умение сделать контракт явным, объяснить interleaving и проверить shutdown. Код, который «обычно работает», но не возвращается при отмене или закрывает канал с двух сторон, — слабое решение даже при верном выводе на одном запуске.

## Минимум для E4

Перед кодом проговорите:

1. Что является входом, выходом и условием окончания?
2. Допустим ли порядок результатов?
3. Что происходит при первой ошибке и отмене?
4. Какие данные shared и кто ими владеет?
5. Какой лимит concurrency/очереди нужен и почему?

Называйте владельца каждого канала: кто send-ит, кто закрывает, кто читает до конца. Предпочитайте передачу ownership через channel общей mutable map. При shared state выберите один mutex и зафиксируйте инвариант. Добавляйте `context.Context`, если операция может ждать или API уже request-scoped.

Пример задачи «выполнить N функций параллельно и вернуть первую ошибку»; `errgroup` отменяет контекст соседних задач, а `SetLimit` ограничивает число активных функций.

```go
package tasks

import (
	"context"

	"golang.org/x/sync/errgroup"
)

type Task func(context.Context) error

func Run(ctx context.Context, limit int, tasks []Task) error {
	g, ctx := errgroup.WithContext(ctx)
	g.SetLimit(limit)

	for _, task := range tasks {
		task := task
		g.Go(func() error {
			return task(ctx)
		})
	}
	return g.Wait()
}
```

`SetLimit` требует положительного лимита для запуска работ; валидируйте пользовательский параметр до вызова. «Первая ошибка» здесь означает ошибка, которую вернёт group; не обещайте детерминированный выбор, если несколько задач падают одновременно.

## Углубление для E5/Senior

На E5 важнее не изощрённый паттерн, а доказательство свойств: отсутствие data race, bounded goroutines/queue, liveness при раннем возврате consumer-а, корректное распространение ошибки и ресурсный budget. Напишите сначала последовательное решение и инварианты, затем добавьте конкурентность только к независимым частям.

Для тестов делайте scheduling управляемым: barriers/каналы вместо `Sleep`, timeout на весь тест как диагностику, повторный запуск (`-count=100`) и `-race`. Факт, что тест с `time.Sleep` прошёл, не доказывает ни порядок, ни отсутствие утечки. Для production добавьте метрики in-flight, queue depth, errors, duration и goroutine count; без них overload и starvation трудно отличить от медленного downstream.

Уточняйте границы: concurrency внутри одного процесса не решает distributed locking, exactly-once или глобальную квоту. Для денег/остатков нужен атомарный переход в БД или сериализованный owner, а не только `sync.Mutex` в HTTP instance.

## Ключевые понятия

| Задача             | Что проверяют                   | Хороший инструмент                    |
| ------------------ | ------------------------------- | ------------------------------------- |
| Producer–consumer  | close, backpressure, завершение | channels + context                    |
| Concurrent counter | критическая секция              | `Mutex` или `atomic` для одного числа |
| Parallel map       | лимит и порядок                 | worker pool / `errgroup`              |
| Merge каналов      | закрытие output                 | `WaitGroup` + coordinator             |
| Rate limit         | время против in-flight          | `rate.Limiter`, не semaphore          |
| Graceful stop      | lifecycle и deadline            | `signal.NotifyContext`, `Shutdown`    |

## Типовые вопросы

1. **Как реализовать concurrent-safe cache?**
   - Сначала определить операции и consistency. Для map с составными операциями — mutex; `sync.Map` уместен для специальных read-mostly/disjoint-key сценариев, не как автоматическая замена дизайна.
2. **Как напечатать числа по очереди из двух goroutine?**
   - Использовать два канала-токена и явное число итераций/закрытие. Не полагаться на scheduler или `Sleep`.
3. **Как объединить два канала?**
   - Запустить copier на каждый input, отправлять в общий output с cancellation, закрыть output одним coordinator-ом после `WaitGroup`.
4. **Как вернуть первую ошибку из workers?**
   - Координатор получает ошибку, отменяет общий context, workers выбирают `ctx.Done()` в blocking points, затем coordinator ждёт их. Нужно определить, нужна ли именно первая или все ошибки.
5. **Когда выбрать atomic вместо mutex?**
   - Для маленькой чётко определённой атомарной операции (счётчик, флаг, CAS). Для нескольких связанных полей и инвариантов mutex обычно понятнее и безопаснее.
6. **Как проверить отсутствие race и leak?**
   - `go test -race`, управляемые тестовые barriers, timeout, многократный запуск и проверка завершения workers. Это сильное свидетельство, но не математическое доказательство всех interleaving.
7. **Почему нельзя закрывать канал receiver-у?**
   - Он не знает, все ли senders завершены; concurrent send после close вызывает panic. Закрывает владелец send side.

## Практика

- [ ] **Odd/even ping-pong.** Две goroutine печатают 1..100 по очереди. Критерии: нет `Sleep`, оба канала закрываются владельцем, `WaitGroup` завершается, результат детерминирован.
- [ ] **Merge.** Реализуйте `Merge(ctx, ...<-chan int) <-chan int`. Критерии: output закрывается после всех inputs, ранняя отмена не оставляет copier goroutine, `go test -race -count=100` проходит.
- [ ] **Bounded parallel map.** Критерии: максимум K одновременных `fn`, порядок сохраняется, первая ошибка отменяет новые работы, нет send в abandoned output.
- [ ] **Cache with TTL.** Критерии: read/write/delete согласованы, expired value не возвращается, cleanup останавливается, тесты не используют произвольный sleep.
- [ ] **HTTP limiter.** Критерии: distinction между rate и concurrency отражён в тестах, 429 документирован, metrics включают rejections и waiting time.
- [ ] **Code review.** Найдите не менее пяти дефектов в намеренно плохом примере: unowned close, `wg.Add` поздно, map race, I/O под lock, отсутствие cancellation. Для каждого дайте воспроизводимый сценарий и минимальный fix.

## Частые ошибки и ловушки

- Начинать с goroutine до определения ownership и правила закрытия.
- Писать `for { select { default: ... } }`, создавая busy loop и starvation.
- Использовать `recover` для маскировки `send on closed channel` вместо исправления ownership.
- Вызывать `WaitGroup.Add` после старта ожидания или забывать `Done` на error path.
- Конкурентно append-ить в общий slice или писать в обычную map.
- Не проверять ошибку и cancellation в созданных goroutine.
- Давать архитектурный ответ на локальную задачу или, наоборот, обещать distributed guarantee локальным mutex.

## Связанные темы

[[course/02-go|Go]] · [[course/02-go/03-concurrency/06-race-deadlock-livelock-starvation|Race, deadlock и starvation]] · [[course/02-go/03-concurrency/07-fanout-fanin-worker-pool|Fan-out и worker pool]] · [[course/02-go/03-concurrency/08-pipelines-cancellation|Pipelines и cancellation]] · [[course/15-interview-practice|Интервью-практика]]

## Источники

- [Go by Example: WaitGroups](https://gobyexample.com/waitgroups)
- [Go by Example: Worker Pools](https://gobyexample.com/worker-pools)
- [The Go Memory Model](https://go.dev/ref/mem)
- [Data Race Detector](https://go.dev/doc/articles/race_detector)
- [golang.org/x/sync/errgroup](https://pkg.go.dev/golang.org/x/sync/errgroup)
