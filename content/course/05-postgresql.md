---
title: SQL и PostgreSQL
description: SQL, транзакции и эксплуатация PostgreSQL — обязательная зона для backend E4.
tags:
  - go
  - interview
  - 05-postgresql
status: in-progress
difficulty: e4
draft: false
---

# SQL и PostgreSQL

SQL, транзакции и эксплуатация PostgreSQL — обязательная зона для backend E4.

## Результат модуля

После модуля вы можете объяснить ключевые понятия, выбрать подход под условия задачи и показать это на коде, запросе или архитектурной схеме.

## Темы

- SELECT, JOIN, aggregates, CTE, window functions, NULL logic, parameterized queries.
- Schema design: constraints, normalization/denormalization, UUID/bigint/jsonb/timestamptz.
- ACID, MVCC, isolation levels, row/table/advisory locks, deadlocks и SELECT FOR UPDATE SKIP LOCKED.
- B-tree, GIN/GiST/BRIN, composite/partial/covering/expression indexes.
- EXPLAIN ANALYZE: scans, joins, selectivity, sort, work_mem, N+1.
- WAL, vacuum/autovacuum, bloat, pool, replicas, backups/PITR, partitions.
- database/sql and pgx: connection pool, context, rows close, transactions and batch operations.

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

1. **Почему индекс может не использоваться?**
   - Подготовьте ответ с примером из production или практики.
1. **Чем Read Committed отличается от Repeatable Read в PostgreSQL?**
   - Подготовьте ответ с примером из production или практики.
1. **Как применить миграцию на большой таблице без длительной блокировки?**
   - Подготовьте ответ с примером из production или практики.

## Практика

- [ ] Создайте схему заказов, напишите 10 запросов с окнами/CTE и оптимизируйте намеренно медленный запрос через EXPLAIN ANALYZE.
- [ ] Сформулируйте три частые ошибки по модулю и признаки их проявления.
- [ ] Добавьте в личные карточки определения и решения, которые не удалось воспроизвести без подсказки.

## Связанные темы

[[index|Главная]] · [[course/02-go|Go]] · [[course/05-postgresql|PostgreSQL]] · [[course/08-system-design|System Design]] · [[course/15-interview-practice|Интервью-практика]]

## Источники

- Официальная документация используемого языка, БД или платформы.
- Production-документация команды и проверенные технические разборы.
- Конкретные ссылки добавляйте при наполнении темы, вместе с датой проверки актуальности.
