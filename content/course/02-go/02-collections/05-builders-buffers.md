---
title: "bytes.Buffer и strings.Builder"
description: "Выбор инструмента для построения текста и байтовых потоков без лишних копий."
tags:
  - go
  - strings
  - io
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# bytes.Buffer и strings.Builder

## Зачем это на интервью

Конкатенация строк в цикле может создавать много промежуточных строк. Правильный builder уменьшает аллокации, а `bytes.Buffer` нужен, когда API работает с байтами или `io.Reader`/`io.Writer`.

## Минимум для E4

- [ ] Выбирать `strings.Builder` для построения строки и `bytes.Buffer` для байтов/I/O.
- [ ] Вызывать `Grow` только как оптимизацию после измерения или при известном размере.
- [ ] Не копировать ненулевой `Builder` и `Buffer`.

## Углубление для E5/Senior

`strings.Builder` имеет API записи строк/байтов и `String`; он не реализует чтение. `bytes.Buffer` — растущий буфер байт, реализует `Reader` и `Writer`, пригоден для кодеков и потокового API. После `String`/`Bytes` не сохраняйте результат, если буфер будет переиспользован, без понимания aliasing и документации метода. `Reset` сохраняет выделенную capacity: это полезно в ограниченном lifecycle, но удерживает большой пик памяти.

## Ключевые понятия

```go
func greeting(names []string) string {
	var b strings.Builder
	b.Grow(len("hello: ") + len(names)*8)
	b.WriteString("hello: ")
	for i, name := range names {
		if i > 0 { b.WriteString(", ") }
		b.WriteString(name)
	}
	return b.String()
}

var buf bytes.Buffer
if err := json.NewEncoder(&buf).Encode(map[string]int{"ok": 1}); err != nil { panic(err) }
body := buf.Bytes() // валиден до следующей изменяющей операции с buf
```

Не используйте `fmt.Sprintf` в каждом витке простого цикла лишь для склейки: это часто дороже и менее явно. Внешний API важнее микрооптимизации: возвращайте `string`/`[]byte`, а не mutable buffer.

## Типовые вопросы

1. **Когда нужен `strings.Builder`?**
   - При последовательной сборке строки, особенно в цикле.
2. **Чем Buffer отличается от Builder?**
   - Buffer работает с `[]byte` и I/O; Builder ориентирован на string.
3. **Можно ли копировать builder после записи?**
   - Нет; документация запрещает копировать ненулевое значение.
4. **Что делает `Grow`?**
   - Резервирует минимум места; не меняет длину и может panic при слишком большом размере.
5. **Освобождает ли `Reset` память?**
   - Он сбрасывает содержимое, но capacity обычно остаётся для повторного использования.

## Практика

- [ ] Перепишите конкатенацию в цикле через `strings.Builder`. **Готово:** тест идентичен, benchmark с `-benchmem` сравнивает обе версии.
- [ ] Закодируйте JSON в `bytes.Buffer`. **Готово:** ошибка Encoder обработана, а тест декодирует результат обратно.

## Частые ошибки и ловушки

- Копировать buffer/builder после первого использования.
- Удерживать `Bytes()` и затем переиспользовать buffer.
- Пулить большие буферы без лимита и удерживать peak memory.

## Связанные темы

[[course/02-go/02-collections|Коллекции и работа с данными]] · [[course/02-go/02-collections/06-json-encoding|JSON]]

## Источники

- [package strings: Builder](https://pkg.go.dev/strings#Builder)
- [package bytes: Buffer](https://pkg.go.dev/bytes#Buffer)
- [Go blog: Strings, bytes, runes and characters in Go](https://go.dev/blog/strings)
