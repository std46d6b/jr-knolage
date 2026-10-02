---
title: "sync: Mutex, RWMutex, WaitGroup, Once, Cond, Pool и Map"
description: Выбор примитива sync, инварианты, корректный жизненный цикл и ограничения concurrent-safe контейнеров.
tags:
  - go
  - concurrency
  - sync
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# sync: Mutex, RWMutex, WaitGroup, Once, Cond, Pool и Map

Пакет `sync` предоставляет низкоуровневые механизмы координации. Их выбирают по инварианту: `Mutex` защищает изменяемое состояние, `WaitGroup` ждёт завершения, `Once` выполняет инициализацию один раз. Примитив нельзя копировать после первого использования, а его корректность определяется дисциплиной всех участников.

## Зачем это на интервью

Интервьюер ожидает, что вы не предложите `RWMutex` без профиля, не вызовете `Add` конкурентно с начавшимся `Wait`, а также понимаете, почему `sync.Map` и `sync.Pool` — не универсальные замены map и allocation.

## Минимум для E4

- [ ] Держать под lock весь инвариант и отпускать lock через `defer` в небольшой критической секции.
- [ ] Вызывать `wg.Add` до запуска goroutine, а `Done` — через `defer` внутри неё.
- [ ] Использовать `RWMutex` только когда есть преимущественно читатели и измеренная конкуренция.
- [ ] Не копировать `Mutex`, `RWMutex`, `WaitGroup`, `Once`, `Cond`, `Pool` после использования.

```go
package main

import (
    "fmt"
    "sync"
)

type Counter struct {
    mu sync.Mutex
    n  int
}

func (c *Counter) Add(delta int) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.n += delta
}

func (c *Counter) Value() int {
    c.mu.Lock()
    defer c.mu.Unlock()
    return c.n
}

func main() {
    var wg sync.WaitGroup
    var c Counter
    for range 100 {
        wg.Add(1) // до go
        go func() {
            defer wg.Done()
            c.Add(1)
        }()
    }
    wg.Wait()
    fmt.Println(c.Value())
}
```

## Углубление для E5/Senior

`Mutex` устанавливает happens-before от `Unlock` к последующему `Lock`, поэтому защищённые данные не требуют `atomic`. `RWMutex` разрешает параллельных readers, но усложняет путь записи и может проигрывать `Mutex` при коротких секциях. Lock не держат во время сетевого вызова, callback или потенциально долгой операции; порядок нескольких locks фиксируют глобально для предотвращения deadlock.

`Once` публикует результаты `f` всем вернувшимся из `Do`, но не является retry-механизмом: если `f` panic, `Do` считается завершённым. `Cond` нужен для сложного ожидания condition под lock и всегда ждёт в цикле; чаще яснее канал. `Pool` — кэш временных объектов, который GC может очистить в любой момент; объект возвращают только после полного прекращения использования. `sync.Map` уместен для append-only/read-mostly или независимых ключей, но не даёт атомарного составного инварианта между ключами.

## Ключевые понятия

- **Critical section** — код, который читает/меняет общий инвариант под lock.
- **Mutex/RWMutex** — взаимное исключение; `RLock` не разрешает запись.
- **WaitGroup** — счётчик завершений; не средство cancellation и не reusable без завершённого предыдущего Wait.
- **Once** — один успешный вызов `Do` на экземпляр.
- **Cond** — condition variable: `Wait` атомарно отпускает lock и засыпает.
- **Pool/Map** — специализированные concurrent структуры с ограниченной семантикой.

## Типовые вопросы

1. **Почему `WaitGroup` не отменяет goroutine?**
   - Он лишь ждёт счётчик. Для остановки нужен context, закрытие канала или другой сигнал, который goroutine сама наблюдает.
2. **Когда `RWMutex` хуже `Mutex`?**
   - При частых writes, коротких секциях или малой конкуренции его накладные расходы превосходят выгоду параллельных reads.
3. **Можно ли вызвать `Add` после `Wait`?**
   - Нельзя добавлять положительный счётчик, когда `Wait` уже ждёт и счётчик нулевой; для нового цикла дождитесь завершения предыдущего и настройте группу до запуска работ.
4. **Зачем `Cond.Wait` в цикле?**
   - Пробуждение не означает, что predicate всё ещё истинный; condition проверяют под тем же lock после каждого wakeup.
5. **Почему `sync.Pool` не cache с гарантиями?**
   - Runtime может очистить pool при GC, а объект нельзя использовать после `Put`; нельзя строить на нём корректность или обязательное сохранение.
6. **Когда выбрать `sync.Map`?**
   - При его специализированных паттернах: ключ записывается раз и потом читается многими, либо разные goroutine работают с непересекающимися ключами. Для общего инварианта — map+mutex.

## Практика

- [ ] Защитите map и связанный счётчик одним mutex. **Готово:** инвариант `count == len(map)` сохраняется под `go test -race`.
- [ ] Реализуйте `WaitGroup`-запуск workers. **Готово:** `Add` происходит до `go`, каждый путь worker вызывает `Done` ровно раз.
- [ ] Сравните `Mutex` и `RWMutex` benchmark на read-heavy и write-heavy нагрузке. **Готово:** вывод основан на `go test -bench`, а не предположении.

## Частые ошибки и ловушки

- Читать защищённое mutex поле без mutex «потому что запись редкая».
- Копировать struct с mutex value receiver или возвращать его по значению.
- Вызывать внешний код под lock.
- Использовать `WaitGroup` как semaphore или хранить в нём бизнес-состояние.
- Применять `sync.Map` для нескольких зависимых ключей.

## Связанные темы

[[course/02-go/03-concurrency|Конкурентность]] · [[course/02-go/03-concurrency/05-atomics-memory-model|Атомарные операции]] · [[course/02-go/03-concurrency/06-race-deadlock-livelock-starvation|Гонки и deadlock]] · [[course/02-go/03-concurrency/07-fanout-fanin-worker-pool|Worker pool]]

## Источники

- [Package sync](https://pkg.go.dev/sync)
- [Go Memory Model: synchronization](https://go.dev/ref/mem)
- [Go blog: Go maps in action](https://go.dev/blog/maps)
- [Go blog: Profiling Go programs](https://go.dev/blog/pprof)
