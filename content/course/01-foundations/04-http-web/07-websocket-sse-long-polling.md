---
title: "WebSocket, SSE и long polling: доставка обновлений"
description: "Как выбрать транспорт realtime-обновлений, обеспечить восстановление, порядок, backpressure и безопасное завершение соединений."
tags:
  - websocket
  - sse
  - realtime
  - http
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# WebSocket, SSE и long polling: доставка обновлений

Realtime обычно означает не магическую «мгновенность», а сокращение задержки между изменением состояния и уведомлением клиента. WebSocket даёт двунаправленный канал после HTTP upgrade. Server-Sent Events (SSE) оставляет обычный HTTP response, который сервер держит открытым и пишет события только в сторону браузера. Long polling удерживает запрос до события или timeout, затем клиент немедленно делает следующий.

## Зачем это на интервью

Нужно обосновать выбор транспорта через направление данных, прокси, масштабирование, reconnect и потерю сообщений. Интервьюер ищет понимание, что websocket не заменяет авторизацию, durable storage и API чтения состояния.

## Минимум для E4

- [ ] Выбирать SSE для server-to-client событий в браузере, WebSocket для настоящей двунаправленной интерактивности, long polling как совместимый простой fallback.
- [ ] Считать уведомление подсказкой обновить состояние: клиент умеет повторно прочитать ресурс через обычный API.
- [ ] Реализовать reconnect с экспоненциальной задержкой и jitter; не создавать reconnect storm.
- [ ] Ограничивать число соединений, размер очереди каждого клиента, размер сообщения и частоту событий.
- [ ] Проверять аутентификацию при handshake, авторизацию на каждом channel/topic и отзывать доступ при смене прав.
- [ ] Отправлять heartbeat/ping и корректно закрывать соединение при shutdown/deadline.

## Углубление для E5/Senior

Соединение — состояние конкретного процесса, а подписки и события часто должны переживать его рестарт. При горизонтальном масштабировании сообщения публикуют через broker или event log, но нельзя считать broker delivery пользовательской гарантией. Выберите и документируйте семантику: at-most-once допускает пропуск, at-least-once требует дедупликации по event ID, exactly-once почти всегда заменяется идемпотентным применением состояния.

Порядок имеет область. Один TCP/WebSocket stream сохраняет порядок bytes данного соединения, но несколько серверов, reconnect и несколько producer не дают глобального порядка. Практический контракт: `entity_id`, монотонный `revision` или `event_id`; клиент применяет только более новую revision, а после gap делает snapshot read. Это проще и надёжнее, чем пытаться «дослать всё» из памяти gateway.

SSE поддерживает `id:` и браузерный `Last-Event-ID`; это полезно для ограниченного replay, если сервер реально хранит журнал. Без журнала `Last-Event-ID` не восстанавливает прошлое. SSE автоматически использует cookies same-origin, поэтому защита origin/CSRF для команд остаётся важной; `EventSource` стандартно не позволяет произвольные request headers, что влияет на bearer-token дизайн. WebSocket handshake начинается как HTTP, но после upgrade привычные HTTP middleware/limits могут не примениться автоматически.

Backpressure нельзя решать безграничным buffered channel. У медленного клиента задайте bounded queue и политику: coalesce последнюю цену/состояние, отбросить noncritical event или закрыть и дать переподключиться. Не допускайте, чтобы один клиент удерживал producer lock или общую очередь. Метрики должны включать active connections, reconnect rate, dropped events, очередь, lag и причины close.

## Ключевые понятия

| Транспорт    | Направление                     | Сильная сторона                                 | Ограничение                                  |
| ------------ | ------------------------------- | ----------------------------------------------- | -------------------------------------------- |
| WebSocket    | Двунаправленно                  | Чат, совместное редактирование, игровые команды | Stateful connection и сложнее proxy/security |
| SSE          | Сервер → браузер                | Простые события поверх HTTP, auto reconnect     | Нет клиентских сообщений в том же канале     |
| Long polling | Клиент запрашивает, сервер ждёт | Работает через консервативную инфраструктуру    | Больше запросов и latency между циклами      |
| Polling      | Клиент периодически читает      | Самая простая консистентность                   | Лишние запросы и задержка                    |

### SSE-поток

```text
event: order.updated
id: 8231
data: {"orderId":"ord_42","revision":17}

```

Клиент не должен полагаться, что payload содержит полный, авторизованный snapshot. Он сопоставляет revision и при необходимости делает `GET /orders/ord_42`. Это снижает риск устаревшей схемы события и упрощает восстановление после reconnect.

## Типовые вопросы

1. **Почему не всегда WebSocket?**
   - Если сообщения идут только от сервера, SSE проще проходит через HTTP-инфраструктуру и имеет встроенный reconnect. Для редких обновлений достаточно polling.
2. **Гарантирует ли WebSocket доставку бизнес-события?**
   - TCP доставляет bytes в живом соединении, но disconnect/restart оставляет gap. Бизнес-гарантию дают durable log, revision и повторное чтение.
3. **Как клиент узнаёт о пропуске событий?**
   - Сравнивает revision/event sequence; при дыре или reconnect запрашивает актуальный snapshot либо replay с серверной позиции.
4. **Как бороться с медленным подписчиком?**
   - Bounded queue, coalescing/drop policy или close. Никогда не накапливать неограниченные сообщения в памяти процесса.
5. **Достаточно ли проверить токен при WebSocket connect?**
   - Нет, права на topic и их отзыв могут меняться. Проверяйте доступ при subscribe и определите revalidation/revocation policy.
6. **Что делает `Last-Event-ID` в SSE?**
   - Передаёт последнюю полученную позицию при reconnect; сервер может начать replay только если хранит доступный журнал событий.

## Практика

- [ ] Постройте SSE уведомления о смене заказа.
  - Критерии приёмки: каждое событие содержит `id`, `orderId`, revision; reconnect передаёт `Last-Event-ID`; при недоступном replay клиент читает snapshot; тест проверяет gap и дедупликацию.
- [ ] Реализуйте WebSocket room с ограничениями.
  - Критерии приёмки: subscribe авторизован на room; входящее сообщение имеет limit и schema validation; slow client не увеличивает память без границы; graceful shutdown отправляет close frame и завершает goroutine.
- [ ] Нагрузочно проверьте disconnect storm.
  - Критерии приёмки: reconnect использует capped exponential backoff с jitter; метрики показывают reconnects/drops/queue depth; после рестарта клиента данные сходятся со snapshot API.

## Частые ошибки и ловушки

- Хранить единственную копию важного события в памяти websocket-сервера.
- Передавать полные модели в каждое событие и забывать о версии схемы/правах доступа.
- Делать busy reconnect без задержки и тем самым усиливать outage.
- Считать порядок нескольких соединений глобальным.
- Не отключать timer, subscription и goroutine после close.
- Открывать WebSocket без ограничения origin, message size и rate limit.

## Связанные темы

[[course/01-foundations/index|База разработки и Computer Science]] · [[course/01-foundations/04-http-web/05-rest-api-design|REST-дизайн API]] · [[course/01-foundations/04-http-web/06-rpc-grpc|RPC и gRPC]] · [[course/01-foundations/04-http-web/08-cookies-sessions-cors-csrf|Cookies, сессии, CORS и CSRF]]

## Источники

- RFC 6455 — The WebSocket Protocol.
- WHATWG HTML Living Standard: Server-sent events и `EventSource`.
- MDN Web Docs: WebSocket API, Using server-sent events.
- IETF RFC 9110 — HTTP semantics и connection handling.
