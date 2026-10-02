---
title: "Основы языка Go"
description: "Последовательный конспект по пакетам, типам, коллекциям, структурам, функциям, интерфейсам, ошибкам, управлению потоком, generics и модулям Go."
tags:
  - go
  - language
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Основы языка Go

Этот раздел формирует модель языка, с которой удобно читать чужой код и отвечать на вопросы интервью: от области имён и представления значений до публичных контрактов пакета. Сначала пройдите страницы по порядку, затем возвращайтесь к связанным темам при разборе кода.

## Результат раздела

После изучения вы умеете предсказывать копирование и aliasing, выбирать value или pointer API, проектировать небольшой пакет, безопасно работать с `map` и строками, объяснять interface satisfaction и не подменять обработку ошибок `panic`.

## Карта тем

1. [[course/02-go/01-language/01-packages-visibility-naming|Пакеты, видимость и именование]] — модуль, import path, экспорт, `internal` и публичная поверхность.
2. [[course/02-go/01-language/02-values-types-constants-iota|Значения, типы, константы и iota]] — zero values, определённые типы, alias, conversions и перечисления.
3. [[course/02-go/01-language/03-arrays-slices-maps-strings|Массивы, срезы, map и строки]] — backing array, capacity, aliasing, UTF-8 и конкурентный доступ.
4. [[course/02-go/01-language/04-structs-embedding-tags|Структуры, embedding и теги]] — композиция, promotion, DTO и метаданные библиотек.
5. [[course/02-go/01-language/05-functions-pointers-value-semantics|Функции, указатели и семантика значений]] — copy semantics, receivers, замыкания и ownership.
6. [[course/02-go/01-language/06-methods-interfaces-composition|Методы, интерфейсы и композиция]] — method sets, неявная реализация и границы зависимостей.
7. [[course/02-go/01-language/07-errors-panics-recover|Ошибки, panic и recover]] — error contracts, wrapping, sentinel/typed errors и аварийные пути.
8. [[course/02-go/01-language/08-control-flow-defer|Управление потоком и defer]] — `if`, `for`, `switch`, `range`, scope и гарантированное освобождение ресурсов.
9. [[course/02-go/01-language/09-generics-type-parameters|Generics и параметры типов]] — constraints, type sets, inference и границы обобщений.
10. [[course/02-go/01-language/10-modules-imports-tooling|Модули, импорты и tooling]] — `go.mod`, версии, зависимости и базовые команды Go.

## Рекомендуемый порядок

1. Страницы 1–5 дают модель областей имён, значений и памяти.
2. Страницы 6–8 соединяют модель с API, обработкой сбоев и обычным кодовым потоком.
3. Страницы 9–10 помогают выбирать уровень абстракции и поддерживать воспроизводимую сборку.

Не переходите к конкурентности, пока не можете без запуска объяснить различие `[]T`, `*[]T`, `map[K]V`, `T` и `*T`: эти представления определяют ownership и риск data race.

## Проверка готовности

- [ ] Я могу назвать import path, package name и экспортируемость любого символа в небольшом примере.
- [ ] Я объясняю, какие данные разделяют два среза после присваивания и когда `append` разрывает связь.
- [ ] Я выбираю pointer receiver по семантике идентичности или мутации, а не по привычке.
- [ ] Я умею написать небольшой пакет с документированным API, тестом внешнего потребителя и явной обработкой ошибок.
- [ ] Я могу пройти `go test ./...`, `go vet ./...` и `go test -race ./...` для учебного модуля и объяснить назначение каждой команды.

## Связанные темы

[[course/02-go|Go: язык, runtime и стандартная библиотека]] · [[course/02-go/02-concurrency|Конкурентность Go]] · [[course/02-go/03-runtime-memory|Runtime и память Go]] · [[course/02-go/04-standard-library|Стандартная библиотека Go]]

## Источники

- [The Go Programming Language Specification](https://go.dev/ref/spec).
- [Effective Go](https://go.dev/doc/effective_go).
- [Go Blog](https://go.dev/blog/).
- [Go Documentation](https://go.dev/doc/).
