---
title: "Go: язык, runtime и стандартная библиотека"
description: "Ключевой модуль: идиоматичный Go, конкурентность, память, контексты и tooling."
tags:
  - go
  - interview
  - 02-go
status: in-progress
difficulty: e4
draft: false
---

# Go: язык, runtime и стандартная библиотека

Ключевой модуль: идиоматичный Go, конкурентность, память, контексты и tooling.

## Результат модуля

После модуля вы можете объяснить ключевые понятия, выбрать подход под условия задачи и показать это на коде, запросе или архитектурной схеме.

## Темы

- Types, zero values, slices, maps, strings, structs, methods, interfaces, errors и generics.
- Slice aliasing, append/reallocation, map concurrency, UTF-8 и bytes/runes.
- Goroutines, channels, select, mutex/RWMutex, WaitGroup, atomic, race/deadlock/starvation.
- context cancellation/deadline, graceful shutdown, утечки goroutines.
- G-M-P scheduler, escape analysis, GC, pprof, trace, race detector.
- net/http, http.Client/Transport, io, database/sql, slog, time и encoding/json.

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

1. **Чем nil interface отличается от interface с nil pointer?**
   - Подготовьте ответ с примером из production или практики.
1. **Кто должен закрывать канал и почему?**
   - Подготовьте ответ с примером из production или практики.
1. **Как найти memory leak или lock contention в Go-сервисе?**
   - Подготовьте ответ с примером из production или практики.

## Практика

- [ ] Напишите worker pool с отменой через context, ограничением параллелизма, сбором ошибок и тестом под `-race`.
- [ ] Сформулируйте три частые ошибки по модулю и признаки их проявления.
- [ ] Добавьте в личные карточки определения и решения, которые не удалось воспроизвести без подсказки.

## Связанные темы

[[index|Главная]] · [[course/02-go|Go]] · [[course/05-postgresql|PostgreSQL]] · [[course/08-system-design|System Design]] · [[course/15-interview-practice|Интервью-практика]]

## Источники

- Официальная документация используемого языка, БД или платформы.
- Production-документация команды и проверенные технические разборы.
- Конкретные ссылки добавляйте при наполнении темы, вместе с датой проверки актуальности.
