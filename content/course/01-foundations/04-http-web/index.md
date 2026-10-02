---
title: HTTP и Web
description: Карта протоколов, браузерной безопасности и эволюции API для backend-интервью.
tags:
  - http
  - web
  - networking
  - api
  - interview
status: complete
difficulty: foundation
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# HTTP и Web

HTTP — прикладной протокол обмена сообщениями; Web добавляет браузер, происхождения, state и эволюцию публичного контракта. Этот раздел строит путь от одного запроса до выбора транспорта и безопасного изменения API.

## Карта раздела

1. [[course/01-foundations/04-http-web/01-http-request-response|HTTP: запрос и ответ]] — семантика методов, заголовков, статусов, кэшей и повторов.
2. [[course/01-foundations/04-http-web/02-http-1-1-connections|HTTP/1.1: соединения и ограничения]] — persistent connections, pipeline и head-of-line blocking.
3. [[course/01-foundations/04-http-web/03-http-2-streams-multiplexing|HTTP/2: streams и мультиплексирование]] — фреймы, flow control, HPACK и границы выигрыша.
4. [[course/01-foundations/04-http-web/04-http-3-quic|HTTP/3 и QUIC]] — UDP-транспорт, независимые потоки и миграция соединения.
5. [[course/01-foundations/04-http-web/05-rest-api-design|REST и дизайн API]] — ресурсы, идемпотентность, пагинация и ошибки.
6. [[course/01-foundations/04-http-web/06-rpc-grpc|RPC и gRPC]] — контракт, protobuf, streaming и deadline.
7. [[course/01-foundations/04-http-web/07-websocket-sse-long-polling|Realtime: WebSocket, SSE и long polling]] — однонаправленные и двунаправленные события.
8. [[course/01-foundations/04-http-web/08-cookies-sessions-cors-csrf|Браузерная безопасность и state]] — cookies, CORS, CSRF, SameSite и сессии.
9. [[course/01-foundations/04-http-web/09-api-versioning-compatibility|Совместимость API]] — additive changes, versioning и rollout.

## Зачем это на интервью

Интервьюер ожидает не перечень кодов, а объяснение контракта и последствий: можно ли повторить запрос, кто применяет CORS, почему p99 вырос на потере пакетов и как не сломать старый клиент. Ответ должен связывать семантику HTTP, сеть, безопасность и наблюдаемость.

## Минимум для E4

- [ ] Читать запрос и ответ: method, target, headers, body, status и cache directives.
- [ ] Отличать safe, idempotent и cacheable семантику от реализации конкретного handler.
- [ ] Знать различия HTTP/1.1, HTTP/2 и HTTP/3 на уровне соединений и потоков.
- [ ] Не путать browser-политику CORS с авторизацией сервера.

## Углубление для E5/Senior

- Выбирать транспорт по клиентам, loss profile, прокси, streaming и стоимости эксплуатации, а не по номеру версии.
- Проектировать retry, timeout, cancellation, rate limit и идемпотентность как единый контракт.
- Выпускать совместимые изменения с метриками клиентов, обратимой миграцией и явной политикой устаревания.

## Ключевые понятия

- **Origin** — схема, host и port; именно его сравнивает браузер для web-политик.
- **End-to-end header** проходит между клиентом и сервером; **hop-by-hop header** относится к одному соединению.
- **Stream** — логический канал внутри соединения HTTP/2 или HTTP/3; поток не равен TCP-соединению.
- **Deadline** ограничивает весь бюджет операции; timeout отдельного чтения не заменяет его.

## Типовые вопросы

1. **Почему `GET` не гарантирует отсутствие побочного эффекта?**
   - Это требование семантики метода, но сервер может нарушить контракт; клиент и промежуточный кэш вправе рассчитывать на safe-семантику.
2. **Где живёт CORS?**
   - В браузере. Сервер выдаёт заголовки, но non-browser клиент их не применяет.
3. **Устраняет ли HTTP/2 все head-of-line blocking?**
   - Он устраняет его между HTTP-стримами на прикладном уровне, но один потерянный TCP-сегмент задерживает байты всех потоков соединения.
4. **Почему retry опасен для `POST`?**
   - Ответ мог потеряться после применения операции; нужен idempotency key или иной механизм дедупликации.
5. **Когда HTTP/3 не даст ожидаемого улучшения?**
   - При CPU-нагрузке TLS/QUIC, коротких локальных соединениях или посредниках без поддержки; измеряют end-to-end p95/p99 и ошибки.

## Практика

- [ ] Снимите `curl -v` для cacheable `GET` и mutating запроса; критерий: объяснены все request/response headers и допустимость retry.
- [ ] В Go-сервисе задайте deadline, propagation cancellation и idempotency key; критерий: повтор одного ключа не создаёт второй ресурс.
- [ ] Сравните HTTP/1.1 и HTTP/2 под искусственной потерей пакетов; критерий: есть график p99 и сформулированная причина различий.

## Частые ошибки и ловушки

- Называть любой `POST` неидемпотентным, а любой `PUT` идемпотентным без проверки эффекта реализации.
- Отвечать `200` на ошибку в теле и лишать промежуточные системы семантики статуса.
- Настраивать CORS как замену authentication/authorization.
- Включать HTTP/3 без метрик handshake, retransmission, CPU и реальной поддержки клиентов.

## Связанные темы

[[course/01-foundations|База разработки и Computer Science]] · [[course/09-linux-networking|Linux и сети]] · [[course/11-security|Безопасность]] · [[course/07-distributed-systems|Распределённые системы]] · [[course/08-system-design|System Design]]

## Источники

- RFC 9110, _HTTP Semantics_; RFC 9111, _HTTP Caching_; RFC 9112, _HTTP/1.1_.
- RFC 9113, _HTTP/2_; RFC 9114, _HTTP/3_; RFC 9000, _QUIC_.
- MDN Web Docs: _HTTP_, _CORS_, _Cookies_.
