---
title: Linux, сети и cloud
description: Операционная база для диагностики production-сервисов.
tags:
  - go
  - interview
  - 09-linux-networking
status: in-progress
difficulty: e4
draft: false
---

# Linux, сети и cloud

Операционная база для диагностики production-сервисов.

## Результат модуля

После модуля вы можете объяснить ключевые понятия, выбрать подход под условия задачи и показать это на коде, запросе или архитектурной схеме.

## Темы

- Filesystem, permissions, users, processes, signals, systemd и environment variables.
- RSS/virtual memory, OOM killer, load average, ulimit и file descriptors.
- TCP handshake, retransmission, flow/congestion control; UDP и QUIC.
- IP/CIDR, NAT, DNS/TTL, TLS, reverse proxy, L4/L7 balancing, ephemeral ports.
- Инструменты: ps/top, lsof, strace, df/du, curl, dig, ss, tcpdump.
- Cloud: regions/AZ, IAM, autoscaling, managed services, RPO/RTO.

## Минимум для E4

- Знать определения без заученных «магических» формулировок.
- Объяснять ограничения каждого подхода и называть минимум одну альтернативу.
- Приводить практический пример: код, схема, запрос или production-сценарий.
- Учитывать ошибки, наблюдаемость и безопасный rollout там, где это применимо.

## Углубление для E5/Senior

- Оценивать масштаб, стоимость, эксплуатационные риски и совместимость изменений.
- Проектировать постепенную эволюцию решения, а не только целевую схему.
- Защищать решение через требования и измеримые trade-offs.

## Типовые вопросы

1. **Почему сервис получает too many open files?**
   - Подготовьте ответ с примером из production или практики.
1. **Почему DNS change не вступает в силу сразу?**
   - Подготовьте ответ с примером из production или практики.
1. **Как отличить network timeout от application timeout?**
   - Подготовьте ответ с примером из production или практики.

## Практика

- [ ] Разберите сценарий: pod не отвечает. Соберите диагностический чек-лист от DNS до процесса.
- [ ] Сформулируйте три частые ошибки по модулю и признаки их проявления.
- [ ] Добавьте в личные карточки определения и решения, которые не удалось воспроизвести без подсказки.

## Связанные темы

[[index|Главная]] · [[course/02-go|Go]] · [[course/05-postgresql|PostgreSQL]] · [[course/08-system-design|System Design]] · [[course/15-interview-practice|Интервью-практика]]

## Источники

- Официальная документация используемого языка, БД или платформы.
- Production-документация команды и проверенные технические разборы.
- Конкретные ссылки добавляйте при наполнении темы, вместе с датой проверки актуальности.
