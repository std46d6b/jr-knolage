---
title: Жизненный цикл goroutine и модель G-M-P
description: Запуск, блокировки и завершение goroutine; связь планировщика Go с G, M, P и GOMAXPROCS.
tags:
  - go
  - concurrency
  - scheduler
  - runtime
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Жизненный цикл goroutine и модель G-M-P

Goroutine — лёгкая единица выполнения, управляемая runtime Go. Её стек растёт и сжимается по необходимости, а runtime мультиплексирует много goroutine на меньшее число потоков ОС. Однако goroutine не «бесплатна»: каждая требует памяти, записи в scheduler и ясного способа завершиться.

## Зачем это на интервью

Тема проверяет, понимаете ли вы, почему `go f()` не даёт ни ожидания, ни отмены, что именно ограничивает `GOMAXPROCS`, и как отличать проблему Go scheduler от блокировки на I/O или lock.

## Минимум для E4

- [ ] Объяснять, что goroutine запускается асинхронно и программа завершается вместе с `main`.
- [ ] Знать роли G (goroutine), M (OS thread), P (ресурс выполнения) и `GOMAXPROCS`.
- [ ] Передавать `context.Context` в долгую работу и ждать workers через `sync.WaitGroup` или результат.
- [ ] Понимать, что блокирующий syscall может потребовать дополнительный M, а P не равен числу goroutine.

```go
package main

import (
    "context"
    "fmt"
    "sync"
)

func worker(ctx context.Context, jobs <-chan int, wg *sync.WaitGroup) {
    defer wg.Done()
    for {
        select {
        case <-ctx.Done():
            return
        case job, ok := <-jobs:
            if !ok {
                return
            }
            fmt.Println(job * job)
        }
    }
}

func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    jobs := make(chan int)
    var wg sync.WaitGroup
    wg.Add(1)
    go worker(ctx, jobs, &wg)
    jobs <- 4
    close(jobs) // единственный producer сообщает конец входа
    wg.Wait()
}
```

## Углубление для E5/Senior

P содержит локальную очередь runnable G и нужен M для выполнения Go-кода; число P ограничено `GOMAXPROCS` (по умолчанию runtime выбирает доступный CPU). Scheduler использует локальные очереди, глобальную очередь и work stealing. Когда M блокируется в syscall, runtime может отвязать P и дать его другому M, чтобы не останавливать Go-код. При CPU-bound нагрузке больше runnable G, чем P, повышают конкуренцию и latency, но не создают дополнительный CPU.

Асинхронная preemption позволяет runtime остановить долго работающую goroutine в безопасной точке, поэтому бесконечный CPU-цикл не должен рассчитывать на добровольный yield. Это механизм справедливости, а не контракт latency. Диагностируют scheduler через `go tool trace`, profile goroutine и метрики runtime; изменение `GOMAXPROCS` — измеряемый deployment-параметр, особенно при CPU quota контейнера.

## Ключевые понятия

- **G** — дескриптор goroutine: стек, состояние, функция и метаданные.
- **M** — поток ОС, исполняющий Go-код или системный вызов.
- **P** — логический ресурс runtime, необходимый M для запуска Go-кода; не процессор ОС.
- **Runnable/blocked** — runnable ждёт P/M/CPU, blocked ждёт канал, lock, I/O, таймер или другое событие.
- **Goroutine leak** — goroutine, которая больше не полезна, но навсегда ждёт и удерживает ресурсы.

## Типовые вопросы

1. **Что делает `go f()`?**
   - Создаёт новую goroutine и планирует её выполнение; порядок с текущей goroutine не определён, а вызвавшая сторона не ждёт результат.
2. **Что означает G-M-P?**
   - G — работа, M — OS thread, P — разрешение исполнять Go-код. M выполняет G только имея P.
3. **`GOMAXPROCS` — это число OS threads?**
   - Нет. Это максимум P, то есть параллельного Go-кода; runtime может создать больше M из-за syscalls и других нужд.
4. **Почему нельзя просто поднять число goroutine для CPU-задачи?**
   - После насыщения P/CPU растут очередь, переключения и хвост задержки. Нужен ограниченный пул и измерение.
5. **Как гарантировать завершение goroutine?**
   - Дать ей наблюдаемый вход завершения: закрытие входного канала, `ctx.Done()`, ограниченный результат и `WaitGroup` для ожидания.
6. **Как искать утечку?**
   - Сравнить goroutine profile/метрику до и после нагрузки, найти stack ожидания, затем исправить владельца cancellation или закрытия.

## Практика

- [ ] Напишите worker, который ждёт канал или отмену. **Готово:** `wg.Wait()` возвращается и при закрытии jobs, и при `cancel()`.
- [ ] Создайте утечку: goroutine отправляет в канал без получателя; найдите её goroutine profile. **Готово:** стек показывает блокировку send, после исправления число goroutine возвращается к baseline.
- [ ] Проверьте CPU-bound workload при разных `GOMAXPROCS`. **Готово:** записаны throughput, p99 и CPU quota; выбранное значение обосновано метриками.

## Частые ошибки и ловушки

- Считать завершение `main` ожиданием всех goroutine.
- Передавать работу в goroutine, игнорируя `ctx.Done()`.
- Путать P с физическим ядром и M с числом P.
- Вызывать `runtime.Gosched()` как универсальное исправление дизайна.
- Менять `GOMAXPROCS` без учёта cgroup quota и профиля нагрузки.

## Связанные темы

[[course/02-go/03-concurrency|Конкурентность]] · [[course/02-go/03-concurrency/04-sync-primitives|sync-примитивы]] · [[course/02-go/03-concurrency/09-pipeline-cancellation|Pipeline и отмена]] · [[course/01-foundations/01-os/02-cpu-scheduling-context-switch|Планирование CPU]]

## Источники

- [Package runtime: GOMAXPROCS](https://pkg.go.dev/runtime#GOMAXPROCS)
- [Go blog: Go's work-stealing scheduler](https://go.dev/blog/scheduler)
- [Go execution tracer](https://go.dev/doc/diagnostics#tracing)
- [Go FAQ: goroutines](https://go.dev/doc/faq#goroutines)
