---
title: Ошибки в Go
description: Контракт ошибок, wrapping, errors.Is и errors.As, sentinel и typed errors, классификация и сохранение причины отказа.
tags:
  - go
  - language
  - errors
  - api-design
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
aliases:
  - Error handling в Go
  - Wrapping ошибок
draft: false
---

# Ошибки в Go

## Зачем это на интервью

В Go ошибка — явный результат, поэтому error handling одновременно часть API и наблюдаемости. На интервью E4 должен отличить контекст ошибки от её классификации, обернуть причину через `%w`, проверить цепочку `errors.Is`/`errors.As` и не превратить ожидаемый отказ в panic. На E5 важны стабильный контракт между слоями, retry semantics и безопасное логирование.

## Минимум для E4

- [ ] Возвращать `error` и проверять её сразу, не игнорировать без документированной причины.
- [ ] Добавлять операционный контекст через `fmt.Errorf("operation: %w", err)`.
- [ ] Проверять sentinel error через `errors.Is`, typed error — через `errors.As`.
- [ ] Отличать ошибку доменного правила от временной инфраструктурной ошибки.

`%w` создаёт unwrap-цепочку. `%v` вставляет текст, но теряет программную связь с причиной. Внешний слой добавляет, _какая операция_ не удалась; он не должен переписывать или скрывать полезную первопричину.

```go
package main

import (
    "errors"
    "fmt"
)

var ErrNotFound = errors.New("not found")

func loadUser(id string) error {
    if id == "" {
        return fmt.Errorf("load user %q: %w", id, ErrNotFound)
    }
    return nil
}

func main() {
    err := loadUser("")
    fmt.Println(errors.Is(err, ErrNotFound))
}
```

Sentinel error подходит для малого стабильного набора состояний, о которых вызывающий должен принять решение: `ErrNotFound`, `ErrConflict`, `context.Canceled`. Не сравнивайте wrapped error через `==`; после wrapping срабатывает `errors.Is`.

## Углубление для E5/Senior

Граница пакета — граница обещаний. Возвращая чужую sentinel error напрямую или заворачивая её с `%w`, вы позволяете клиенту зависеть от её identity. Это может быть верно, например для `fs.ErrNotExist`, но для инфраструктурной реализации часто лучше перевести ошибку в собственную доменную классификацию и сохранить original error в логах/telemetry. Не публикуйте тип ошибки, если не готовы поддерживать поля и поведение как API.

Typed error несёт данные решения: поле, ограничение, retry-after, код поставщика. Используйте `errors.As` по указателю на target. Реализация `Unwrap() error` либо `Unwrap() []error` позволяет error tree; `errors.Join` (Go 1.20+) полезен, когда несколько cleanup-ошибок одинаково важны. Не применяйте `Join` механически: вызывающий должен понимать, что означает одновременное наличие нескольких причин.

```go
package main

import (
    "errors"
    "fmt"
)

type ValidationError struct {
    Field string
    Msg   string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("%s: %s", e.Field, e.Msg)
}

func validateEmail(email string) error {
    if email == "" {
        return &ValidationError{Field: "email", Msg: "required"}
    }
    return nil
}

func main() {
    err := validateEmail("")
    var validation *ValidationError
    if errors.As(err, &validation) {
        fmt.Println(validation.Field)
    }
}
```

Классификация управляет действием: `context.Canceled` обычно не ретраят и часто не логируют как server error; deadline может быть следствием исчерпанного budget, а не недоступности dependency; conflict отдаётся клиенту без retry; transient network error может быть retryable только для идемпотентной операции и с budget/backoff. Один HTTP status не заменяет внутренний error contract.

Логируйте ошибку с контекстными полями один раз на границе, которая владеет решением о наблюдаемости. Повторное логирование на каждом слое создаёт дубликаты без новой информации. Не включайте в `Error()` пароль, token, полный request body или PII: текст ошибки часто попадёт в логи, метрики и ответ API.

## Ключевые понятия

| Понятие           | Смысл                                      | Как проверять                      |
| ----------------- | ------------------------------------------ | ---------------------------------- |
| Sentinel error    | Экспортируемый singleton для состояния     | `errors.Is(err, ErrNotFound)`      |
| Typed error       | Тип с данными, нужными вызывающему         | `errors.As(err, &target)`          |
| Wrapping          | Добавление контекста с сохранением причины | `fmt.Errorf("op: %w", err)`        |
| Unwrap chain/tree | Причины, доступные `Is` и `As`             | `Unwrap() error` / `[]error`       |
| Error contract    | Стабильные классификации для клиента       | Документировать действия, не текст |

Error string предназначен человеку, а не ветвлению программы. Не парсите `err.Error()` и не проверяйте подстроки. Для transport API делайте явное отображение domain errors в HTTP/gRPC response; оригинальную ошибку не отправляйте клиенту, если она раскрывает внутренности.

## Типовые вопросы

1. **Чем `%w` отличается от `%v` в `fmt.Errorf`?**
   - `%w` сохраняет error для `errors.Is`/`As`; `%v` только форматирует текст.
2. **Когда использовать sentinel error?**
   - Когда есть небольшое устойчивое состояние, по которому клиент должен ветвиться, без дополнительных данных.
3. **Когда нужен typed error?**
   - Когда вызывающему нужны структурированные данные, например поле validation или retry hint.
4. **Почему нельзя сравнивать wrapped error через `==`?**
   - Внешнее значение — новый wrapper; identity исходной ошибки ищет `errors.Is` по цепочке.
5. **Нужно ли оборачивать каждую ошибку?**
   - Добавляйте контекст, который помогает действию или диагностике; не создавайте шум из повторяющихся «failed» без операции.
6. **Как обработать две ошибки cleanup?**
   - Определить приоритет по контракту; при независимой важности использовать `errors.Join` и документировать это.

## Практика

- [ ] Реализуйте repository `FindUser`, который преобразует отсутствие строки в `ErrNotFound`.
  - **Критерии готовности:** вызывающий использует `errors.Is`; ошибка драйвера не сравнивается по строке; operation context содержит ID без секрета.
- [ ] Создайте `ValidationError` для формы регистрации и HTTP mapping.
  - **Критерии готовности:** handler использует `errors.As`; клиент получает безопасный 400-контракт; оригинальная infrastructure error не раскрывается в ответе.
- [ ] Добавьте cleanup с двумя независимыми ресурсами.
  - **Критерии готовности:** тест проверяет обе причины через `errors.Is`; решение об `errors.Join` объяснено; success path возвращает literal `nil`.

## Частые ошибки и ловушки

- Терять cause, форматируя её через `%v` вместо `%w`.
- Ветвиться по `err.Error()` или HTTP-тексту поставщика.
- Экспортировать sentinel/typed error случайно и затем считать её внутренней деталью.
- Логировать одну и ту же ошибку на каждом уровне call stack.
- Считать любую ошибку dependency retryable без идемпотентности, deadline и retry budget.
- Возвращать typed-nil pointer как `error`.

## Связанные темы

- [[course/02-go/01-language/07-interfaces-nil-type-assertions|Интерфейсы, nil и type assertion]]
- [[course/02-go/01-language/09-defer-panic-recover|defer, panic и recover]]
- [[course/01-foundations/04-http-web/01-http-request-response|HTTP request/response]]
- [[course/02-go/index|Модуль Go]]

## Источники

- [Go `errors` package](https://pkg.go.dev/errors).
- [Go `fmt.Errorf` documentation](https://pkg.go.dev/fmt#Errorf).
- [Go blog: Working with Errors in Go 1.13](https://go.dev/blog/go1.13-errors).
- [Go blog: Error handling and Go](https://go.dev/blog/error-handling-and-go).
