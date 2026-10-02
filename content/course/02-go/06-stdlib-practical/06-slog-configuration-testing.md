---
title: slog, конфигурация и testing
description: Структурированные логи, безопасная конфигурация через flag/env и проверяемые Go-сервисы стандартными средствами.
tags: [go, slog, configuration, testing, observability]
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# slog, конфигурация и testing

`log/slog` пишет событие как message и typed attributes; handler выбирает представление и фильтрацию. `flag` разбирает параметры процесса, `os.LookupEnv` читает окружение с различием unset/empty. Пакеты `testing`, `httptest`, `test/fs` и `testing/fstest` дают изоляцию без живой сети и production-инфраструктуры.

## Зачем это на интервью

На E4 оценивают, умеет ли кандидат конфигурировать сервис до старта, валидировать значения, писать table-driven test и тестировать handler через `httptest`. E5 проектирует schema конфигурации, log policy/redaction, корреляцию событий и быстрые, не flaky тесты на границах системы.

## Минимум для E4

- [ ] Создать `slog.Logger` с `JSONHandler`/`TextHandler`, передавать logger как dependency и добавлять поля через `With`.
- [ ] Использовать стабильные ключи (`request_id`, `user_id`, `err`) и не логировать секреты/PII по умолчанию.
- [ ] Парсить `flag.FlagSet`, читать env через `LookupEnv`, валидировать конфигурацию до открытия listener-а.
- [ ] Писать subtests/table-driven tests, `t.Helper`, `t.Cleanup` и запускать `go test -race ./...` для concurrent-кода.
- [ ] Тестировать HTTP через `httptest.NewRequest`/`NewRecorder` или `httptest.Server` для настоящего client path.

## Углубление для E5/Senior

Лог — контракт observability. Устанавливайте уровень из configuration, чтобы noisy debug не включался случайно; JSON полезен для machines, text — для локальной разработки. `slog.LogValuer` годится для controlled redaction, но защита не абсолютна: не передавайте secret атрибутом вообще. События должны иметь ограниченную cardinality: URL path без query, код ошибки, route template; не уникальный payload как label/field без политики retention.

Конфигурация имеет precedence (обычно defaults < file < env < flags), обязательные поля, диапазоны и документацию. Не читайте env в глубине business logic: соберите immutable `Config` один раз в `main`, провалидируйте и внедрите. Секреты не печатают через `%+v` и не включают в error message. Для reload определите атомарность и владельца: частичный apply опаснее явного restart.

## Ключевые понятия

```go
package app

import (
    "flag"
    "fmt"
    "log/slog"
    "os"
    "strconv"
    "time"
)

type Config struct { Addr string; RequestTimeout time.Duration; LogLevel slog.Level }

func Load(args []string, getenv func(string) (string, bool)) (Config, error) {
    fs := flag.NewFlagSet("service", flag.ContinueOnError)
    addr := fs.String("addr", ":8080", "listen address")
    timeout := fs.Duration("request-timeout", 2*time.Second, "request deadline")
    level := fs.String("log-level", "info", "debug|info|warn|error")
    if err := fs.Parse(args); err != nil { return Config{}, err }
    if v, ok := getenv("SERVICE_ADDR"); ok && v != "" { *addr = v }
    var parsed slog.Level
    if err := parsed.UnmarshalText([]byte(*level)); err != nil { return Config{}, fmt.Errorf("log level: %w", err) }
    if *timeout <= 0 { return Config{}, fmt.Errorf("request-timeout must be positive") }
    return Config{Addr: *addr, RequestTimeout: *timeout, LogLevel: parsed}, nil
}

func NewLogger(level slog.Level) *slog.Logger {
    return slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: level}))
}

func ParsePort(s string) (int, error) {
    p, err := strconv.Atoi(s); if err != nil || p < 1 || p > 65535 { return 0, fmt.Errorf("invalid port") }; return p, nil
}
```

Здесь `getenv` внедрён для unit test. Выберите и явно зафиксируйте precedence: в данном примере env перекрывает flag для `Addr`, что нетипично для многих CLI; часто флаги имеют высший приоритет. В реальном приложении сделайте правило единым для всех полей, не оставляйте его неявным.

## Типовые вопросы

1. **`os.Getenv` и `os.LookupEnv`?**
   - `Getenv` возвращает пустую строку и для unset, и для empty; `LookupEnv` даёт второй признак, если разница важна.
2. **Почему `flag.Parse` не вызывают в библиотеке?**
   - Парсинг process-global arguments — ответственность `main`; библиотека должна принимать уже определённую конфигурацию или свой `FlagSet`.
3. **Как добавить request ID во все логи?**
   - На границе создать `logger.With("request_id", id)` и передать его через зависимости/context по принятой политике, не мутировать глобальный logger.
4. **Когда применять `t.Parallel`?**
   - Только если тест не меняет global state, env, cwd, shared files/ports и корректно изолирован; иначе он делает suite flaky.
5. **`httptest.NewRecorder` и `httptest.Server`?**
   - Recorder тестирует handler in-process; Server проверяет HTTP client/transport, redirect, TLS и сетевой путь.

## Практика

- [ ] Напишите `Load` для flags/env/defaults. **Критерий готовности:** таблица тестов покрывает invalid duration, unknown level, пустой и unset env; precedence документирован.
- [ ] Настройте JSON `slog` и протестируйте его через `bytes.Buffer`. **Критерий готовности:** event содержит message, level и request ID; token/password отсутствует в output.
- [ ] Протестируйте handler и клиент. **Критерий готовности:** handler test не открывает порт, client test использует `httptest.Server`, `go test -race ./...` проходит.

## Частые ошибки и ловушки

- Вызывать package-level `flag.Parse` в init или библиотеке.
- Хранить конфигурацию в изменяемых глобальных переменных и читать env на горячем пути.
- Логировать `err` без operation/context либо печатать весь request body.
- Утверждать только happy path и не проверять status/body/error.
- Делать test зелёным через `time.Sleep`; используйте каналы, context, fake clock или контролируемый server.

## Связанные темы

[[course/02-go/06-stdlib-practical|Практический Go]] · [[course/10-observability|Observability]] · [[course/12-testing|Тестирование]] · [[course/02-go/06-stdlib-practical/01-net-http-server-middleware|HTTP-сервер]]

## Источники

- [package log/slog](https://pkg.go.dev/log/slog)
- [package flag](https://pkg.go.dev/flag)
- [package testing](https://pkg.go.dev/testing)
- [package net/http/httptest](https://pkg.go.dev/net/http/httptest)
- [Go blog: Subtests](https://go.dev/blog/subtests)
