---
title: Конкурентность в Go
description: Goroutine, каналы, синхронизация, память и устойчивые паттерны конкурентного кода.
tags:
  - go
  - concurrency
  - runtime
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Конкурентность в Go

Конкурентность в Go строится из goroutine, каналов, примитивов `sync`, атомарных операций и явного управления жизненным циклом. Корректность начинается не с выбора примитива, а с контракта: кто владеет данными, кто останавливает работу и какое событие устанавливает порядок между операциями.

## Зачем это на интервью

Нужно показать, что вы отличаете параллелизм от конкурентности, умеете не допускать data race и утечек goroutine, а также выбираете простой способ синхронизации под инвариант, а не «каналы везде».

## Темы

1. [[course/02-go/03-concurrency/01-goroutine-lifecycle-gmp|Жизненный цикл goroutine и модель G-M-P]]
2. [[course/02-go/03-concurrency/02-channels-ownership-close|Каналы: ownership, send/receive и close]]
3. [[course/02-go/03-concurrency/03-select-and-nil-channels|select, blocking, default и nil-каналы]]
4. [[course/02-go/03-concurrency/04-sync-primitives|sync: Mutex, RWMutex, WaitGroup, Once, Cond, Pool и Map]]
5. [[course/02-go/03-concurrency/05-atomics-memory-model|Атомарные операции и модель памяти Go]]
6. [[course/02-go/03-concurrency/06-race-deadlock-livelock-starvation|Data race, deadlock, starvation и race detector]]
7. [[course/02-go/03-concurrency/07-fanout-fanin-worker-pool|Fan-out, fan-in и worker pool]]
8. [[course/02-go/03-concurrency/08-pipelines-cancellation|Pipeline и отмена]]
9. [[course/02-go/03-concurrency/09-semaphore-rate-limiting|Semaphore и rate limiting]]
10. [[course/02-go/03-concurrency/10-graceful-shutdown|Graceful shutdown]]
11. [[course/02-go/03-concurrency/11-concurrency-interview-tasks|Конкурентные задачи на интервью]]

## Минимум для E4

- [ ] Для общего изменяемого состояния выбирать `Mutex` либо последовательного владельца данных, а не читать/писать map одновременно.
- [ ] Уметь объяснить блокировки send/receive, `close`, `select` и отмену через `context.Context`.
- [ ] Запускать тесты с `go test -race ./...` и понимать, что отсутствие отчёта не является доказательством отсутствия гонок.
- [ ] Не оставлять goroutine без пути к завершению и не закрывать канал со стороны получателя.

## Углубление для E5/Senior

Устойчивый дизайн задаёт границы параллелизма, backpressure, ownership и наблюдаемое завершение до реализации. При нагрузке оценивают не только throughput: нужны очередь, p95/p99, число goroutine, block/mutex profile и причины отмены. Оптимизацию синхронизации начинают после профилирования, сохраняя ясный инвариант.

## Ключевые понятия

- **Concurrency** — организация независимых работ с перекрытием ожиданий; **parallelism** — их одновременное выполнение на CPU.
- **Happens-before** — гарантированный порядок, делающий запись видимой последующему чтению.
- **Ownership** — компонент, единолично ответственный за изменение или закрытие ресурса.
- **Backpressure** — ограничение производителя скоростью потребителя через буфер, семафор или отмену.

## Типовые вопросы

1. **Когда выбрать канал, а когда mutex?**
   - Канал удобен для передачи работы и владения; mutex — для защиты небольшого общего инварианта. Выбор определяется потоком данных и стоимостью модели, а не идеологией.
2. **Что гарантирует `go f()`?**
   - Только запуск новой goroutine; вызывающий код не ждёт её завершения и должен сам задать синхронизацию.
3. **Кто закрывает канал?**
   - Отправитель, который единственный знает, что новых значений не будет; при нескольких отправителях нужен единый владелец/координатор.
4. **Почему `-race` недостаточен?**
   - Детектор видит лишь реально выполненные конфликтующие обращения. Нужны достаточные тестовые сценарии и корректный дизайн.
5. **Что делать при росте числа goroutine?**
   - Снять goroutine profile/trace, найти точку ожидания и добавить cancellation, deadline, закрытие входов либо лимит параллелизма.

## Практика

- [ ] Реализуйте обработчик задач с фиксированным лимитом workers и `context`-отменой. **Готово:** при отмене все goroutine завершаются, нет send в заблокированный выход, тест проходит `go test -race`.
- [ ] Сделайте намеренную гонку счётчика и исправьте её двумя способами. **Готово:** объяснён инвариант, `-race` на сценарии находит ошибку до исправления и молчит после него.
- [ ] Снимите `go tool pprof` goroutine/mutex profile нагруженной программы. **Готово:** названа причина самого долгого ожидания и измерен эффект исправления.

## Частые ошибки и ловушки

- Запускать goroutine без условия остановки, deadline или получателя результата.
- Закрывать канал из нескольких мест либо закрывать его при продолжающихся send.
- Использовать `time.After` в горячем цикле вместо управляемого таймера и отмены.
- Копировать значение с `Mutex`, `WaitGroup` или `Once` после первого использования.
- Подменять измерение конкурентности количеством goroutine.

## Связанные темы

[[course/02-go|Go]] · [[course/02-go/04-context-lifecycle|Context и жизненный цикл]] · [[course/02-go/05-runtime-memory|Runtime и управление памятью]] · [[course/10-observability|Наблюдаемость]] · [[course/12-testing|Тестирование]]

## Источники

- [Effective Go: Concurrency](https://go.dev/doc/effective_go#concurrency)
- [Go Memory Model](https://go.dev/ref/mem)
- [Data Race Detector](https://go.dev/doc/articles/race_detector)
- [Go blog: Pipelines](https://go.dev/blog/pipelines)
