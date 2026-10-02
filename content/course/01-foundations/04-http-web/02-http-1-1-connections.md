---
title: HTTP/1.1: соединения и ограничения
description: Persistent connections, порядок ответов, pipeline, head-of-line blocking и эксплуатация HTTP/1.1.
tags:
  - http
  - http-1-1
  - networking
  - performance
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# HTTP/1.1: соединения и ограничения

HTTP/1.1 обычно использует одно TCP-соединение для нескольких последовательных request/response обменов. Persistent connection уменьшает цену TCP/TLS handshake, но порядок байтов в TCP и порядок ответов HTTP/1.1 создают очереди: медленный ранний ответ может задержать следующий.

## Зачем это на интервью

Нужно уметь объяснить, почему «keep-alive включён» не означает отсутствия latency-проблем, как выбрать размер connection pool и почему прокси обязан правильно обработать границы сообщений. Это базис для осмысленного перехода к HTTP/2 и HTTP/3.

## Минимум для E4

- [ ] Знать, что HTTP/1.1 persistent connections включены по умолчанию, если не указан `Connection: close`.
- [ ] Отличать TCP-соединение от HTTP-запроса и понимать последовательность ответов.
- [ ] Объяснять head-of-line blocking в HTTP/1.1 и назначение нескольких соединений.
- [ ] Ограничивать idle connections, время чтения header/body и число одновременных запросов.

Границу тела определяют `Content-Length`, `Transfer-Encoding: chunked` либо закрытие соединения в допустимых сценариях. Одновременное наличие `Content-Length` и `Transfer-Encoding` — опасный сигнал: intermediaries должны применять правила RFC, иначе возможен request smuggling. `chunked` — framing HTTP/1.1, не свойство payload и не «потоковый JSON».

## Углубление для E5/Senior

HTTP pipelining разрешал отправить несколько запросов до получения ответов, но ответы всё равно должны идти в порядке запросов. Из-за неправильной реализации посредников и блокировки он практически не используется браузерами. Клиенты обходили проблему параллельными TCP-соединениями, но это увеличивает handshake, congestion control state, FD и давление на upstream.

Connection pool — очередь с ограниченными ресурсами. Слишком малый pool создаёт wait time до отправки; слишком большой перегружает upstream и скрывает отсутствие backpressure. Измеряйте connection acquisition latency, in-flight requests, reuse ratio, handshake, ошибки и p99 отдельно для клиента и сервера. Таймауты должны покрывать acquire, connect, TLS, header и полный request deadline.

## Ключевые понятия

- **Keep-alive/persistent connection** — повторное использование TCP-соединения для нескольких обменов.
- **HOL blocking** — задержка готовой работы за более ранней работой в одной очереди.
- **Pipelining** — несколько отправленных подряд запросов без ожидания ответа; порядок ответов остаётся строгим.
- **Chunked transfer coding** — способ определить конец тела при неизвестной длине; каждый chunk имеет размер в hex.
- **Request smuggling** — рассинхронизация границ запроса между прокси и origin.

## Типовые вопросы

1. **Сколько запросов можно обслужить на keep-alive соединении?**
   - Много последовательно; сервер и клиент задают свои лимиты/idle timeout. Это не означает одновременную независимую обработку ответов на проводе.
2. **Почему браузер открывал несколько соединений к origin?**
   - Чтобы обойти HOL blocking HTTP/1.1 и получить параллелизм, ценой лишних TCP/TLS состояний.
3. **Зачем `Content-Length`?**
   - Он задаёт точную границу тела и позволяет reuse соединения; неверный размер нарушает framing следующего сообщения.
4. **Чем chunked отличается от compression?**
   - Chunked определяет передачу и конец тела, compression (`Content-Encoding`) преобразует representation; их нельзя смешивать.
5. **Почему timeout idle connection не равен deadline запроса?**
   - Idle timeout закрывает неиспользуемый socket; deadline ограничивает конкретную работу, включая ожидание pool и ответ.
6. **Почему нельзя просто отключить keep-alive при ошибках?**
   - Это маскирует bug и кратно увеличивает handshake/ephemeral ports; сначала надо проверить framing, таймауты и lifecycle body.

## Практика

- [ ] Запустите slow endpoint и быстрый endpoint через одно HTTP/1.1 соединение; критерий: в trace видно, что быстрый ответ задержан порядком, и описан обход.
- [ ] Отправьте корректный chunked response и проверьте его `curl --raw`; критерий: клиент получает тело, а соединение безопасно переиспользуется.
- [ ] Настройте Go `http.Transport`; критерий: заданы `MaxIdleConns`, `MaxConnsPerHost`, dial/TLS/header timeouts, а тест доказывает закрытие response body.

## Частые ошибки и ловушки

- Считать HTTP/1.1 «один запрос на одно соединение» или считать keep-alive неограниченным ресурсом.
- Не закрывать `resp.Body`, из-за чего соединение не возвращается в pool.
- Давать frontend и backend разную трактовку `Content-Length`/`Transfer-Encoding`.
- Выбирать pool по CPU, игнорируя лимиты upstream, FD и очередь ожидания.

## Связанные темы

[[course/01-foundations/04-http-web|HTTP и Web]] · [[course/01-foundations/04-http-web/01-http-request-response|HTTP: запрос и ответ]] · [[course/01-foundations/04-http-web/03-http-2-streams-multiplexing|HTTP/2: streams]] · [[course/09-linux-networking|Linux и сети]] · [[course/10-observability|Наблюдаемость]]

## Источники

- RFC 9112, _HTTP/1.1_, sections on message framing and persistent connections.
- RFC 9110, _HTTP Semantics_.
- PortSwigger Web Security Academy: _HTTP request smuggling_.
- Go documentation: `net/http` and `http.Transport`.
