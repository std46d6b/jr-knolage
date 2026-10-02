---
title: "Утечки goroutine и ресурсов"
description: "Ownership каналов, cancel, WaitGroup, backpressure и диагностика зависших goroutine, соединений, timers и response bodies."
tags:
  - go
  - goroutine
  - context
  - resource-management
  - pprof
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Утечки goroutine и ресурсов

Утечка — работа или ресурс, которые больше не достижимы по бизнес-смыслу, но остаются живыми: goroutine ждёт channel/I/O/lock, `Rows` удерживает connection, HTTP response body не возвращает connection в pool, timer ждёт срок. GC не решает это автоматически: goroutine и внешние дескрипторы имеют собственный lifecycle.

## Зачем это на интервью

Рост `runtime.NumGoroutine`, исчерпание pool или FD, зависающий shutdown и tail latency часто имеют одну причину — неявное ownership. Нужен воспроизводимый способ найти блокировку, назвать owner каждого `go`, channel, `Close` и `Cancel`, затем подтвердить исправление тестом и профилем.

## Минимум для E4

- [ ] Для каждого `go` назвать событие выхода, owner запуска и способ ожидания (`WaitGroup`, `errgroup`, result channel).
- [ ] В `select` при potentially blocking send/receive наблюдать `ctx.Done()`.
- [ ] Закрывать `resp.Body`, `sql.Rows`, files и `Ticker`; останавливать timers когда это требуется.
- [ ] Ограничивать очередь и concurrency, а не создавать goroutine на каждое входящее событие без лимита.
- [ ] Диагностировать через goroutine profile, block/mutex profile, trace и метрики открытых ресурсов.

## Углубление для E5/Senior

E5 проектирует structured concurrency: родитель владеет детьми и ждёт их outcome; producer владеет close output channel; cancellation прекращает admission, а `Wait` подтверждает termination. Он отличает normal long-lived goroutine (server accept loop) от leak по steady-state baseline, задаёт limits и оценивает FD/pool budget под peak traffic.

## Ключевые понятия

| Признак                | Частая причина                                | Проверка/исправление                                  |
| ---------------------- | --------------------------------------------- | ----------------------------------------------------- |
| Растёт goroutine count | blocked send, lost receiver, infinite retry   | `/debug/pprof/goroutine?debug=2`, cancellation branch |
| Pool исчерпан          | не закрыли rows/body, transaction долго живёт | `defer Close`, pool stats, bounded transaction        |
| Растут FD              | file/socket response не закрыт                | `lsof`, process FD metric, owner Close                |
| CPU после cancel       | busy loop/default select                      | block until event, add backoff/exit                   |
| Shutdown висит         | worker не observes stop                       | root ctx + Wait with deadline                         |

### Bounded worker pool

```go
package workers

import (
	"context"
	"sync"
)

func Process(ctx context.Context, jobs <-chan int, n int, handle func(context.Context, int) error) error {
	var wg sync.WaitGroup
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				select {
				case <-ctx.Done():
					return
				case job, ok := <-jobs:
					if !ok {
						return
					}
					_ = handle(ctx, job) // Production code должен определить policy ошибки.
				}
			}
		}()
	}
	wg.Wait()
	return ctx.Err()
}
```

Imports: `context`, `sync`. Owner `jobs` закрывает канал после завершения producer; workers никогда не закрывают input. Эта версия ждёт workers синхронно и не возвращает рабочие ошибки: для fail-fast используйте `errgroup.WithContext`, но всё равно убедитесь, что producer может разблокироваться при cancel.

### `Rows` и response body

```go
func listNames(ctx context.Context, db *sql.DB) ([]string, error) {
	rows, err := db.QueryContext(ctx, "SELECT name FROM users")
	if err != nil { return nil, err }
	defer rows.Close()

	var names []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil { return nil, err }
		names = append(names, name)
	}
	return names, rows.Err()
}
```

Imports: `context`, `database/sql`. `rows.Close` важен и после partial iteration; `rows.Err` ловит ошибки доставки после успешного `QueryContext`. Для HTTP всегда `defer resp.Body.Close()` после non-nil response и читайте body ровно так, как требует reuse policy transport.

## Типовые вопросы

1. **Почему goroutine не исчезает после return caller?**
   - Goroutine независима; она живёт, пока сама не вернётся. Caller обязан передать termination signal и при необходимости дождаться её.
2. **Кто закрывает channel?**
   - Обычно единственный sender/producer, который знает, что новых значений не будет. Receiver закрывать не должен.
3. **Нужен ли `defer ticker.Stop()`?**
   - Да для ticker с ограниченным lifecycle, чтобы освободить связанные runtime resources; канал ticker не закрывается.
4. **Как отличить leak от busy service?**
   - Сравнить steady-state baseline по нагрузке, снять goroutine stack и связать рост с request/queue/FD метриками.
5. **Почему `WaitGroup` не отменяет work?**
   - Он только считает завершения; stop signal передаёт context/channel, затем `Wait` подтверждает exit.
6. **Что делает `resp.Body.Close`?**
   - Освобождает body и позволяет transport корректно управлять connection; отсутствие close ведёт к исчерпанию ресурсов.

## Практика

- [ ] Создайте тест на producer, который блокируется при остановленном consumer.
  - Критерии приёмки: cancel разблокирует send; `WaitGroup` завершает workers; повтор 100 раз не показывает роста goroutine; `go test -race` проходит.
- [ ] Найдите искусственную leak в HTTP/SQL коде.
  - Критерии приёмки: приложен goroutine/FD/pool symptom до исправления; исправление закрывает body/rows на всех return paths; регрессионный тест проверяет cancel.

## Частые ошибки и ловушки

- `go func(){ ch <- value }()` как способ не блокировать sender: leak просто становится скрытой.
- `recover` вокруг send в закрытый channel вместо явного ownership.
- Держать DB transaction или mutex во время сетевого RPC.
- Считать `runtime.GC()` средством лечения FD/goroutine leak.

## Связанные темы

[[course/02-go/04-context-lifecycle|Context и жизненный цикл]] · [[course/02-go/04-context-lifecycle/01-context-basics-propagation|Propagation]] · [[course/02-go/04-context-lifecycle/06-service-shutdown|Shutdown сервиса]] · [[course/10-observability|Наблюдаемость]]

## Источники

- [Go blog: Pipelines and cancellation](https://go.dev/blog/pipelines) — cancellation and goroutine leak patterns.
- [Go `runtime/pprof`](https://pkg.go.dev/runtime/pprof) — profiles goroutine/block/mutex.
- [Go `database/sql.Rows.Close`](https://pkg.go.dev/database/sql#Rows.Close) — lifecycle database rows.
- [Go `net/http.Response.Body`](https://pkg.go.dev/net/http#Response) — необходимость закрыть response body.
