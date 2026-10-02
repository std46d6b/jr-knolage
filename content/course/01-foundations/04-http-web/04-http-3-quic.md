---
title: HTTP/3 и QUIC
description: Как QUIC поверх UDP даёт независимые потоки, быстрый handshake, migration и новые эксплуатационные trade-offs.
tags:
  - http
  - http-3
  - quic
  - udp
  - networking
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# HTTP/3 и QUIC

HTTP/3 переносит HTTP-семантику на QUIC. QUIC работает поверх UDP, но сам реализует надёжность, congestion control, TLS 1.3 handshake и streams. Потеря пакета в одном stream не блокирует доставку данных другого stream, потому что порядок применяется внутри stream, а не ко всему соединению.

## Зачем это на интервью

Тема проверяет способность отделить протокол от маркетингового тезиса «UDP быстрее TCP». QUIC не отказывается от надёжности; он переносит её в user space и меняет границы состояния, диагностики, балансировки и защиты от перегрузки.

## Минимум для E4

- [ ] Знать, что HTTP/3 использует QUIC поверх UDP, а QUIC включает TLS 1.3.
- [ ] Отличать stream-level ordering QUIC от byte-stream ordering TCP.
- [ ] Объяснять connection ID, connection migration и 0-RTT с ограничением на повтор.
- [ ] Проверять поддержку сети и fallback, а не предполагать доступность UDP/443.

QUIC packet несёт connection ID, поэтому соединение может пережить смену IP-адреса клиента после валидации нового пути. Это полезно при переходе Wi‑Fi ↔ mobile, но изменяет привязку состояния в load balancer: маршрутизация должна быть согласована с CID или использовать подходящий proxy. UDP-пакеты могут быть отброшены firewall/NAT; корректный клиент имеет HTTP/2/TCP fallback.

## Углубление для E5/Senior

В TCP один loss создаёт transport-level HOL blocking: байты с большим offset не выдаются до восстановления пропуска. QUIC retransmit-ит данные нужного stream, а независимый stream может продолжать. Однако два streams всё ещё делят congestion controller и path bandwidth: QUIC не обещает нулевую задержку и не лечит перегруженный сервер.

0-RTT уменьшает latency при возобновлении сессии, но early data может быть replayed. Разрешайте в 0-RTT только safe/idempotent операции без одноразовых эффектов, либо отвергайте early data. Для rollout измеряйте UDP reachability, handshake time, loss, retransmissions, CPU, path validation и долю fallback. Из-за encryption transport headers пассивная сеть видит меньше, поэтому нужна endpoint-телеметрия и совместимые инструменты.

## Ключевые понятия

- **QUIC connection ID (CID)** — идентификатор соединения, не равный 4-tuple адресов и портов.
- **Connection migration** — продолжение QUIC connection на новом network path после проверки достижимости.
- **0-RTT** — early data при resumption; быстрее, но потенциально воспроизводима атакующим.
- **Stream-level HOL avoidance** — потеря блокирует свой stream, но не delivery данных других streams.
- **Path MTU / amplification limit** — ограничения отправки до валидации пути и размером пакета.

## Типовые вопросы

1. **Почему QUIC использует UDP?**
   - UDP даёт минимальный datagram substrate; QUIC реализует нужные transport-свойства в user space и не наследует TCP ordering между streams.
2. **Гарантирует ли QUIC отсутствие HOL blocking?**
   - Он избегает transport HOL между streams, но внутри одного stream порядок сохраняется; общий congestion и server queue остаются.
3. **Безопасно ли послать `POST` в 0-RTT?**
   - По умолчанию нет: early data может быть replayed. Нужна доказанная идемпотентность и защита дедупликацией, иначе ждут 1-RTT.
4. **Что даёт connection migration?**
   - Клиент может сменить сеть без полного нового handshake, если peer подтвердит новый путь; это не отменяет политики security и routing.
5. **Почему HTTP/3 может быть медленнее?**
   - UDP блокируется, CPU QUIC выше, путь имеет плохую MTU/потери или приложение ограничено backend; обязателен fallback и измерение.
6. **Как балансировать QUIC?**
   - Load balancer должен устойчиво направлять пакеты connection к одному owner либо проксировать их; простая привязка к source IP ломается при migration.

## Практика

- [ ] Поднимите HTTP/3 endpoint с HTTP/2 fallback; критерий: `curl --http3-only` успешен, а при запрете UDP клиент получает рабочий HTTP/2 путь.
- [ ] Проверьте mutating endpoint при session resumption; критерий: early data для него отклонена либо доказана дедупликация replay.
- [ ] Сравните p95/p99 и CPU HTTP/2/HTTP/3 при loss; критерий: отчёт содержит loss rate, UDP reachability, handshake и объяснение результата.

## Частые ошибки и ловушки

- Называть UDP ненадёжным аргументом против HTTP/3: надёжность обеспечивает QUIC, не UDP.
- Разрешать 0-RTT для платежей, создания ресурсов или одноразовых токенов.
- Терять соединение при смене сети из-за CID-независимого routing.
- Считать успешный лабораторный тест доказательством доступности UDP в корпоративных сетях.

## Связанные темы

[[course/01-foundations/04-http-web|HTTP и Web]] · [[course/01-foundations/04-http-web/03-http-2-streams-multiplexing|HTTP/2: streams]] · [[course/01-foundations/04-http-web/01-http-request-response|HTTP: запрос и ответ]] · [[course/09-linux-networking|Linux и сети]] · [[course/11-security|Безопасность]]

## Источники

- RFC 9000, _QUIC: A UDP-Based Multiplexed and Secure Transport_.
- RFC 9001, _Using TLS to Secure QUIC_; RFC 9002, _QUIC Loss Detection and Congestion Control_.
- RFC 9114, _HTTP/3_.
- IETF QUIC Working Group: implementation and deployment guidance.
