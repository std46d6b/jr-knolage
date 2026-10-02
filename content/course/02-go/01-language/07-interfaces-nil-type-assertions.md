---
title: Интерфейсы, nil и type assertion в Go
description: Неявная реализация интерфейсов, двухсловное представление interface, typed nil и безопасное сужение типа.
tags:
  - go
  - language
  - interfaces
  - nil
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
aliases:
  - Nil interface
  - Проверка типа в Go
draft: false
---

# Интерфейсы, nil и type assertion в Go

## Зачем это на интервью

Интерфейсы в Go задают поведение структурно: тип реализует их без ключевого слова `implements`. Это делает API небольшими и гибкими, но требует точно понимать dynamic type, dynamic value и `nil`. Классическая production-ошибка — вернуть `(*MyError)(nil)` как `error`, получить non-nil interface и выполнить ненужную ветку ошибки.

## Минимум для E4

- [ ] Объяснить, что interface value содержит dynamic type и dynamic value.
- [ ] Отличать nil interface от interface, содержащего typed-nil pointer.
- [ ] Объявлять узкий интерфейс у потребителя, а не экспортировать «универсальный» интерфейс поставщика.
- [ ] Использовать comma-ok assertion или type switch для данных из открытой границы.

Nil interface не содержит ни dynamic type, ни dynamic value. После присваивания nil-указателя интерфейсу dynamic type уже известен, поэтому интерфейс не равен `nil`.

```go
package main

import "fmt"

type FileStore struct{}
func (*FileStore) String() string { return "file store" }

type Worker interface {
    Work() string
}

type job struct{}

func (*job) Work() string { return "done" }

func main() {
    var p *job
    var w Worker = p

    fmt.Println(p == nil) // true
    fmt.Println(w == nil) // false: dynamic type is *job
}
```

Присваивание интерфейсу проверяет method set на этапе компиляции. Хорошая защита для exported реализации — явная проверка:

```go
package main

import "io"

type FileStore struct{}

func (*FileStore) Read(p []byte) (int, error) { return 0, io.EOF }

var _ io.Reader = (*FileStore)(nil)

func main() {}
```

## Углубление для E5/Senior

Интерфейсная граница должна выражать потребность вызывающего кода. Интерфейс из одного-двух методов легче реализовать, документировать и эволюционировать. Принимайте интерфейсы, возвращайте concrete types, если API не обязан скрывать реализацию: это сохраняет методы и снижает необходимость assertions.

Не все значения можно безопасно сравнивать через `==`. Два interface values сравниваются только если их dynamic values comparable; интерфейс с `[]byte`, map или func при сравнении может вызвать panic. Для данных use `slices.Equal`, `maps.Equal`, `reflect.DeepEqual` с пониманием его семантики либо доменное сравнение.

Type assertion `v.(T)` паникует, если dynamic type не соответствует `T`. Двухзначная форма `value, ok := v.(T)` не паникует. В type switch case с `nil` срабатывает только для nil interface; typed nil попадёт в case его pointer-типа. После проверки pointer всё ещё может быть nil — это нужно обработать до вызова метода, если метод не поддерживает nil receiver.

```go
package main

import "fmt"

func describe(v any) string {
    switch x := v.(type) {
    case nil:
        return "nil interface"
    case string:
        return "string: " + x
    case *FileStore:
        if x == nil {
            return "typed-nil *FileStore"
        }
        return x.String()
    case fmt.Stringer:
        // x — non-nil interface even when it contains a typed-nil pointer.
        return x.String()
    default:
        return fmt.Sprintf("unknown %T", x)
    }
}

func main() {
    fmt.Println(describe("go"))
}
```

`any` — alias для `interface{}`; он не устраняет динамическую типизацию. Если набор типов известен на compile time, generics или обычный concrete API обычно лучше, чем `any` с assertions. Для ошибок используйте `errors.As`, а не assertion: wrapping меняет внешний dynamic type, но не логическую классификацию ошибки.

## Ключевые понятия

| Понятие                 | Смысл                                          | Последствие                                  |
| ----------------------- | ---------------------------------------------- | -------------------------------------------- |
| Interface value         | Пара dynamic type + dynamic value              | `nil` только когда отсутствуют оба           |
| Typed nil               | Nil pointer/map/slice и известный dynamic type | Interface с ним обычно `!= nil`              |
| Implicit implementation | Совпадение method set без декларации           | Контракт можно определить возле потребителя  |
| Type assertion          | Проверка/извлечение dynamic type               | Однозначная форма может panic                |
| Type switch             | Ветвление по dynamic type                      | Удобен для закрытого набора допустимых типов |

Пустой интерфейс принимает любое значение, но не предоставляет полезных операций без assertion. Не используйте его вместо предметной модели или чтобы обойти циклические зависимости: обычно это переносит ошибку из компиляции в runtime.

## Типовые вопросы

1. **Почему `return (*MyError)(nil)` как `error` опасен?**
   - Интерфейс содержит тип `*MyError`, поэтому не равен `nil`; возвращайте literal `nil` при отсутствии ошибки.
2. **Чем `var r io.Reader` отличается от `var r io.Reader = (*bytes.Buffer)(nil)`?**
   - Первый — nil interface; второй содержит dynamic type `*bytes.Buffer` и typed-nil dynamic value.
3. **Когда применять `x.(T)` без `ok`?**
   - Только когда нарушение инварианта — программная ошибка и panic действительно допустима; на входе API используйте comma-ok.
4. **Где объявлять интерфейс?**
   - Обычно рядом с потребителем, с минимальным набором нужных ему методов.
5. **Почему `any` не является generic?**
   - `any` хранит runtime dynamic type; generic type parameter проверяется и специализируется компилятором в рамках constraint.
6. **Почему не стоит возвращать интерфейс всегда?**
   - Клиент теряет дополнительные методы concrete type и вынужден делать assertions; возвращайте interface только как намеренную абстракцию.

## Практика

- [ ] Воспроизведите typed-nil ошибку в функции `func Open() error` и исправьте контракт.
  - **Критерии готовности:** тест различает `nil` и typed nil; успешная ветка возвращает literal `nil`; `go vet` и `go test` проходят.
- [ ] Спроектируйте порт `Notifier` для use case с методами, нужными только use case.
  - **Критерии готовности:** интерфейс содержит не более двух методов; fake реализует его без SDK; compile-time assertion подтверждает production adapter.
- [ ] Распарсите `[]any` с `string`, `float64` и неподдерживаемым значением.
  - **Критерии готовности:** нет panic на внешнем вводе; неизвестный тип даёт диагностическую ошибку с `%T`; typed nil обработан отдельно.

## Частые ошибки и ловушки

- Проверять лишь `err != nil`, когда функция формирует typed-nil error.
- Вызывать метод у typed-nil pointer внутри interface без контракта на nil receiver.
- Делать assertion на конкретную ошибку вместо `errors.As`.
- Добавлять широкий интерфейс из десятков методов ради «переиспользования».
- Сравнивать interface values, внутри которых могут лежать slice, map или func.

## Связанные темы

- [[course/02-go/01-language/06-methods-receivers|Методы и receivers]]
- [[course/02-go/01-language/08-generics|Generics]]
- [[course/02-go/01-language/10-errors|Ошибки]]
- [[course/01-foundations/03-design-principles/06-dependency-inversion-injection|Инверсия зависимостей и DI]]

## Источники

- [Go specification: Interface types](https://go.dev/ref/spec#Interface_types).
- [Go specification: Type assertions](https://go.dev/ref/spec#Type_assertions).
- [Go FAQ: Why is my nil error value not equal to nil?](https://go.dev/doc/faq#nil_error).
- [Go Code Review Comments: Interfaces](https://go.dev/wiki/CodeReviewComments#interfaces).
