---
title: "Context и жизненный цикл Go-сервиса"
description: "Отмена, дедлайны, значения, завершение goroutine и graceful shutdown без утечек."
tags:
  - go
  - context
  - concurrency
  - lifecycle
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Context и жизненный цикл Go-сервиса

`context.Context` переносит **сигнал отмены**, дедлайн и небольшой request-scoped metadata по дереву вызовов. Он не отменяет работу магически: каждая goroutine и каждый I/O API должны наблюдать `Done` или принимать `ctx`. Вместе с явным владением ресурсами это задаёт жизненный цикл запроса, фоновой работы и процесса.

## Зачем это на интервью

Тема проверяет не знание четырёх конструкторов, а способность объяснить, почему запрос не продолжает тратить CPU, соединения и деньги после disconnect клиента, как не превратить один общий timeout в каскад ошибок и как безопасно остановить сервис.

## Минимум для E4

- [ ] Передавать `ctx` первым параметром функции и не хранить его в struct.
- [ ] Вызывать `cancel` у каждого созданного derived context, включая успешный путь.
- [ ] Различать отмену вызывающей стороны, deadline и собственную ошибку операции через `ctx.Err()`/`context.Cause`.
- [ ] Останавливать goroutine через `select` с `ctx.Done()` и закрывать принадлежащие ресурсы.
- [ ] Назвать порядок graceful shutdown: прекратить ingress, дать время активной работе, остановить workers, закрыть зависимости.

## Углубление для E5/Senior

E5 проектирует бюджет времени по критическому пути, не увеличивает дедлайн дочернего вызова и отделяет request-scoped работу от независимой durable-задачи. Он определяет ownership каналов, `Close` и `Wait`, измеряет число goroutine/очереди/in-flight requests и заранее выбирает политику forced shutdown.

## Карта тем

1. [[course/02-go/04-context-lifecycle/01-context-basics-propagation|Основы Context и propagation]] — контракт, корни и границы API.
2. [[course/02-go/04-context-lifecycle/02-cancellation-deadlines-causes|Отмена, дедлайны и причины]] — constructors, причины и обработка ошибок.
3. [[course/02-go/04-context-lifecycle/03-deadline-budgets|Бюджеты дедлайнов]] — latency budget и ретраи.
4. [[course/02-go/04-context-lifecycle/04-context-values|Значения Context]] — допустимый metadata и анти-паттерны.
5. [[course/02-go/04-context-lifecycle/05-goroutine-resource-leaks|Утечки goroutine и ресурсов]] — ownership, диагностика и backpressure.
6. [[course/02-go/04-context-lifecycle/06-service-shutdown|Завершение сервиса]] — HTTP/gRPC, consumers и фоновые workers.

## Типовые вопросы

1. **Почему `context` не равен механизму принудительной остановки?**
   - Он лишь закрывает `Done`; функция должна cooperatively выйти, а API — поддерживать отмену.
2. **Кто вызывает `cancel`?**
   - Тот, кто создал derived context; это освобождает timer и связь родитель—ребёнок раньше дедлайна.
3. **Можно ли передать `context.Background()` в библиотечный вызов?**
   - Только на осознанной process-level границе; внутри request path это отрывает работу от отмены и бюджета.
4. **Что делает shutdown после timeout?**
   - Прекращает ожидание согласно политике процесса, логирует незавершённую работу и допускает принудительное завершение supervisor’ом.
5. **Почему нельзя передавать зависимости через values?**
   - Сигнатура скрывает обязательную зависимость, теряется типовой контракт и lifetime становится неясным.

## Практика

- [ ] Соберите HTTP endpoint → service → repository с единым `ctx`.
  - Критерии приёмки: disconnect или test cancellation прекращает все уровни; логи различают cancel и deadline; `go test -race` проходит.
- [ ] Реализуйте root context от SIGTERM и worker pool.
  - Критерии приёмки: ingress прекращается до закрытия dependency; workers завершаются или фиксируются как timeout; повторный сигнал имеет определённую политику.

## Частые ошибки и ловушки

- Использовать `context.TODO()` как постоянный способ игнорировать контракт отмены.
- Создавать timeout в нижнем слое без бюджета вызывающей операции.
- Закрывать канал со стороны получателя или отменять context вместо ожидания завершения workers.
- Считать `Server.Shutdown` остановкой Kafka/RabbitMQ consumer или произвольной goroutine.

## Связанные темы

[[course/02-go|Go: язык, runtime и стандартная библиотека]] · [[course/01-foundations/01-os/06-unix-signals|Unix-сигналы]] · [[course/10-observability|Наблюдаемость]] · [[course/08-system-design|System Design]]

## Источники

- [Go `context`](https://pkg.go.dev/context) — контракт `Context`, constructors и причины отмены.
- [Go blog: Go Concurrency Patterns: Context](https://go.dev/blog/context) — исходная модель propagation.
- [Go blog: Pipelines and cancellation](https://go.dev/blog/pipelines) — завершение pipeline без утечек.
- [Go `net/http.Server`](https://pkg.go.dev/net/http#Server.Shutdown) и [gRPC graceful shutdown](https://grpc.io/docs/guides/server-graceful-stop/) — shutdown серверов.
