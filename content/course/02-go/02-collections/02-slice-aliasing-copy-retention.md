---
title: "Slice: aliasing, copy и удержание памяти"
description: "Общие backing arrays, full slice expression, копирование срезов и структур."
tags:
  - go
  - collections
  - memory
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Slice: aliasing, copy и удержание памяти

## Зачем это на интервью

Подсрез обычно разделяет массив с исходным значением. Это источник порчи данных, неожиданных мутаций и удержания больших буферов в памяти — частые production-баги.

## Минимум для E4

- [ ] Понимать, что присваивание и `s[a:b]` обычно создают alias, а не копию.
- [ ] Копировать элементы через `copy` или `append([]T(nil), s...)`.
- [ ] Ограничивать capacity `s[a:b:b]`, когда вызывающий код не должен дописывать в исходный массив.

## Углубление для E5/Senior

Full slice expression ограничивает capacity нового заголовка, но не копирует данные. Он полезен для API-границы: следующий `append` обязан выделить новый массив. Для структур копирование поверхностное: slice, map, pointer, interface и function-поля всё ещё могут вести к общим изменяемым данным; «deep copy» — часть контракта типа, а не встроенная операция.

## Ключевые понятия

```go
buf := []byte("abcdef")
view := buf[1:3]      // "bc", cap(view) больше len(view)
view[0] = 'X'         // buf теперь "aXcdef"
isolated := buf[1:3:3] // cap=2: append не затронет buf
isolated = append(isolated, '!')

clone := append([]byte(nil), view...) // независимые элементы
// Эквивалентно: clone := make([]byte, len(view)); copy(clone, view)
```

Маленький subslice большого входного буфера сохраняет ссылку на весь backing array. Если он живёт долго, копируйте нужный фрагмент. `copy(dst, src)` копирует `min(len(dst), len(src))` и возвращает число элементов.

```go
type Request struct { Labels []string }
a := Request{Labels: []string{"new"}}
b := a              // копия struct, но Labels разделены
b.Labels[0] = "old" // меняет a.Labels[0]
b.Labels = slices.Clone(a.Labels) // Go 1.21+: независимый slice
```

## Типовые вопросы

1. **Копирует ли `b := a` элементы slice?**
   - Нет, копируется заголовок; оба значения обычно смотрят на один массив.
2. **Что делает `s[:0]`?**
   - Создаёт нулевой slice с прежней capacity; данные и память остаются удержанными.
3. **Зачем `s[:len(s):len(s)]`?**
   - Чтобы запретить последующему `append` писать за конец `s` в общий массив.
4. **Когда full slice expression недостаточен?**
   - Когда нужна независимость уже существующих элементов или освобождение большого backing array: нужна копия.
5. **Является ли копия struct глубокой?**
   - Только для полей с value semantics; ссылочные поля надо копировать по правилам домена.

## Практика

- [ ] Напишите `Prefix(data []byte, n int) []byte`, возвращающий независимую копию первых `n` байт. **Готово:** изменение результата не меняет `data`, а тест покрывает `n=0`, `n=len(data)` и неверный `n`.
- [ ] Найдите alias в структуре с `map` и `[]string`. **Готово:** тест демонстрирует баг до копирования и его отсутствие после выбранной deep copy.

## Частые ошибки и ловушки

- Возвращать subslice временного гигабайтного буфера из кэша.
- Считать `slices.Clone` deep copy элементов.
- Передавать mutable slice между владельцами без документирования владения.

## Связанные темы

[[course/02-go/02-collections|Коллекции и работа с данными]] · [[course/02-go/02-collections/01-slice-internals-append|Slice: append]]

## Источники

- [Go specification: Slice expressions](https://go.dev/ref/spec#Slice_expressions)
- [Go specification: Appending to and copying slices](https://go.dev/ref/spec#Appending_and_copying_slices)
- [package slices](https://pkg.go.dev/slices)
