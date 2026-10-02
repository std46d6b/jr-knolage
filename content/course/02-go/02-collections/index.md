---
title: "Коллекции и работа с данными"
description: "Slices, maps, строки, кодирование форматов и время в Go для интервью и production-кода."
tags:
  - go
  - collections
  - data
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Коллекции и работа с данными

Раздел покрывает данные, которые чаще всего пересекают API и границы владения в Go: backing arrays slices, map, UTF-8, сериализацию и время. Каждая тема самостоятельна и содержит код, вопросы и проверяемую практику.

## Результат раздела

После изучения раздела можно обосновать выбор структуры, избежать aliasing и data race, корректно обработать текст и внешний формат, а также не смешать duration, timezone и момент времени.

## Темы

1. [[course/02-go/02-collections/01-slice-internals-append|Slice: len, cap, append и реаллокация]]
2. [[course/02-go/02-collections/02-slice-aliasing-copy-retention|Slice: aliasing, copy и удержание памяти]]
3. [[course/02-go/02-collections/03-maps-internals-concurrency|Map: устройство, ограничения и конкурентный доступ]]
4. [[course/02-go/02-collections/04-strings-utf8-bytes-runes|Strings: UTF-8, bytes и runes]]
5. [[course/02-go/02-collections/05-builders-buffers|bytes.Buffer и strings.Builder]]
6. [[course/02-go/02-collections/06-json-encoding|JSON: encoding/json, теги и custom marshal]]
7. [[course/02-go/02-collections/07-data-formats|XML, CSV и base64]]
8. [[course/02-go/02-collections/08-time|Time: time.Time, duration и timezone]]

## Минимум для E4

- [ ] Объяснять ownership backing array и назначение `copy`/full slice expression.
- [ ] Выбирать безопасную синхронизацию map и запускать проверку `-race`.
- [ ] Отличать byte, rune и пользовательский grapheme cluster.
- [ ] Обрабатывать ошибки кодеков и хранить моменты времени в явной зоне.

## Углубление для E5/Senior

Старший инженер рассматривает данные как контракт: фиксирует владение и mutability, вводит лимиты внешнего ввода, отделяет DTO от внутренней модели и подтверждает performance-решения профилем и benchmark. Он также документирует семантику отсутствующего/пустого значения и времени, а не оставляет её случайным свойством библиотеки.

## Ключевые понятия

Backing array, aliasing, capacity, comparable key, data race, UTF-8, code point, streaming codec, DTO, UTC, monotonic clock.

## Типовые вопросы

1. **Почему append иногда меняет другой slice?**
   - Пока оба slice разделяют backing array и у первого есть свободная capacity, запись может попасть в общий массив.
2. **Можно ли безопасно читать map и писать в него из разных goroutine?**
   - Нет; синхронизируйте все обращения или используйте подходящую специализированную структуру.
3. **Почему `len(string)` не равно количеству символов?**
   - Это длина в байтах UTF-8, а не в rune или grapheme clusters.
4. **Когда `omitempty` меняет контракт API?**
   - Когда клиент должен отличать отсутствующее поле от нулевого/пустого значения.
5. **Почему timestamp лучше хранить в UTC?**
   - UTC однозначно представляет момент; display zone применяют отдельно.

## Практика

- [ ] Соберите мини-импорт: CSV → validated DTO → JSON. **Готово:** вход ограничен, ошибки возвращаются с контекстом, тесты покрывают Unicode и неверную запись.
- [ ] Реализуйте cache с map и mutex. **Готово:** `go test -race` проходит, наружу не возвращается mutable внутренний map.

## Частые ошибки и ловушки

- Считать slice или struct автоматически независимой копией.
- Полагаться на порядок обхода map.
- Использовать base64 как механизм защиты и локальное серверное время как формат хранения.

## Связанные темы

[[course/02-go|Go: язык, runtime и стандартная библиотека]] · [[course/01-foundations/02-performance|Производительность и память]] · [[course/01-foundations/04-http-web|HTTP и Web]]

## Источники

- [The Go Programming Language Specification](https://go.dev/ref/spec)
- [Go standard library](https://pkg.go.dev/std)
- [Effective Go](https://go.dev/doc/effective_go)
