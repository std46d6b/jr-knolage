---
title: Fan-out, fan-in и worker pool в Go
description: Паттерны параллельной обработки с ограничением конкуренции, корректным завершением и сбором результатов.
tags:
  - go
  - concurrency
  - worker-pool
  - interview
status: complete
difficulty: e5
created: 2026-10-02
updated: 2026-10-02
aliases:
  - Пул воркеров Go
draft: false
---

# Fan-out, fan-in и worker pool в Go

## Зачем это на интервью

Это частая live-coding задача: параллельно обработать набор работ, не превысить лимит внешнего API, остановиться по отмене и не утечь goroutine. Хороший ответ начинается с границ: CPU или I/O, допустим ли порядок, как вернуть ошибку и кто закрывает каналы.

## Минимум для E4

- **Fan-out**: один входной поток работ распределяется нескольким worker-ам.
- **Fan-in**: результаты нескольких producer-ов объединяются в один поток.
- **Worker pool** ограничивает число одновременно работающих goroutine; число workers не равно размеру буфера.
- Создатель канала обычно отвечает за его закрытие. Канал результатов закрывают после `wg.Wait()`, а не каждый worker.
- Для CPU-bound работы ориентир — число доступных CPU и измерения; для I/O-bound можно увеличить concurrency, но только с лимитами внешней зависимости.

Ниже pool возвращает результат на каждую задачу, завершает workers по закрытию `jobs` и корректно закрывает `results` после всех отправителей.

```go
package pool

import (
	"sync"
)

type Result struct {
	Input  int
	Output int
}

func SquareAll(inputs []int, workers int) []Result {
	jobs := make(chan int)
	results := make(chan Result)

	var wg sync.WaitGroup
	for range workers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for n := range jobs {
				results <- Result{Input: n, Output: n * n}
			}
		}()
	}

	go func() {
		defer close(jobs)
		for _, n := range inputs {
			jobs <- n
		}
	}()
	go func() {
		wg.Wait()
		close(results)
	}()

	out := make([]Result, 0, len(inputs))
	for result := range results {
		out = append(out, result)
	}
	return out
}
```

Результаты не обязаны сохранять входной порядок. Если контракт требует порядок, передавайте индекс и собирайте в предвыделенный slice или сортируйте после обработки.

## Углубление для E5/Senior

Pool — механизм backpressure, а не универсальная оптимизация. Не создавайте pool для короткой последовательной работы: он добавляет каналы, contention и сложность lifecycle. Для независимых задач ограничение может быть semaphore; для длительного общего сервиса — явная очередь с политикой переполнения, fairness и метриками.

В production контракт должен назвать: максимальную очередь, что происходит при переполнении (wait, reject, drop), deadline каждой работы, retry/idempotency и классификацию ошибок. Не запускайте goroutine на каждый входящий запрос, если downstream ограничен: это переносит очередь в память процесса и разрушает latency при всплеске.

Обрабатывайте первую ошибку через отменяемый `context`, но не теряйте ошибки произвольно: для batch API иногда нужны все результаты, для fail-fast — причина первой ошибки. `errgroup.Group` с `SetLimit` удобен для ограниченного набора работ; долгоживущий pool требует собственного жизненного цикла и явного `Close`/`Stop`.

## Ключевые понятия

| Выбор               | Когда подходит                 | Цена                               |
| ------------------- | ------------------------------ | ---------------------------------- |
| Goroutine на задачу | маленький ограниченный batch   | нужен отдельный лимит              |
| Worker pool         | поток однотипных задач         | lifecycle очереди и workers        |
| Semaphore           | ограничить участок работы      | не образует очередь/результаты сам |
| `errgroup.SetLimit` | request-scoped batch с отменой | не замена долгоживущему dispatcher |

## Типовые вопросы

1. **Зачем pool, если goroutine дешёвые?**
   - Дешёвые не значит бесплатные. Pool ограничивает число одновременных DB/RPC/CPU операций, память очереди и нагрузку на downstream.
2. **Кто закрывает `results`?**
   - Координатор, знающий, что все senders закончили: обычно goroutine после `wg.Wait`. Worker не знает, последний ли он.
3. **Почему worker не должен закрывать `jobs`?**
   - Закрывает producer/владелец входа; несколько producer-ов должны координироваться отдельно. Закрытие receiver-ом гоняется с send.
4. **Как сохранить порядок?**
   - Пронумеровать jobs, записывать результат в `out[index]` после корректной синхронизации либо собрать и отсортировать; нельзя полагаться на порядок канала от разных workers.
5. **Что задаёт размер buffer?**
   - Допустимую очередь и сглаживание, но не параллелизм. Большой buffer может скрыть перегрузку и удерживать много памяти.
6. **Как остановить pool по ошибке?**
   - Передать `context`, проверять `ctx.Done()` при receive/send и отменять координатором; затем дождаться workers, чтобы не оставить goroutine.

## Практика

- [ ] Реализуйте `Map(ctx, inputs, workers, fn)`. Критерии: workers > 0 валидируется, порядок результатов сохраняется, возврат идёт по отмене и `go test -race` чистый.
- [ ] Добавьте ошибку одной задачи. Критерии: fail-fast прекращает dispatch, не блокируется sender результата, все запущенные workers завершаются.
- [ ] Нагрузите I/O-имитацию для разных лимитов. Критерии: измерены throughput и p95, выбран лимит обоснован downstream, а не числом «по умолчанию».
- [ ] Спроектируйте bounded очередь. Критерии: прописаны поведение при full queue, deadline, метрики `queue_depth` и `queue_wait_seconds`.

## Частые ошибки и ловушки

- Вызывать `wg.Add` внутри goroutine или параллельно с `Wait`, когда счётчик уже мог стать нулём.
- Закрывать один канал несколькими worker-ами или посылать в `results`, когда consumer уже ушёл.
- Не читать результаты при unbuffered `results`: workers застревают на send, `Wait` никогда не заканчивается.
- Использовать бесконечную очередь/неограниченный запуск для «защиты» HTTP handler.
- Игнорировать `ctx.Err()` и выполнять уже ненужную дорогую работу.

## Связанные темы

[[course/02-go|Go]] · [[course/02-go/03-concurrency/06-race-deadlock-livelock-starvation|Race, deadlock и starvation]] · [[course/02-go/03-concurrency/08-pipelines-cancellation|Pipelines и cancellation]] · [[course/02-go/03-concurrency/09-semaphore-rate-limiting|Semaphore и rate limiting]]

## Источники

- [Go blog: Pipelines and cancellation](https://go.dev/blog/pipelines)
- [sync.WaitGroup](https://pkg.go.dev/sync#WaitGroup)
- [golang.org/x/sync/errgroup](https://pkg.go.dev/golang.org/x/sync/errgroup)
- [Effective Go: Channels](https://go.dev/doc/effective_go#channels)
