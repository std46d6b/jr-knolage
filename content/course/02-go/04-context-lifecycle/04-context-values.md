---
title: "Значения в Context: metadata без скрытых зависимостей"
description: "Когда Context values оправданы, как выбирать ключи и почему dependencies, optional parameters и бизнес-данные передают явно."
tags:
  - go
  - context
  - api-design
  - observability
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Значения в Context: metadata без скрытых зависимостей

`Context.Value` предназначен для request-scoped данных, которые пересекают process/API boundary: trace/span ID, correlation ID, authentication principal, locale — если их получение на каждом слое было бы неразумным. Value не заменяет аргументы функции, configuration или dependency injection. Ключ и значение должны быть маленькими, безопасными и понятными по lifetime.

## Зачем это на интервью

Context values удобны и поэтому быстро превращаются в service locator: logger, DB, feature flags, user input и десятки optional параметров исчезают из сигнатур. Нужно объяснить, почему это ломает тестируемость и контракт, и показать type-safe локальный key для действительно request-scoped metadata.

## Минимум для E4

- [ ] Класть только request-scoped metadata, а обязательные данные передавать явными параметрами.
- [ ] Использовать неэкспортируемый собственный тип ключа, не string и не built-in type.
- [ ] Делать accessor с type assertion и documented fallback; не panic на недоверенном context.
- [ ] Не помещать secret, mutable map, большой object graph или connection в context.
- [ ] Не хранить context в struct и не извлекать values deep в domain без ясной причины.

## Углубление для E5/Senior

E5 определяет trust boundary: client-supplied `X-Request-ID` валидируется/заменяется, identity формируется authentication middleware, tracing propagator использует стандартный формат и не превращает arbitrary headers в attributes. Он следит за cardinality и PII: ID может быть полезен в log, но email/токен не должны стать label или error text.

## Ключевые понятия

| Допустимо               | Почему                                | Не следует класть                            |
| ----------------------- | ------------------------------------- | -------------------------------------------- |
| Trace/correlation ID    | Нужен по цепочке логов и RPC          | `*sql.DB`, `*http.Client`, logger dependency |
| Auth principal          | Принадлежит конкретному request       | Пароль, bearer token, PII без политики       |
| Locale/request metadata | Сквозной optional context             | Обязательный `userID`, filter, pagination    |
| Span context            | Стандартная observability propagation | Mutable map/cache/large payload              |

### Локальный тип ключа и accessor

```go
package requestmeta

import "context"

type requestIDKey struct{}

func WithRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, requestIDKey{}, id)
}

func RequestID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(requestIDKey{}).(string)
	return id, ok && id != ""
}
```

Ключ без экспорта исключает collision с другим пакетом; zero-size struct не выделяет память. Пакет-владелец предоставляет accessor, поэтому потребители не копируют type assertion. Для нескольких полей лучше typed struct как value, но не изменяйте его после помещения в context.

### Middleware с validation

```go
package requestmeta

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"strings"
)

func newID() string {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return "generated-id-unavailable"
	}
	return hex.EncodeToString(buf)
}

func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := strings.TrimSpace(r.Header.Get("X-Request-ID"))
		if len(id) == 0 || len(id) > 128 {
			id = newID()
		}
		next.ServeHTTP(w, r.WithContext(WithRequestID(r.Context(), id)))
	})
}
```

Imports: `net/http`, `strings`. Не доверяйте header как безопасному trace ID и не отражайте его в response/log без лимита и sanitization. `newID` намеренно является dependency конкретного приложения: документируйте формат и collision policy.

## Типовые вопросы

1. **Почему string — плохой ключ?**
   - Любой пакет может использовать то же значение и получить collision; private named type создаёт namespace.
2. **Можно ли хранить logger в context?**
   - Обычно нет: logger — dependency процесса. Лучше передать его в constructor, а request ID/spans добавить через middleware/adapter.
3. **Почему `userID` иногда value, а иногда параметр?**
   - Для authorization middleware principal может быть request metadata; если use case требует ID для смысла операции, явный параметр делает контракт видимым.
4. **Можно ли менять map, помещённую в context?**
   - Не следует: contexts разделяются между goroutine, mutable value создаёт race и неявный ownership.
5. **Как тестировать accessor?**
   - Проверить empty context, корректный value и foreign value wrong type; accessor не должен panic.
6. **Нужно ли использовать values для OpenTelemetry?**
   - Используйте официальный propagator/SDK: он сам хранит span context по соглашению и соблюдает transport format.

## Практика

- [ ] Реализуйте middleware correlation ID и structured log adapter.
  - Критерии приёмки: ID ограничен и валидирован; downstream получает его через accessor; log не содержит auth header/PII; тестирует отсутствие и некорректный header.
- [ ] Отрефакторьте функцию, читающую `*sql.DB` из context.
  - Критерии приёмки: DB передаётся через constructor; business inputs стали параметрами; тест использует fake/repository interface без context value.

## Частые ошибки и ловушки

- Использовать string key вроде `"user"` в публичном пакете.
- Прятать feature flag или transaction в values вместо явного API.
- Сохранять context в `Client` и использовать после исходного request.
- Логировать все values «для диагностики»: это может раскрыть PII/секреты.

## Связанные темы

[[course/02-go/04-context-lifecycle|Context и жизненный цикл]] · [[course/02-go/04-context-lifecycle/01-context-basics-propagation|Propagation]] · [[course/10-observability|Наблюдаемость]] · [[course/01-foundations/03-design-principles/06-dependency-inversion-injection|DIP и DI]]

## Источники

- [Go `context` package documentation](https://pkg.go.dev/context#Context) — intended use of values and key guidance.
- [Go blog: Context](https://go.dev/blog/context) — request-scoped data rationale.
- [OpenTelemetry Go context propagation](https://opentelemetry.io/docs/languages/go/propagation/) — standard trace propagation.
- [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html) — PII и safe logging.
