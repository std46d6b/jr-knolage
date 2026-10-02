---
title: "Ошибки и observability в Go"
description: "Контракт ошибок, структурированные логи, метрики и трассировка для интервью и production-кода."
tags:
  - go
  - errors
  - observability
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Ошибки и observability в Go

## Зачем это на интервью

Production-код должен дать клиенту предсказуемую реакцию, оператору — достаточный контекст, а разработчику — возможность классифицировать сбой. На интервью слабый ответ ограничивается `fmt.Println(err)`; сильный сохраняет причину, границу ответственности и сигнал для диагностики.

## Минимум для E4

Возвращайте ошибку вызывающему уровню, добавляя операцию и `%w`, если первопричина нужна для `errors.Is`/`errors.As`. Sentinel подходит для устойчивой категории (`ErrNotFound`), typed error — когда вызывающему нужны данные. Не сравнивайте обёрнутую ошибку через `==`. Логируйте на границе, где ошибка обрабатывается: повторное логирование на каждом слое создаёт шум.

```go
package payment

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
)

var ErrDeclined = errors.New("payment declined")

type Gateway interface {
	Charge(context.Context, string, int64) error
}

func Charge(ctx context.Context, log *slog.Logger, gw Gateway, orderID string, cents int64) error {
	if err := gw.Charge(ctx, orderID, cents); err != nil {
		if errors.Is(err, ErrDeclined) {
			log.Info("payment declined", "order_id", orderID)
			return ErrDeclined
		}
		log.Error("charge gateway failed", "order_id", orderID, "error", err)
		return fmt.Errorf("charge order %s: %w", orderID, err)
	}
	return nil
}
```

В production не добавляйте в лог номер карты, token, пароль, body запроса без redaction. Для HTTP внешний ответ обычно не раскрывает внутреннюю ошибку, но содержит request/trace ID для поддержки.

## Углубление для E5/Senior

Разделяйте доменные, инфраструктурные и transport-ошибки. На boundary централизованно маппируйте их на status/retry policy, сохраняя cause для логов и traces. Задавайте telemetry как контракт: названия метрик, единицы и допустимые labels; `order_id` или email не являются label Prometheus из-за высокой cardinality. Прокидывайте trace context в HTTP/gRPC и сообщения, применяйте sampling осознанно.

Ошибка не всегда требует `Error`-лога: ожидаемое отсутствие сущности может быть `Info` или метрикой результата. Alert строят на пользовательском симптоме/SLO, а не на каждой строке лога.

## Ключевые понятия

- **Wrapping**: `%w` сохраняет цепочку причин; `%v` — только текст.
- **`errors.Is` / `errors.As`**: проверяют категорию или извлекают тип по цепочке.
- **Structured logging**: событие и поля, пригодные для машинного поиска.
- **RED**: rate, errors, duration; для сервиса это базовый набор метрик.
- **Correlation**: request ID/trace ID связывает лог, метрику и trace без помещения ID в metric labels.
- **Cardinality**: число комбинаций labels; неограниченные значения повышают стоимость и могут сломать monitoring.

## Типовые вопросы

1. **Когда использовать sentinel, а когда typed error?**
   - Sentinel для устойчивого факта, typed error — когда обработчику нужны поля; оба должны быть частью осмысленного контракта.
2. **Почему `err == ErrNotFound` ненадёжно?**
   - После `%w` объект ошибки другой; используйте `errors.Is(err, ErrNotFound)`.
3. **Где логировать ошибку?**
   - Там, где принято решение обработать её или она покидает процесс/запрос; нижний слой обычно добавляет контекст и возвращает.
4. **Какие поля нельзя писать в логи?**
   - Пароли, access tokens, платёжные данные, секреты и лишние PII; применяйте allowlist и redaction.
5. **Почему `user_id` плохой label метрики?**
   - Он создаёт практически неограниченное число временных рядов; ID лучше оставить в логах/traces.

## Практика

- [ ] Реализуйте HTTP mapping для `ErrDeclined`, `context.DeadlineExceeded` и неизвестной ошибки.
- [ ] Напишите тесты на `errors.Is` для обёрнутых ошибок и на отсутствие внутреннего текста в JSON-ответе.
- [ ] Добавьте структурированный лог на границе handler и счётчик `requests_total` только с labels `method`, `route`, `status`.

**Критерии готовности:** причина классифицируется после wrapping, клиент не получает секрет/stack trace, лог содержит безопасный request context, а labels имеют конечное множество значений.

## Частые ошибки и ловушки

- Оборачивать ошибку через `%v`, а затем ожидать `errors.Is`.
- Логировать и возвращать одно и то же исключение на каждом слое.
- Превращать все ошибки в один HTTP 500 или, наоборот, раскрывать ошибку БД клиенту.
- Добавлять ID пользователя, URL с query-параметрами или текст ошибки как label метрики.

## Связанные темы

[[course/02-go/08-interview-code|Go-код на интервью]] · [[course/10-observability|Observability]] · [[course/01-foundations/04-http-web/01-http-request-response|HTTP]]

## Источники

- [Package errors](https://pkg.go.dev/errors) — проверено 2026-10-02.
- [log/slog package](https://pkg.go.dev/log/slog) — проверено 2026-10-02.
- [OpenTelemetry Go](https://opentelemetry.io/docs/languages/go/) — проверено 2026-10-02.
- [Prometheus metric and label naming](https://prometheus.io/docs/practices/naming/) — проверено 2026-10-02.
