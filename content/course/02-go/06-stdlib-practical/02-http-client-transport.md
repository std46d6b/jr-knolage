---
title: "HTTP-клиент: timeout, Transport и connection pool"
description: Как безопасно вызывать внешние HTTP-сервисы через http.Client и настраивать переиспользование соединений.
tags: [go, net-http, client, resilience]
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# HTTP-клиент: timeout, Transport и connection pool

`http.Client` выполняет запросы, а его `Transport` (`http.RoundTripper`) устанавливает соединения, TLS, proxy и содержит пул idle connections. Нормальная практика — создать client/transport при старте и переиспользовать их; request-specific deadline приходит из `context.Context`.

## Зачем это на интервью

Вызов внешнего API без deadline может навсегда занять goroutine и соединение. На E4 важно закрывать response body, проверять non-2xx status и разделять timeout всего обмена с настройками dial/TLS/header. На E5 нужны бюджет, retry только безопасных операций и capacity pool-а.

## Минимум для E4

- [ ] Передавать `NewRequestWithContext`, а не делать фоновый запрос из handler.
- [ ] Настроить `Client.Timeout` как верхнюю границу всего запроса либо гарантировать deadline в context.
- [ ] Переиспользовать client; не изменять общий `Transport` конкурентно после начала работы.
- [ ] Закрывать `resp.Body` сразу после `Do`, ограничивать error body и проверять `StatusCode`.
- [ ] Не делать blind retry POST; учитывать идемпотентность, `Retry-After` и контекст.

## Углубление для E5/Senior

`Client.Timeout` включает dial, redirects и чтение body. Он удобен как fail-safe, но deadline верхнего запроса должен быть меньше или равен бюджету caller-а. `Transport` позволяет отдельно задать `DialContext`, `TLSHandshakeTimeout`, `ResponseHeaderTimeout`, `ExpectContinueTimeout`, `IdleConnTimeout`, `MaxIdleConns`, `MaxIdleConnsPerHost`, `MaxConnsPerHost`. Ограничение `MaxConnsPerHost` защищает downstream, но вызывает очередь в transport; наблюдайте latency и cancellation.

Повтор допустим, когда семантика безопасна: GET/HEAD обычно, PUT/DELETE при корректной идемпотентности, POST — только с idempotency key и контрактом сервера. Exponential backoff с jitter не должен жить дольше request deadline. Ответ `429`/`503` не одинаково означает retry: уважайте `Retry-After` и бизнес-SLO.

## Ключевые понятия

```go
package catalog

import (
    "context"
    "fmt"
    "io"
    "net"
    "net/http"
    "time"
)

var transport = &http.Transport{
    Proxy: http.ProxyFromEnvironment,
    DialContext: (&net.Dialer{Timeout: 2 * time.Second, KeepAlive: 30 * time.Second}).DialContext,
    ForceAttemptHTTP2: true,
    MaxIdleConns: 100,
    MaxIdleConnsPerHost: 20,
    MaxConnsPerHost: 50,
    IdleConnTimeout: 90 * time.Second,
    TLSHandshakeTimeout: 3 * time.Second,
    ResponseHeaderTimeout: 2 * time.Second,
}

var client = &http.Client{Transport: transport, Timeout: 5 * time.Second}

func Fetch(ctx context.Context, url string) ([]byte, error) {
    req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
    if err != nil { return nil, err }
    resp, err := client.Do(req)
    if err != nil { return nil, fmt.Errorf("catalog request: %w", err) }
    defer resp.Body.Close()
    const maxBody = 1 << 20
    body, err := io.ReadAll(io.LimitReader(resp.Body, maxBody+1))
    if err != nil { return nil, fmt.Errorf("read catalog response: %w", err) }
    if len(body) > maxBody { return nil, fmt.Errorf("catalog response exceeds %d bytes", maxBody) }
    if resp.StatusCode < 200 || resp.StatusCode > 299 { return nil, fmt.Errorf("catalog status %s: %q", resp.Status, body) }
    return body, nil
}
```

Для production error payload следует логировать/возвращать с redaction и разумным лимитом. Глобальные переменные в примере допустимы только как неизменяемые объекты; часто client внедряют через конструктор для тестов.

## Типовые вопросы

1. **`Client.Timeout` и context deadline?**
   - Первый — абсолютный лимит всей операции client-а; context выражает бюджет caller-а и отменяет все поддерживающие его зависимости. Обычно нужны оба, причём client — страховка.
2. **Почему обязательно `Close` body?**
   - Иначе transport не освобождает связанные ресурсы; соединение не сможет переиспользоваться и возможна утечка FD.
3. **Нужно ли читать body перед Close?**
   - Для небольшой response обычно читают до EOF, чтобы connection мог вернуться в pool; при большой/ненужной response закрывают, принимая возможное закрытие соединения.
4. **Когда нужен отдельный `Transport`?**
   - При отличающейся политике proxy/TLS/pool/лимитов. `http.DefaultTransport` нельзя мутировать: его могут использовать другие клиенты.
5. **Что означает `MaxConnsPerHost`?**
   - Предел активных, dialing и idle соединений на host; запросы сверх него ожидают, пока освободится connection или отменится context.

## Практика

- [ ] Напишите client для `httptest.Server`. **Критерий готовности:** тест проверяет method/header, response non-2xx возвращает ошибку с status, body закрывается.
- [ ] Смоделируйте сервер, не отдающий headers. **Критерий готовности:** `ResponseHeaderTimeout` или context прекращает запрос в ожидаемый срок без `time.Sleep` в production-коде.
- [ ] Добавьте retry GET с jitter. **Критерий готовности:** не больше заданного числа попыток, нет retry после отмены context, POST без idempotency key не повторяется.

## Частые ошибки и ловушки

- Создавать `http.DefaultClient`-подобный client без timeout для внешнего вызова.
- Делать `io.ReadAll` ответа без лимита, особенно для error path.
- Клонировать `Transport` после начала работы или менять его поля concurrent-но.
- Retry всех сетевых ошибок и удваивать side effect.
- Отменять child context, но забывать вызвать `cancel` при раннем выходе.

## Связанные темы

[[course/02-go/06-stdlib-practical|Практический Go]] · [[course/02-go/06-stdlib-practical/01-net-http-server-middleware|HTTP-сервер]] · [[course/01-foundations/04-http-web|HTTP и Web]]

## Источники

- [http.Client](https://pkg.go.dev/net/http#Client)
- [http.Transport](https://pkg.go.dev/net/http#Transport)
- [Go blog: Context](https://go.dev/blog/context)
