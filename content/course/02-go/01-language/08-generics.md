---
title: Generics в Go
description: Параметры типов, constraints, вывод типов и границы применения generics в понятном публичном API.
tags:
  - go
  - language
  - generics
  - types
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
aliases:
  - Обобщения Go
  - Параметры типов
draft: false
---

# Generics в Go

## Зачем это на интервью

Generics позволяют выразить один алгоритм или контейнер для семейства типов без `any`, reflection и дублирования. На интервью важнее не синтаксис, а выбор границы: кандидат E4 должен написать constraint и объяснить, почему generic helper лучше или хуже concrete функции и интерфейса. Избыточная параметризация делает API сложнее, не добавляя reuse.

## Минимум для E4

- [ ] Объявить type parameter у функции и использовать его в `[]T`, `map[K]V` или результате.
- [ ] Понимать constraint как интерфейс допустимых типов, а не runtime interface value.
- [ ] Использовать `comparable` только там, где нужен `==` или ключ map.
- [ ] Использовать `~` в type set, если алгоритм должен принимать named types с тем же underlying type.

Компилятор часто выводит аргументы типов из обычных аргументов. У вызова `Contains([]string{"go"}, "go")` не нужно писать `Contains[string]`. Constraint `comparable` включает типы, разрешённые в операторах `==` и `!=`, и поэтому подходит для ключа map.

```go
package main

import "fmt"

func Contains[T comparable](items []T, want T) bool {
    for _, item := range items {
        if item == want {
            return true
        }
    }
    return false
}

func main() {
    fmt.Println(Contains([]string{"go", "rust"}, "go"))
}
```

Для операций `<`, `+` и подобных constraint должен явно разрешать операторы. В стандартной библиотеке нет экспортируемого `constraints.Ordered`; определите локальный constraint либо используйте `cmp.Ordered` из пакета `cmp` в современных версиях Go.

```go
package main

import "fmt"

type Ordered interface {
    ~int | ~int64 | ~float64 | ~string
}

func Max[T Ordered](a, b T) T {
    if a > b {
        return a
    }
    return b
}

func main() {
    fmt.Println(Max(3, 5))
}
```

## Углубление для E5/Senior

Interface, использующийся как constraint, может содержать type terms (`~int`, `A | B`) и применим только как constraint; нельзя создать переменную такого interface type. Обычные методы в constraint задают операции, доступные для `T`; type set задаёт допустимое множество concrete types. Не проектируйте constraint «на будущее»: добавление type term или изменение union может сломать клиентов неочевиднее, чем изменение обычного интерфейса.

Generics не заменяют динамический полиморфизм. Если реализация выбирается во время работы (драйвер БД, отправитель уведомлений), используйте обычный interface. Если одна и та же статическая операция работает для многих форм данных (filter/map/min, typed cache), type parameter уместен. Для одной предметной сущности `UserID` concrete API обычно читается лучше generic контейнера с несколькими параметрами.

У generic type методы не могут иметь собственные type parameters: используйте parameters базового типа. Нельзя обращаться к полям `T` только потому, что все типы в union имеют такое поле; constraint обещает лишь разрешённые операции. Нет covariant/contravariant подтипирования `[]T`: `[]Dog` не является `[]Animal`, даже если `Dog` реализует `Animal`.

```go
package main

import "sync"

type Cache[K comparable, V any] struct {
    mu sync.RWMutex
    m  map[K]V
}

func NewCache[K comparable, V any]() *Cache[K, V] {
    return &Cache[K, V]{m: make(map[K]V)}
}

func (c *Cache[K, V]) Get(key K) (V, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    value, ok := c.m[key]
    return value, ok
}

func main() {
    _ = NewCache[string, int]()
}
```

Производительность измеряют, а не предполагают. Generics часто позволяют избежать boxing в `interface{}` и assertions, но generated code, inlining и escape behaviour зависят от версии компилятора и конкретного вызова. Для hot path проверяйте benchmark с `-benchmem`, а не выбирайте generic API только ради ожидаемого ускорения.

## Ключевые понятия

| Понятие         | Смысл                                     | Пример                              |
| --------------- | ----------------------------------------- | ----------------------------------- |
| Type parameter  | Переменная типа, известная при компиляции | `T any`                             |
| Type argument   | Конкретный тип в instantiation            | `Cache[string, User]`               |
| Constraint      | Ограничение допустимых типов и операций   | `K comparable`                      |
| Type set        | Множество типов constraint                | `~int                               | ~int64` |
| Underlying type | Базовый тип named type                    | `type UserID string` имеет `string` |

`any` — предопределённый alias `interface{}`. Он полезен, когда алгоритму не нужны операции над `T`, например `Clone[T any]`; это не сигнал использовать `any` для неструктурированного JSON или dependency injection.

## Типовые вопросы

1. **Когда выбрать generic, а когда interface?**
   - Generic — для статически типизированного алгоритма над несколькими типами; interface — для runtime-полиморфизма поведения.
2. **Зачем `~int`, а не `int`?**
   - `int` допускает только сам `int`; `~int` также допускает named types с underlying type `int`.
3. **Почему `T any` нельзя сравнить через `==`?**
   - `any` допускает несравнимые map, slice и func; нужен `T comparable` либо другая операция сравнения.
4. **Можно ли вызвать поле `x.ID` у `T`, ограниченного union structs?**
   - Нет, полевая селекция не выводится из type set; проектируйте метод в constraint или передавайте accessor.
5. **Может ли метод generic типа добавить новый type parameter?**
   - Нет. Методы используют parameters receiver type; вынесите такую операцию в generic функцию.
6. **Делают ли generics код автоматически быстрее?**
   - Нет. Возможны преимущества над boxing, но решение подтверждают benchmark и профиль на конкретной версии Go.

## Практика

- [ ] Напишите `Map[T, R any](in []T, f func(T) R) []R` и `Filter[T any]`.
  - **Критерии готовности:** порядок сохраняется; входной slice не меняется; тесты покрывают пустой input и nil slice; функция не использует `reflect`.
- [ ] Реализуйте thread-safe `Cache[K comparable, V any]` с `Get`, `Set`, `Delete`.
  - **Критерии готовности:** zero value либо явно документированно непригоден, либо безопасно работает; параллельный тест проходит `-race`; нет наружной ссылки на internal map.
- [ ] Замените две дублирующиеся функции поиска generic функцией.
  - **Критерии готовности:** API остаётся читаемым; named type `UserID string` проходит при нужном `~string`; добавлен benchmark до/после только при performance-цели.

## Частые ошибки и ловушки

- Создавать generic abstraction до второго реального случая использования.
- Ограничивать `T` через `any`, а затем делать type assertions внутри алгоритма.
- Заменять interface для runtime-сменяемой зависимости type parameter.
- Использовать `comparable` как «всё можно сравнивать содержательно»: pointer сравнивает адрес, struct — все сравнимые поля.
- Ожидать covariance `[]Child` → `[]Parent`.

## Связанные темы

- [[course/02-go/01-language/07-interfaces-nil-type-assertions|Интерфейсы, nil и type assertion]]
- [[course/02-go/01-language/06-methods-receivers|Методы и receivers]]
- [[course/04-algorithms|Алгоритмы и структуры данных]]
- [[course/02-go/index|Модуль Go]]

## Источники

- [Go specification: Type parameters](https://go.dev/ref/spec#Type_parameter_declarations).
- [Go specification: Interface types and type sets](https://go.dev/ref/spec#Interface_types).
- [Go blog: An Introduction to Generics](https://go.dev/blog/intro-generics).
- [Go blog: When To Use Generics](https://go.dev/blog/when-generics).
