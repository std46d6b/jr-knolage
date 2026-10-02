---
title: Graceful shutdown Go-сервиса
description: Безопасная остановка HTTP-сервера и фоновых workers по сигналу без потери управления ресурсами и зависших запросов.
tags:
  - go
  - concurrency
  - shutdown
  - production
status: complete
difficulty: e5
created: 2026-10-02
updated: 2026-10-02
aliases:
  - Мягкая остановка Go-сервиса
draft: false
---

# Graceful shutdown Go-сервиса

## Зачем это на интервью

Graceful shutdown связывает `context`, сигналы, HTTP lifecycle, очередь задач и orchestration. Вопрос проверяет, различаете ли вы «перестали слушать порт» и «безопасно закончили работу», умеете ли установить deadline и обработать ошибку `http.ErrServerClosed`.

## Минимум для E4

Правильная последовательность: принять сигнал, перестать принимать новый трафик, дать in-flight работе ограниченное время, отменить/закрыть фоновые компоненты, дождаться их и завершить процесс с наблюдаемым статусом. Шаги зависят от контракта: HTTP может завершать запросы, consumer — сначала перестать получать сообщения, затем обработать уже взятые.

`signal.NotifyContext` создаёт context, отменяемый на `SIGINT`/`SIGTERM`. `http.Server.Shutdown(ctx)` закрывает listeners, закрывает idle connections и ждёт active connections до deadline; после deadline он возвращает ошибку. Он не ждёт ваших произвольных goroutine и не останавливает hijacked connections (например WebSocket) — ими управляют отдельно.

```go
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	srv := &http.Server{Addr: ":8080", Handler: http.HandlerFunc(handler)}
	root, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	errCh := make(chan error, 1)
	go func() { errCh <- srv.ListenAndServe() }()

	select {
	case err := <-errCh:
		if !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	case <-root.Done():
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(ctx); err != nil {
			log.Printf("graceful shutdown failed: %v", err)
			_ = srv.Close()
		}
	}
}

func handler(w http.ResponseWriter, r *http.Request) {
	_, _ = w.Write([]byte("ok\n"))
}
```

В реальном сервисе readiness надо снять **до** или одновременно с прекращением приёма, чтобы load balancer перестал направлять новые запросы. Дайте propagation delay, если его требует платформа; не делайте фиксированный `Sleep` без понимания topology.

## Углубление для E5/Senior

Разделяйте три budget: время termination grace period платформы, drain HTTP и закрытие зависимостей. Внутренний shutdown deadline должен быть меньше внешнего hard-kill, оставляя запас на flush logs/telemetry. Вторая команда завершения обычно должна ускорять выход, а не бесконечно продлевать drain.

Каждый компонент получает lifecycle contract: `StopAccepting`, `Drain(ctx)`, `Close`. Для consumer-а прекращают pull/claim новых сообщений, завершают уже acquired jobs до deadline, после чего отменяют их согласно semantics брокера (nack/requeue/visibility timeout). Для DB закрытие pool делают после того, как закончилась использующая его работа. Для WebSocket/streaming задают protocol-level close и deadline.

Наблюдаемость shutdown включает причину, длительность, число in-flight, незавершённые jobs и forced termination. Тестируйте порядок через hooks/fakes и интеграционно под сигналом; успешный вызов `Shutdown` сам по себе не доказывает, что readiness, worker и DB согласованы.

## Ключевые понятия

| Событие         | Действие                                                       |
| --------------- | -------------------------------------------------------------- |
| SIGTERM         | начать bounded shutdown, не `os.Exit` немедленно               |
| Readiness false | вывести instance из балансировки                               |
| HTTP `Shutdown` | перестать принимать, дождаться active HTTP до context deadline |
| Worker drain    | не брать новые jobs, завершить/вернуть уже взятые              |
| Deadline истёк  | записать событие, принудительно закрыть, выйти до hard kill    |

## Типовые вопросы

1. **Почему нельзя вызвать `log.Fatal` при `SIGTERM`?**
   - `log.Fatal` вызывает `os.Exit(1)`, defers не исполняются, in-flight работа обрывается. Фатальна может быть стартовая ошибка, но shutdown — управляемая ветка.
2. **Что делает `http.Server.Shutdown`?**
   - Останавливает listeners, закрывает idle connections и ждёт active; он не управляет самостоятельно вашими workers, DB или hijacked connections.
3. **Зачем readiness, если уже вызван Shutdown?**
   - Между началом завершения и обновлением балансировщика возможна доставка новых запросов. Readiness задаёт внешний сигнал «не направляй новый трафик».
4. **Как выбрать timeout?**
   - От termination budget платформы, SLO и максимальной разрешённой операции; оставить запас на cleanup. Это эксплуатационный контракт, не магическое 30 секунд.
5. **Нужно ли использовать context запроса для shutdown worker-а?**
   - Нет: он отменится при окончании конкретного HTTP запроса. Worker получает service/root context и отдельный shutdown policy.
6. **Что делать с незавершённой job после deadline?**
   - Зависит от брокера: отменить и позволить redelivery, продлить visibility или зафиксировать отказ. Обработчик должен быть idempotent.

## Практика

- [ ] Добавьте `/readyz` и service lifecycle. Критерии: после начала shutdown endpoint возвращает non-ready до остановки listener-а, новая работа не принимается.
- [ ] Создайте handler, блокирующийся на канале. Критерии: shutdown ждёт его до deadline, тест явно проверяет forced close после deadline.
- [ ] Добавьте worker с каналом jobs. Критерии: после shutdown новые jobs отвергаются, уже взятая job либо завершается, либо получает отмену согласно документированному контракту.
- [ ] Запустите бинарь и пошлите `SIGTERM`. Критерии: process завершён до заданного deadline, в логах есть причина и длительность, нет зависших goroutine в тестовом сценарии.

## Частые ошибки и ловушки

- Вызывать `os.Exit` из goroutine: defers и cleanup всех goroutine пропускаются.
- Применять один context запроса для всего приложения или закрывать DB до workers.
- Не обрабатывать синхронную ошибку `ListenAndServe` и считать `http.ErrServerClosed` аварией.
- Не учитывать termination deadline Kubernetes/systemd и получать `SIGKILL` раньше drain.
- Считать, что TCP listener закрыт, значит балансировщик мгновенно перестал слать трафик.

## Связанные темы

[[course/02-go|Go]] · [[course/02-go/03-concurrency/08-pipelines-cancellation|Pipelines и cancellation]] · [[course/02-go/03-concurrency/07-fanout-fanin-worker-pool|Worker pool]] · [[course/13-delivery|Delivery]]

## Источники

- [os/signal](https://pkg.go.dev/os/signal)
- [signal.NotifyContext](https://pkg.go.dev/os/signal#NotifyContext)
- [http.Server.Shutdown](https://pkg.go.dev/net/http#Server.Shutdown)
- [Go blog: Context](https://go.dev/blog/context)
