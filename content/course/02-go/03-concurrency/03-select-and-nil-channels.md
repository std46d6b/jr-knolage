---
title: select, blocking, default и nil-каналы
description: Выбор готовой операции, отмена, неблокирующие ветви и управляемое отключение case через nil-канал.
tags:
  - go
  - concurrency
  - channels
  - select
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# select, blocking, default и nil-каналы

`select` ждёт, пока станет возможна хотя бы одна коммуникация; если готовы несколько, runtime выбирает одну псевдослучайно. Это основной способ объединить канал данных, отмену и таймер, но `default` и nil-каналы меняют блокирующее поведение и требуют точного контракта.

## Зачем это на интервью

Нужно без запуска кода объяснить, почему `select` с `default` может крутить CPU, почему операция с nil-каналом никогда не будет выбрана и как безопасно отключать закрытый input в многоканальном цикле.

## Минимум для E4

- [ ] Понимать, что `select` без готового case блокируется, если нет `default`.
- [ ] Знать, что send/receive для nil channel блокируются навсегда, а `close(nil)` паникует.
- [ ] Ставить `ctx.Done()` в `select` там, где операция может ждать.
- [ ] Не использовать `default` для polling без backoff или явной причины.

```go
package main

import (
    "context"
    "fmt"
)

func forward(ctx context.Context, in <-chan int, out chan<- int) error {
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        case v, ok := <-in:
            if !ok {
                return nil
            }
            select {
            case <-ctx.Done():
                return ctx.Err()
            case out <- v:
            }
        }
    }
}

func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    in, out := make(chan int, 1), make(chan int, 1)
    in <- 7
    close(in)
    _ = forward(ctx, in, out)
    fmt.Println(<-out)
}
```

## Углубление для E5/Senior

Go не обещает строгую fairness: при нескольких готовых cases выбор равномерно псевдослучаен в рамках реализации, но код не должен полагаться на bounded wait конкретной ветви. `default` превращает ожидание в немедленную проверку; в цикле это часто busy loop и starvation других работ. Для периодической работы используйте ticker, deadline или блокирующее ожидание.

Присваивание local variable `nil` отключает соответствующий case. Это удобно при объединении нескольких входов: после закрытия input его делают nil, чтобы select не выбирал receive из закрытого канала бесконечно. Но если все каналы стали nil и нет контекста/таймера, select блокируется навсегда; цикл должен явно завершаться.

## Ключевые понятия

- **Ready case** — send с доступным местом/receiver или receive с данными/закрытым каналом.
- **`default`** — выбирается сразу, когда готовых коммуникаций нет; не «низкий приоритет».
- **Nil channel** — отключённый channel case; коммуникация на нём никогда не готова.
- **Closed channel case** — receive всегда готов после опустошения буфера, поэтому его нужно выключить или завершить цикл.
- **Nested select** — способ сделать и receive, и последующий send отменяемыми.

## Типовые вопросы

1. **Когда выполняется `default`?**
   - Немедленно, если в момент проверки нет готовых channel cases; select при этом не ждёт будущих событий.
2. **Как select выбирает из двух готовых cases?**
   - Псевдослучайно. Нельзя строить алгоритм на гарантированном чередовании или приоритете.
3. **Что делает nil channel в select?**
   - Его send/receive case отключён: он никогда не готов. Это отличается от закрытого канала, receive которого готов.
4. **Почему receive из закрытого канала в select опасен?**
   - Он постоянно готов и может захватить цикл, возвращая zero values. Обработайте `ok=false` и присвойте каналу nil/выйдите.
5. **Как сделать send отменяемым?**
   - Обернуть send в `select` с `case <-ctx.Done()`; одной проверки context до send недостаточно.
6. **Можно ли закрыть nil channel?**
   - Нет, `close(nil)` вызывает panic.

## Практика

- [ ] Объедините два входных канала и отключайте каждый после `ok=false`. **Готово:** программа заканчивается после закрытия обоих и не печатает zero values.
- [ ] Напишите отправку результата с cancellation. **Готово:** при остановленном consumer и отменённом context goroutine возвращается, что подтверждает тест с timeout.
- [ ] Добавьте `default` в бесконечный select и измерьте CPU. **Готово:** объяснён busy loop, исправление использует timer либо блокирующую ветвь.

## Частые ошибки и ловушки

- Считать `default` безопасным способом «не зависнуть» и получить spin loop.
- Путать nil и закрытый канал.
- Забывать cancellation вокруг блокирующего send после успешного receive.
- Ожидать deterministic fairness между cases.
- Оставлять select со всеми nil-каналами без условия выхода.

## Связанные темы

[[course/02-go/03-concurrency|Конкурентность]] · [[course/02-go/03-concurrency/02-channels-ownership-close|Каналы и close]] · [[course/02-go/03-concurrency/08-pipelines-cancellation|Pipeline и отмена]] · [[course/02-go/04-context-lifecycle|Context]]

## Источники

- [Language specification: Select statements](https://go.dev/ref/spec#Select_statements)
- [Language specification: Channel types](https://go.dev/ref/spec#Channel_types)
- [Package context](https://pkg.go.dev/context)
- [Go blog: Pipelines](https://go.dev/blog/pipelines)
