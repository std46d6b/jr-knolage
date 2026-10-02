---
title: "Версионирование и совместимость API"
description: "Как безопасно развивать публичные и внутренние API: определять breaking changes, мигрировать клиентов и управлять жизненным циклом контрактов."
tags:
  - api
  - versioning
  - compatibility
  - contracts
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Версионирование и совместимость API

Версионирование API — не подстановка `/v2` в URL, а управление обещанием клиентам. Совместимое изменение сохраняет корректность существующего клиента при новом сервере и нового клиента при старом сервере в оговорённом окне. Несовместимость бывает wire-, source- и семантической: поле может оставаться JSON string, но сменить единицы денег или значение по умолчанию — и сломать бизнес-логику без ошибки парсинга.

## Зачем это на интервью

Интервьюер проверяет, умеет ли кандидат расширять контракт без «сегодня деплоим сервер, завтра все обновят приложение». Хороший ответ называет consumers, аналитические пайплайны, mobile-версии, SDK, кеши и deprecation-план с измерением фактического использования.

## Минимум для E4

- [ ] Считать добавление optional response field обычно совместимым, но проверять клиентов со строгой схемой и подписью payload.
- [ ] Не удалять/переименовывать поле, endpoint, enum value или менять тип/единицы без миграционного периода.
- [ ] Различать отсутствие поля, `null`, пустое значение и новое default-значение в контракте.
- [ ] Публиковать схему и changelog; проверять request/response через contract tests.
- [ ] Добавлять новую возможность аддитивно, запускать dual-read/dual-write при необходимости и мигрировать consumers по telemetry.
- [ ] Заранее объявлять deprecation, срок поддержки и понятный путь перехода.

## Углубление для E5/Senior

Есть несколько стратегий версии: URI (`/v1/...`) прост для маршрутизации и документации; media type/`Accept` даёт версию представления; header/query параметр менее заметен в ссылках и кешах. Выбор важнее единообразием и операционным lifecycle. Не создавайте новую major version для каждого нового поля: чрезмерные версии умножают клиенты и security patches. Major version оправдана, когда additive migration невозможна или новая доменная модель должна сосуществовать со старой.

Расширение response безопасно только для tolerant reader. Некоторые клиенты запрещают unknown fields, подписывают canonical JSON или генерируют закрытые enum. Даже добавление enum value может сломать switch без default или UI, который считает набор исчерпывающим. В protobuf unknown fields обычно переживают прокси, но нельзя переиспользовать field numbers; в JSON правило «ignore unknown» нужно явно проверить SDK и validators.

Изменение write-контракта требует staged rollout. Сначала сервер принимает старый и новый request, пишет новое каноническое представление, при необходимости возвращает старое поле. Затем обновляются producers, а после подтверждённого отсутствия старого трафика поле объявляется deprecated и удаляется в следующем согласованном major/сроке. Dual-write нельзя оставлять навсегда: определите source of truth, сверку расхождений, backfill и дату удаления compatibility code.

Consumer-driven contract testing полезно, если provider проверяет реальные ожидания критичных клиентов. Но это не освобождает от semantic tests: JSON schema не покажет, что `amount` сменил dollars на cents. Наблюдайте version/header, endpoint, deprecated field use, ошибочные декодирования и долю активных клиентов. Kill switch/fallback и canary позволяют остановить rollout до массовой поломки.

## Ключевые понятия

| Изменение                       | Обычно совместимо?       | Безопасный путь                                 |
| ------------------------------- | ------------------------ | ----------------------------------------------- |
| Новое optional поле response    | Да, при tolerant readers | Проверить SDK и строгие validators              |
| Новое обязательное поле request | Нет                      | Сделать optional, дать default/migration        |
| Удаление/переименование поля    | Нет                      | Add new → migrate → deprecate → remove          |
| Новый enum value                | Рискованно               | Клиентам нужен default/unknown branch           |
| Изменение типа или единиц       | Нет                      | Новое поле с явным именем и параллельный период |
| Новый endpoint                  | Да                       | Документировать auth, quotas и lifecycle        |

### Аддитивная миграция суммы

Плохое изменение: оставить `amount: 12.50`, но сменить смысл с рублей на копейки. Клиент декодирует число и выставляет неверный счёт.

Лучше ввести явное поле и переходный ответ:

```json
{
  "amount": "12.50",
  "currency": "RUB",
  "amountMinor": 1250,
  "amountFormat": "minor-unit"
}
```

После миграции клиентов удалять старое поле можно только по заранее опубликованной политике. Документация фиксирует точность, rounding и ISO 4217 currency, а тесты покрывают оба representations.

## Типовые вопросы

1. **Всегда ли добавление поля response совместимо?**
   - Нет. Tolerant reader обычно переживёт его, но строгая schema, подпись или generated enum/client могут сломаться; это проверяют на реальных consumers.
2. **Почему новый enum value — риск?**
   - Старый клиент может иметь исчерпывающий switch, отвергать значение validator-ом или выбрать опасный default.
3. **Как удалить deprecated endpoint?**
   - Объявить replacement и дату, инструментировать использование, уведомить owners, мигрировать/блокировать оставшихся по политике, затем удалить с мониторингом и rollback plan.
4. **Когда выбирать `/v2`?**
   - При крупном несовместимом контракте или параллельной модели. Добавление optional поля обычно не требует новой major версии.
5. **Почему schema validation недостаточна?**
   - Она не проверяет смысл: единицы, timezone, idempotency, ordering, default и права доступа могут измениться при прежней форме JSON.
6. **Что такое dual-write risk?**
   - Две копии данных расходятся из-за частичного отказа или разного порядка. Нужны transaction/outbox, сверка и один source of truth.

## Практика

- [ ] Проведите миграцию поля `displayName` в `profile.name`.
  - Критерии приёмки: сервер принимает старый и новый request в переходный период; response документирует оба поля; telemetry считает старое использование; contract tests запускаются для старого и нового клиента; есть дата удаления.
- [ ] Добавьте enum `status=paused` без поломки клиентов.
  - Критерии приёмки: SDK имеет unknown/default branch; UI не выполняет опасное действие для неизвестного статуса; provider contract test покрывает старый client; dashboard показывает версии consumers.
- [ ] Опишите и отрепетируйте deprecation endpoint.
  - Критерии приёмки: опубликованы replacement, owner, SLA и sunset date; response содержит документированное предупреждение; canary измеряет error rate; rollback не требует восстановления удалённой схемы из backup.

## Частые ошибки и ловушки

- Версионировать каждый endpoint независимо без единой политики и оставлять бесконечный набор старых API.
- Называть изменение единиц/временной зоны «неbreaking», потому что JSON type не поменялся.
- Добавлять required request field без default и без анализа старых mobile-клиентов.
- Переиспользовать значение enum, protobuf tag или удалённый идентификатор для нового смысла.
- Удалять compatibility code по дате без telemetry и владельцев consumers.
- Забывать версионировать события, SDK, webhooks и кешированные representations вместе с REST endpoint.

## Связанные темы

[[course/01-foundations/index|База разработки и Computer Science]] · [[course/01-foundations/04-http-web/05-rest-api-design|REST-дизайн API]] · [[course/01-foundations/04-http-web/06-rpc-grpc|RPC и gRPC]] · [[course/01-foundations/04-http-web/07-websocket-sse-long-polling|WebSocket, SSE и long polling]]

## Источники

- OpenAPI Specification 3.1 — описания контрактов и schema evolution.
- Google API Improvement Proposals: AIP-180 (backwards compatibility), AIP-185 (versioning), AIP-215 (versioned packages).
- Protocol Buffers Documentation: updating a message type и reserved fields.
- Martin Fowler, _Tolerant Reader_ и Consumer-Driven Contracts.
- RFC 8594 — `Sunset` HTTP header для уведомления о прекращении сервиса.
