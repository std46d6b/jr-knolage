---
title: Распределённые системы и интеграции
description: "Надёжные взаимодействия сервисов: timeouts, сообщения, доставка и согласованность данных."
tags:
  - go
  - interview
  - 07-distributed-systems
status: in-progress
difficulty: e4
draft: false
---

# Распределённые системы и интеграции

Надёжные взаимодействия сервисов: timeouts, сообщения, доставка и согласованность данных.

## Результат модуля

После модуля вы можете объяснить ключевые понятия, выбрать подход под условия задачи и показать это на коде, запросе или архитектурной схеме.

## Темы

- Partial failures, partitions, clock skew, latency budget, consistency/availability/durability.
- Timeouts, retries, exponential backoff+jitter, retry budget, circuit breaker, bulkhead, load shedding.
- Idempotency и deduplication на HTTP и consumer side.
- Kafka: topic, partition, offset, consumer group, ordering, rebalancing, retention/compaction.
- RabbitMQ: exchanges, queues, routing, ack/nack, retry queue и DLQ.
- Saga, outbox, inbox, CDC, CQRS/event sourcing: условия применимости и цена.
- gRPC/Protobuf compatibility, deadlines, streaming, contract tests.

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

1. **Что означает at-least-once и как обработать дубликат?**
   - Подготовьте ответ с примером из production или практики.
1. **Почему exactly-once не является end-to-end гарантией?**
   - Подготовьте ответ с примером из production или практики.
1. **Как обеспечить публикацию события и запись в БД без 2PC?**
   - Подготовьте ответ с примером из production или практики.

## Практика

- [ ] Сделайте design exercise: заказ → оплата → резерв; опишите saga, outbox, retry и компенсации.
- [ ] Сформулируйте три частые ошибки по модулю и признаки их проявления.
- [ ] Добавьте в личные карточки определения и решения, которые не удалось воспроизвести без подсказки.

## Связанные темы

[[index|Главная]] · [[course/02-go|Go]] · [[course/05-postgresql|PostgreSQL]] · [[course/08-system-design|System Design]] · [[course/15-interview-practice|Интервью-практика]]

## Источники

- Официальная документация используемого языка, БД или платформы.
- Production-документация команды и проверенные технические разборы.
- Конкретные ссылки добавляйте при наполнении темы, вместе с датой проверки актуальности.
