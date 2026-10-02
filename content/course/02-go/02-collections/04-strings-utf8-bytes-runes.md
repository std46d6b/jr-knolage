---
title: "Strings: UTF-8, bytes и runes"
description: "Неизменяемые строки Go, байтовая индексация и корректная работа с Unicode."
tags:
  - go
  - strings
  - unicode
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Strings: UTF-8, bytes и runes

## Зачем это на интервью

В Go строка — неизменяемая последовательность байтов, обычно UTF-8. Ошибка «символ равен байту» ломает валидацию, обрезку и отображение пользовательского текста.

## Минимум для E4

- [ ] Различать `len(s)` в байтах и число rune.
- [ ] Обходить Unicode-текст через `range` или `[]rune` при необходимости индексации по code point.
- [ ] Не менять строку по индексу; строить новый результат.

## Углубление для E5/Senior

`rune` — alias `int32` и представляет Unicode code point, но не пользовательский «символ»: один grapheme cluster может состоять из нескольких rune (например, буква с combining mark или emoji ZWJ). `range` декодирует UTF-8 и заменяет некорректную последовательность на `U+FFFD`; если важна байтовая валидность, используйте `utf8.ValidString`. Преобразование `[]rune(s)` выделяет память и не должно быть скрытой оптимизацией.

## Ключевые понятия

```go
s := "Go🙂"
fmt.Println(len(s))                    // байты: 6
fmt.Println(utf8.RuneCountInString(s)) // code points: 3
for byteOffset, r := range s {
	fmt.Printf("%d: %U\n", byteOffset, r)
}

b := []byte(s) // копия байтов; подходит для протокола/UTF-8
r := []rune(s) // декодированные code points
r[0] = 'g'
changed := string(r)
```

`s[i]` возвращает `byte`, не «i-й Unicode-символ». Slice строки `s[a:b]` использует байтовые смещения и должен резать по границе UTF-8, если результат будет текстом.

## Типовые вопросы

1. **Почему `len("é")` может быть не 1?**
   - `len` считает байты UTF-8; один code point занимает переменное число байтов.
2. **Что возвращает `s[i]`?**
   - Один байт типа `uint8`.
3. **Всегда ли `range` даёт количество видимых символов?**
   - Нет, он даёт rune/code point, а grapheme cluster может состоять из нескольких rune.
4. **Можно ли менять строку?**
   - Нет, строки immutable; создайте новую через builder, bytes или runes.
5. **Как проверить корректность UTF-8?**
   - `utf8.ValidString`; не полагайтесь на успешный `range`.

## Практика

- [ ] Напишите функцию, возвращающую первые `n` rune без разрыва UTF-8. **Готово:** тесты включают ASCII, кириллицу, emoji и `n=0`; контракт явно говорит, что grapheme clusters не считаются.
- [ ] Провалидируйте вход в UTF-8. **Готово:** некорректная байтовая последовательность возвращает ошибку до обработки.

## Частые ошибки и ловушки

- Обрезать UI-текст по байтовому индексу.
- Путать `byte`, rune и grapheme cluster.
- Считать строку всегда валидным UTF-8: она может содержать произвольные байты.

## Связанные темы

[[course/02-go/02-collections|Коллекции и работа с данными]] · [[course/02-go/02-collections/05-builders-buffers|Builders и buffers]]

## Источники

- [Go blog: Strings, bytes, runes and characters in Go](https://go.dev/blog/strings)
- [package unicode/utf8](https://pkg.go.dev/unicode/utf8)
- [Go specification: String types](https://go.dev/ref/spec#String_types)
