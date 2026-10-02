---
title: NoSQL, кэш и поиск
description: Выбор хранилища под access pattern, Redis и полнотекстовый поиск.
tags:
  - go
  - interview
  - 06-nosql-cache-search
status: in-progress
difficulty: e4
draft: false
---

# NoSQL, кэш и поиск

Выбор хранилища под access pattern, Redis и полнотекстовый поиск.

## Результат модуля

После модуля вы можете объяснить ключевые понятия, выбрать подход под условия задачи и показать это на коде, запросе или архитектурной схеме.

## Темы

- Key-value, document, wide-column, graph: data/query model и CAP/PACELC.
- Redis types, TTL, eviction, persistence, replication, Cluster/Sentinel на обзорном уровне.
- Cache-aside/read-through/write-through; invalidation, stampede, penetration и hot keys.
- Distributed locks и fencing tokens: почему lock не даёт абсолютной безопасности.
- MongoDB, Cassandra/Scylla, DynamoDB: partitioning и consistency — основы.
- Elasticsearch/OpenSearch: inverted index, shards, mappings, relevance, search_after.

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

1. **Как защитить кэш от stampede?**
   - Подготовьте ответ с примером из production или практики.
1. **Как выбрать partition key?**
   - Подготовьте ответ с примером из production или практики.
1. **Почему search index обычно eventual consistent?**
   - Подготовьте ответ с примером из production или практики.

## Практика

- [ ] Спроектируйте cache-aside для профиля пользователя с TTL, invalidation и защитой от stampede.
- [ ] Сформулируйте три частые ошибки по модулю и признаки их проявления.
- [ ] Добавьте в личные карточки определения и решения, которые не удалось воспроизвести без подсказки.

## Связанные темы

[[index|Главная]] · [[course/02-go|Go]] · [[course/05-postgresql|PostgreSQL]] · [[course/08-system-design|System Design]] · [[course/15-interview-practice|Интервью-практика]]

## Источники

- Официальная документация используемого языка, БД или платформы.
- Production-документация команды и проверенные технические разборы.
- Конкретные ссылки добавляйте при наполнении темы, вместе с датой проверки актуальности.
