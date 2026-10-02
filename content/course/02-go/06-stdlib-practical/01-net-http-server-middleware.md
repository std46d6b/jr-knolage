---
title: "net/http: Server, Handler и middleware"
description: Как строить HTTP-сервер на стандартной библиотеке, управлять жизненным циклом запроса и создавать безопасные middleware.
tags: [go, net-http, backend, interview]
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# net/http: Server, Handler и middleware

`http.Handler` — минимальный серверный контракт: `ServeHTTP(http.ResponseWriter, *http.Request)`. `http.Server` владеет listener-ом, тайм-аутами и graceful shutdown; router (`http.ServeMux`) лишь выбирает handler. Такая декомпозиция позволяет тестировать обработчик без реального порта.

## Зачем это на интервью

Задача «напишите endpoint» проверяет больше, чем JSON: корректный method/path, ограничение ввода, статусы, отмену request context и отсутствие глобального состояния. E5 должен выбрать server timeouts, описать порядок middleware и завершение in-flight запросов.

## Минимум для E4

- [ ] Принимать dependency через структуру/замыкание и возвращать `http.Handler`.
- [ ] Проверять метод, `Content-Type` при необходимости, размер тела и ошибки decode; не писать ответ дважды.
- [ ] Брать `r.Context()` для нижележащих вызовов и не сохранять `*http.Request` после handler.
- [ ] Явно задать `ReadHeaderTimeout`; для публичного сервиса рассмотреть `ReadTimeout`, `WriteTimeout`, `IdleTimeout` и `MaxHeaderBytes`.
- [ ] Строить middleware как `func(http.Handler) http.Handler`, вызывая следующий handler ровно один раз либо завершая запрос.

## Углубление для E5/Senior

`ReadHeaderTimeout` защищает от slowloris до заголовков; `ReadTimeout` включает чтение body и может конфликтовать с длинными upload; `WriteTimeout` — срок записи response и должен быть согласован с streaming/SSE; `IdleTimeout` ограничивает keep-alive. Не ставьте `http.TimeoutHandler` как универсальную замену контекстному deadline: он буферизует response и не прекращает произвольную работу зависимости.

Порядок middleware — политика. Обычно внешний слой назначает request ID и recovery, затем access log/metrics, затем лимиты, authentication/authorization и endpoint. Recovery не отменяет транзакцию сам по себе: lower layers должны использовать контекст и иметь собственное освобождение ресурсов. Паника после частичной записи не позволяет надёжно сменить status на 500.

## Ключевые понятия

```go
package main

import (
    "context"
    "encoding/json"
    "errors"
    "log/slog"
    "net/http"
    "time"
)

type widget struct { Name string `json:"name"` }

func createWidget(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        w.Header().Set("Allow", http.MethodPost)
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }
    r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
    defer r.Body.Close()
    var in widget
    dec := json.NewDecoder(r.Body)
    dec.DisallowUnknownFields()
    if err := dec.Decode(&in); err != nil || in.Name == "" {
        http.Error(w, "invalid JSON", http.StatusBadRequest)
        return
    }
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    _ = json.NewEncoder(w).Encode(in)
}

func logging(log *slog.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()
            next.ServeHTTP(w, r)
            log.Info("request", "method", r.Method, "path", r.URL.Path, "duration", time.Since(start))
        })
    }
}

func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("POST /widgets", createWidget)
    srv := &http.Server{Addr: ":8080", Handler: logging(slog.Default())(mux), ReadHeaderTimeout: 5 * time.Second, IdleTimeout: 60 * time.Second}
    go func() { _ = srv.ListenAndServe() }()
    <-context.Background().Done()
    if err := srv.Shutdown(context.Background()); err != nil && !errors.Is(err, http.ErrServerClosed) { panic(err) }
}
```

В production `Shutdown` получает отдельный `context.WithTimeout` от сигнала, а не `Background`; в snippet он показан только как форма API. После `Shutdown` listener закрыт, новые запросы не принимаются, а существующим даётся время до deadline. Hijacked connections, например WebSocket, `Shutdown` не закрывает автоматически.

## Типовые вопросы

1. **`Handler` и `HandlerFunc`?**
   - `Handler` — интерфейс; `HandlerFunc` — тип-функция с методом `ServeHTTP`, позволяющий передать обычную функцию.
2. **Зачем `http.MaxBytesReader`, если JSON decoder читает поток?**
   - Decoder потоковый, но без лимита клиент может отправлять большой body и удерживать соединение/ресурсы; лимит делает политику явной.
3. **Можно ли менять headers после `WriteHeader`?**
   - Нет для отправленного ответа. Первый `Write` неявно отправляет status 200 и headers.
4. **Как middleware передаёт request ID?**
   - Создаёт новый context с private typed key и `r = r.WithContext(ctx)`; значения только request-scoped metadata, не optional dependencies.
5. **Что делает `Shutdown`?**
   - Закрывает listeners, закрывает idle connections и ждёт завершения активных до отмены переданного context.

## Практика

- [ ] Напишите `POST /widgets` с размером JSON до 1 MiB. **Критерий готовности:** неверный JSON возвращает 400, неверный method — 405 с `Allow`, test использует `httptest.NewRecorder`.
- [ ] Добавьте middleware request ID, recovery и access log. **Критерий готовности:** ID виден в response и log, panic не убивает процесс, `next` не вызывается после отказа auth middleware.
- [ ] Реализуйте shutdown по `os.Signal`. **Критерий готовности:** новый запрос после начала shutdown не принимается, текущий завершается или отменяется по deadline; результат доказан интеграционным тестом.

## Частые ошибки и ловушки

- Использовать `http.ListenAndServe` без управляемого `http.Server` и его timeouts.
- Считать `r.URL.Path` авторизационной границей без нормализации политики маршрутизации.
- Писать ошибку после успешного JSON encode и получать смешанный response.
- Передавать `ResponseWriter` в goroutine после возврата handler.
- Логировать query string и заголовки без redaction токенов.

## Связанные темы

[[course/02-go/06-stdlib-practical|Практический Go]] · [[course/01-foundations/04-http-web|HTTP и Web]] · [[course/02-go/06-stdlib-practical/02-http-client-transport|HTTP-клиент и Transport]]

## Источники

- [package net/http](https://pkg.go.dev/net/http)
- [http.Server](https://pkg.go.dev/net/http#Server)
- [Writing Web Applications](https://go.dev/doc/articles/wiki/)
