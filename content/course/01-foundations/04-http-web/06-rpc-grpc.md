---
title: "RPC и gRPC: контрактные вызовы между сервисами"
description: "Как выбирать RPC/gRPC, проектировать protobuf-контракт, понимать streaming, deadline, ретраи и совместимость."
tags:
  - rpc
  - grpc
  - protobuf
  - distributed-systems
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# RPC и gRPC: контрактные вызовы между сервисами

RPC (Remote Procedure Call) представляет удалённую операцию как вызов метода. gRPC — распространённая реализация RPC поверх HTTP/2, обычно с Protocol Buffers: `.proto` описывает service и messages, генератор создаёт типизированные клиент и сервер. Удобство локального вызова не отменяет главного факта: сеть может потерять запрос, ответ или соединение, а сервер может выполнить операцию до timeout клиента.

## Зачем это на интервью

Тема показывает зрелость в межсервисном взаимодействии. От кандидата ждут не «gRPC быстрее JSON», а объяснение контракта, дедлайна, отмены, повторов, баланса нагрузки, observability и совместимой эволюции protobuf.

## Минимум для E4

- [ ] Различать unary RPC, server streaming, client streaming и bidirectional streaming.
- [ ] Передавать deadline на каждый исходящий вызов; не использовать бесконечный default timeout.
- [ ] Понимать, что retry безопасен только для идемпотентной операции или при явном идемпотентном ключе.
- [ ] Выбирать gRPC status codes: `INVALID_ARGUMENT`, `NOT_FOUND`, `ALREADY_EXISTS`, `FAILED_PRECONDITION`, `ABORTED`, `UNAVAILABLE`, `DEADLINE_EXCEEDED`, а не прятать ошибку в успешном response.
- [ ] Валидировать message на границе, ограничивать размер и число элементов stream, проверять аутентификацию и авторизацию на сервере.
- [ ] Передавать trace context и request metadata по правилам доверенной инфраструктуры, не как неограниченный пользовательский payload.

## Углубление для E5/Senior

HTTP/2 multiplexing уменьшает число TCP-соединений и допускает много streams, но не гарантирует отсутствие head-of-line blocking: потеря пакета тормозит TCP-поток целиком. При больших потоках и медленном consumer важны flow control, лимиты сообщений и backpressure. Нельзя бесконечно читать channel/stream в память: получатель должен обрабатывать данные инкрементально, а отправитель — уважать `context` и ошибки `Send`.

Deadline — бюджет, а не только timeout клиента. Верхний сервис принимает остаток бюджета, тратит часть на очередь/обработку и передаёт дочернему вызову меньший deadline. Если каждый слой выставляет новый независимый 1-second timeout, end-to-end latency становится непредсказуемой. Отмена клиента не является атомарным откатом: сервер обязан сделать операции идемпотентными, транзакционными или продолжить work в явной durable job.

Ретраи, hedging и circuit breaker меняют нагрузку. Автоматический retry `UNAVAILABLE` без jitter и лимита способен усилить аварию; повтор после `DEADLINE_EXCEEDED` особенно опасен, поскольку сервер мог завершить запись. Применяйте budget ретраев, экспоненциальную задержку с jitter, только разрешённые коды и метрики attempt/result. Health checking не заменяет readiness конкретной зависимости и не должен быть единственным основанием для решения о запросе.

Protobuf не self-describing на проводе как JSON. Tag number — часть wire contract. Никогда не переиспользуйте удалённый номер; помечайте его `reserved`. Новое optional поле совместимо со старым читателем, но смена смысла, type или правила nullability может быть семантически несовместима. Для `oneof` продумывайте поведение неизвестного варианта и эволюцию клиентов.

## Ключевые понятия

| Понятие        | Смысл                              | Следствие                                        |
| -------------- | ---------------------------------- | ------------------------------------------------ |
| Unary          | Один request и один response       | Подходит для короткой операции чтения/команды    |
| Streaming      | Последовательность сообщений       | Нужны лимиты, cancellation и backpressure        |
| Deadline       | Последний момент полезности ответа | Пропагируется вниз по call graph                 |
| Metadata       | Заголовки gRPC                     | Для auth/trace, с ограничением размера и доверия |
| Status         | Машиночитаемый итог RPC            | Управляет retry и обработкой клиента             |
| Reserved field | Нельзя переиспользовать tag/name   | Предотвращает тихую порчу данных                 |

```proto
syntax = "proto3";
package catalog.v1;

service CatalogService {
  rpc GetProduct(GetProductRequest) returns (Product);
  rpc WatchStock(WatchStockRequest) returns (stream StockUpdate);
}

message GetProductRequest { string id = 1; }
message Product { string id = 1; string name = 2; int64 price_minor = 3; }
message StockUpdate { string product_id = 1; int64 available = 2; int64 revision = 3; }
```

`int64 price_minor` здесь намеренно хранит минимальные денежные единицы: floating-point делает контракт денег неоднозначным. Для внешнего публичного API подумайте также о JSON transcoding, совместимости ошибок и HTTP-политиках gateway.

## Типовые вопросы

1. **Почему gRPC не делает сетевой вызов «как локальную функцию»?**
   - Сеть допускает timeout, частичный отказ и повторную доставку; клиент может не узнать, выполнил ли сервер команду.
2. **Когда выбрать server streaming?**
   - Когда клиенту полезна последовательность обновлений или большой результат без ожидания полного массива; всё равно нужны reconnect и способ восстановить позицию.
3. **`DEADLINE_EXCEEDED` означает, что сервер ничего не сделал?**
   - Нет. Это факт о клиентском ожидании; сервер мог не начать, выполнять или уже завершить операцию.
4. **Чем `FAILED_PRECONDITION` отличается от `ABORTED`?**
   - Первое обычно требует изменить состояние/параметры до повтора, второе — конфликт конкурентной транзакции, где повтор всей read-modify-write последовательности может быть уместен.
5. **Почему нельзя менять тип protobuf-поля с тем же номером?**
   - Старый и новый код могут по-разному декодировать те же bytes; это wire-несовместимость даже при успешной компиляции.
6. **Нужен ли retry для `Get`?**
   - Иногда да, если чтение идемпотентно и есть остаток deadline. Но лимит попыток и jitter обязательны, иначе retry ухудшит отказ.

## Практика

- [ ] Реализуйте unary `GetProduct` и server-stream `WatchStock`.
  - Критерии приёмки: невалидный ID даёт `INVALID_ARGUMENT`; закрытие клиента отменяет handler; slow consumer не накапливает неограниченную память; тест читает несколько сообщений и проверяет порядок revision.
- [ ] Добавьте deadline и управляемый retry в клиент.
  - Критерии приёмки: дочерний вызов получает меньший бюджет; retry происходит только для выбранного идемпотентного метода и `UNAVAILABLE`; тесты проверяют jitter/лимит попыток и отсутствие retry при `INVALID_ARGUMENT`.
- [ ] Проведите эволюцию `.proto`.
  - Критерии приёмки: новое поле читает старый клиент; удалённый tag находится в `reserved`; CI запускает buf/protobuf compatibility check; сгенерированный код не редактируется вручную.

## Частые ошибки и ловушки

- Давать каждому RPC бесконечный timeout или создавать новый полный timeout на каждом уровне.
- Ретраить command после неизвестного исхода без идемпотентного ключа.
- Возвращать `OK` с полем `error`, из-за чего инфраструктура не видит неуспех.
- Считать stream бесконечно надёжным: нужны reconnect, cursor/revision и дедупликация.
- Передавать токены и персональные данные в логи metadata.
- Переиспользовать protobuf field number после удаления поля.

## Связанные темы

[[course/01-foundations/index|База разработки и Computer Science]] · [[course/01-foundations/04-http-web/05-rest-api-design|REST-дизайн API]] · [[course/01-foundations/04-http-web/07-websocket-sse-long-polling|WebSocket, SSE и long polling]] · [[course/01-foundations/04-http-web/09-api-versioning-compatibility|Версионирование и совместимость API]]

## Источники

- gRPC Documentation: concepts, deadlines, cancellation, retry, status codes.
- Protocol Buffers Language Guide (proto3) и protobuf.dev: field presence, `oneof`, reserved fields.
- RFC 7540 / RFC 9113 — HTTP/2 и управление потоками.
- Google API Improvement Proposals: AIP-194 (transient errors), AIP-151 (long-running operations).
