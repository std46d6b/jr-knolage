---
title: "Go: язык, runtime и стандартная библиотека"
description: "Ключевой модуль: идиоматичный Go, конкурентность, память, контексты и tooling."
tags:
  - go
  - interview
  - 02-go
status: complete
difficulty: e4
draft: false
---

# Go: язык, runtime и стандартная библиотека

Ключевой модуль: идиоматичный Go, конкурентность, память, контексты и tooling.

## Результат модуля

После модуля вы можете объяснить ключевые понятия, выбрать подход под условия задачи и показать это на коде, запросе или архитектурной схеме.

## Темы

- [[course/02-go/01-language|Основы языка]]: packages, visibility, types, values, methods, interfaces, generics, `defer`, `panic` и errors.
- [[course/02-go/02-collections|Коллекции и работа с данными]]: slices, maps, strings, JSON, форматы данных и time.
- [[course/02-go/03-concurrency|Concurrency]]: goroutines, channels, `select`, `sync`, atomic, race conditions, worker pools и graceful shutdown.
- [[course/02-go/04-context-lifecycle|Context и жизненный цикл]]: cancellation, deadlines, budgets, values, утечки ресурсов и остановка сервиса.
- [[course/02-go/05-runtime-memory|Runtime и memory management]]: scheduler, stacks, escape analysis, heap, GC, `unsafe` и cgo.
- [[course/02-go/06-stdlib-practical|Стандартная библиотека и практический Go]]: HTTP, SQL, I/O, filesystem, encoding, crypto, `slog`, configuration и testing.
- [[course/02-go/07-tools|Инструменты Go]]: modules, formatters, linters, tests, benchmarks, pprof, trace, escape analysis и Delve.
- [[course/02-go/08-interview-code|Go-код на интервью]]: чтение, рефакторинг, ошибки, observability, API пакета, mockability и code review.

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
