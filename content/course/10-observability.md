---
title: Observability, monitoring и incident response
description: Как увидеть состояние сервиса, построить полезные алерты и провести инцидент.
tags:
  - go
  - interview
  - 10-observability
status: in-progress
difficulty: e4
draft: false
---

# Observability, monitoring и incident response

Как увидеть состояние сервиса, построить полезные алерты и провести инцидент.

## Результат модуля

После модуля вы можете объяснить ключевые понятия, выбрать подход под условия задачи и показать это на коде, запросе или архитектурной схеме.

## Темы

- Logs, metrics, traces; golden signals, RED и USE.
- Structured logging, correlation/trace IDs, PII redaction, retention и cardinality.
- Prometheus counters/gauges/histograms, labels, PromQL, recording and alert rules.
- OpenTelemetry context propagation, spans, sampling, Tempo/Jaeger.
- SLI/SLO/SLA, error budget, actionable alerts, runbook, postmortem.
- Диагностика: latency, goroutine leak, DB pool, slow query, consumer lag, cache hit-rate.

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

1. **Почему summary и histogram отвечают на разные вопросы?**
   - Подготовьте ответ с примером из production или практики.
1. **Почему high-cardinality label опасен?**
   - Подготовьте ответ с примером из production или практики.
1. **Что должен содержать alert, чтобы его можно было обработать ночью?**
   - Подготовьте ответ с примером из production или практики.

## Практика

- [ ] Определите SLO API и набор метрик/алертов. Разберите падение p99 с помощью метрик, trace и profile.
- [ ] Сформулируйте три частые ошибки по модулю и признаки их проявления.
- [ ] Добавьте в личные карточки определения и решения, которые не удалось воспроизвести без подсказки.

## Связанные темы

[[index|Главная]] · [[course/02-go|Go]] · [[course/05-postgresql|PostgreSQL]] · [[course/08-system-design|System Design]] · [[course/15-interview-practice|Интервью-практика]]

## Источники

- Официальная документация используемого языка, БД или платформы.
- Production-документация команды и проверенные технические разборы.
- Конкретные ссылки добавляйте при наполнении темы, вместе с датой проверки актуальности.
