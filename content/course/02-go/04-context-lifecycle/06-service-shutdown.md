---
title: "Graceful shutdown: HTTP, gRPC, consumers и workers"
description: "Порядок остановки Go-сервиса по сигналу: прекратить ingress, дождаться in-flight работы, завершить consumers и закрыть зависимости."
tags:
  - go
  - shutdown
  - http
  - grpc
  - context
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Graceful shutdown: HTTP, gRPC, consumers и workers

Graceful shutdown — управляемое завершение процесса: сначала перестать принимать новую работу, затем в ограниченное время завершить или отменить уже принятую, подтвердить выход goroutine и закрыть зависимости. Это не один вызов `http.Server.Shutdown`: у процесса могут быть gRPC streams, message consumers, cron loops, queues, DB/cache clients и собственные workers.

## Зачем это на интервью

Оркестратор посылает SIGTERM и через grace period убивает контейнер. Если readiness остаётся true или consumer продолжает брать сообщения, сервис принимает работу, которую уже не успеет завершить. Ожидается чёткий порядок, deadline и поведение второго сигнала/timeout.

## Минимум для E4

- [ ] Получать root context через `signal.NotifyContext` и вызывать returned `stop`.
- [ ] Сначала выключать readiness/ingress, затем drain активных requests.
- [ ] Вызывать `http.Server.Shutdown` с отдельным bounded shutdown context.
- [ ] Останавливать consumer intake, ждать/отменять in-flight handlers и только после этого закрывать clients.
- [ ] Не вызывать `os.Exit` из worker goroutine: deferred cleanup не выполнится.

## Углубление для E5/Senior

E5 согласует application deadline с Kubernetes `terminationGracePeriodSeconds`, preStop и load balancer propagation. Он делает shutdown idempotent, ограничивает in-flight work, выбирает ack/nack/requeue политику consumer и применяет forced stop после deadline. Для gRPC он понимает, что `GracefulStop` может ждать бесконечно при stream; нужен timer и `Stop` fallback.

## Ключевые понятия

| Шаг                | Цель                       | Примеры                                          |
| ------------------ | -------------------------- | ------------------------------------------------ |
| Signal/root cancel | Начать единую остановку    | SIGTERM, SIGINT, deploy drain                    |
| Stop admission     | Не брать новую работу      | readiness false, close listener, pause consumer  |
| Drain              | Дать завершиться in-flight | HTTP `Shutdown`, worker `Wait`                   |
| Deadline           | Ограничить процесс         | shutdown context, orchestrator grace period      |
| Force              | Не зависнуть навсегда      | `Server.Close`, gRPC `Stop`, process termination |
| Close dependencies | Освободить owned resources | DB, producers, files после users                 |

### HTTP сервер и signal

```go
package main

import (
	"context"
	"errors"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func serve(srv *http.Server) error {
	root, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	errCh := make(chan error, 1)
	go func() { errCh <- srv.ListenAndServe() }()

	select {
	case err := <-errCh:
		if !errors.Is(err, http.ErrServerClosed) { return err }
		return nil
	case <-root.Done():
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		_ = srv.Close()
		return err
	}
	return nil
}
```

`Shutdown` закрывает listeners, закрывает idle connections и ждёт active connections без interrupt. Его context — отдельный root shutdown budget: request context мог быть отменён signal policy, но drain itself должен иметь предсказуемое время. В production до `Shutdown` переключите readiness false и подождите propagation, если этого требует platform. Второй signal policy решайте явно: часто `stop()` возвращает дальнейшему SIGINT обычную семантику.

### Consumer drain

```go
func consume(ctx context.Context, messages <-chan Message, handle func(context.Context, Message) error) error {
	for {
		select {
		case <-ctx.Done():
			return ctx.Err() // intake stopped; broker client должен быть paused/closed owner'ом.
		case msg, ok := <-messages:
			if !ok { return nil }
			if err := handle(ctx, msg); err != nil { return err }
		}
	}
}
```

Consumer protocol важнее шаблона: Kafka revoke, AMQP ack/nack и SQS visibility timeout имеют разные guarantees. Не ack сообщение до durable completion; при shutdown определите, завершаете ли in-flight в budget, продлеваете visibility или возвращаете сообщение. Commit/ack должен быть idempotent и наблюдаемым.

## Типовые вопросы

1. **Почему сначала readiness, а не сразу закрыть DB?**
   - Новые запросы нужно остановить, активные ещё используют DB; раннее закрытие превращает drain в ошибки.
2. **Что делает `http.Server.Shutdown`?**
   - Прекращает listeners и idle connections, ждёт active connections; он не управляет произвольными goroutine приложения.
3. **Почему shutdown context создаётся от `Background`?**
   - Root signal context уже cancelled; child от него был бы отменён сразу и не дал бы времени на drain.
4. **Как остановить gRPC?**
   - `GracefulStop` прекращает новые RPC и ждёт существующие; защитите его deadline/timer и вызовите `Stop` как fallback.
5. **Нужно ли закрывать channel чтобы остановить worker?**
   - Не обязательно: `ctx.Done` может остановить. Закрывайте channel только owner producer, когда это означает «данных больше не будет».
6. **Что делать при deadline shutdown?**
   - Логировать/метрировать unfinished work, применить force policy и позволить supervisor завершить процесс; не ждать бесконечно.

## Практика

- [ ] Соберите сервис с `/healthz`, `/readyz`, slow handler и SIGTERM test.
  - Критерии приёмки: readiness становится false до drain; новая работа не принимается; in-flight завершается или получает deadline; exit code/логи проверены integration test.
- [ ] Добавьте consumer с manual acknowledgement.
  - Критерии приёмки: intake прекращается первым; ack только после обработки; отменённое сообщение имеет документированную requeue policy; clients закрываются после worker `Wait`.

## Частые ошибки и ловушки

- Закрыть listener, но оставить readiness положительным и consumer активным.
- Создать drain timeout от уже cancelled root context.
- Вызывать `Close` DB/producer до завершения handlers.
- Считать shutdown успешным без ожидания собственного worker pool.
- Зависнуть в `GracefulStop` на бесконечном stream без force fallback.

## Связанные темы

[[course/02-go/04-context-lifecycle|Context и жизненный цикл]] · [[course/02-go/04-context-lifecycle/05-goroutine-resource-leaks|Утечки goroutine и ресурсов]] · [[course/01-foundations/01-os/06-unix-signals|Unix-сигналы]] · [[course/01-foundations/04-http-web|HTTP и веб]]

## Источники

- [Go `os/signal.NotifyContext`](https://pkg.go.dev/os/signal#NotifyContext) — lifecycle signal registration.
- [Go `http.Server.Shutdown`](https://pkg.go.dev/net/http#Server.Shutdown) — semantics HTTP drain.
- [gRPC graceful shutdown](https://grpc.io/docs/guides/server-graceful-stop/) — `GracefulStop` и force stop.
- [Kubernetes termination of pods](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination-flow) — процесс SIGTERM и grace period.
- [Google SRE: Handling Overload](https://sre.google/sre-book/handling-overload/) — admission control и graceful degradation.
