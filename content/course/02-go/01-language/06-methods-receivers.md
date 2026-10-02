---
title: Методы и receivers в Go
description: Как method set, value receiver и pointer receiver определяют API типа, мутации и реализацию интерфейсов.
tags:
  - go
  - language
  - methods
  - interfaces
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
aliases:
  - Методы Go
  - Value и pointer receiver
draft: false
---

# Методы и receivers в Go

## Зачем это на интервью

Метод в Go привязан к именованному типу через receiver, а не к классу. На E4 проверяют, понимает ли кандидат разницу между `T` и `*T`: она влияет на мутацию, копирование, method set и то, удовлетворяет ли значение интерфейсу. На production-коде неверный receiver может дать тихую потерю изменения, лишнюю копию `sync.Mutex` или несовместимость публичного API.

## Минимум для E4

- [ ] Объяснить, что value receiver получает копию значения, а pointer receiver — указатель на исходный объект.
- [ ] Выбрать pointer receiver для изменения состояния, больших структур и типов, которые нельзя копировать.
- [ ] Назвать method sets: у `T` — методы с receiver `T`; у `*T` — методы с receiver `T` и `*T`.
- [ ] Не смешивать receivers у одного типа без осознанной причины.

Компилятор автоматически берёт адрес **addressable** значения при вызове pointer-метода: `account.Deposit(10)` эквивалентен `(&account).Deposit(10)`. Это удобство не меняет method set и не работает для временных значений, map-элементов и значений, полученных из интерфейса.

```go
package main

import "fmt"

type Account struct {
    owner   string
    balance int64
}

func (a Account) Label() string {
    return fmt.Sprintf("%s: %d", a.owner, a.balance)
}

func (a *Account) Deposit(amount int64) {
    if amount > 0 {
        a.balance += amount
    }
}

func main() {
    a := Account{owner: "Mira"}
    a.Deposit(100) // a addressable: компилятор передаёт &a
    fmt.Println(a.Label())
}
```

## Углубление для E5/Senior

Receiver — часть контракта и совместимости. Изменение exported метода с value receiver на pointer receiver способно сломать присваивание `T` интерфейсу у клиентов. Выбирайте receiver до публикации API и фиксируйте ожидание compile-time проверкой: `var _ fmt.Stringer = (*Account)(nil)`.

Value receiver не означает «дешёвый»: он копирует всю структуру, хотя её поля могут быть заголовками slice/map/string и по-прежнему указывать на общие данные. Поэтому value-метод не может присвоить новое значение полю исходного struct, но может изменить элементы slice, на которые указывает скопированный заголовок. Это не замена ясному владению данными.

Не копируйте после первого использования `sync.Mutex`, `sync.Once`, `sync.WaitGroup`, `atomic`-значения и типы с внутренней синхронизацией. `go vet -copylocks` обнаруживает типичные случаи. Для таких типов pointer receiver — требование корректности, а не оптимизация.

Встраивание (`embedding`) продвигает методы вложенного поля. У `struct{ T }` продвигаются методы `T`; у `struct{ *T }` — также pointer-методы `*T`. Но promotion не отменяет правил method set: при проектировании публичного API лучше явно проверять, какой именно тип реализует интерфейс.

```go
package main

import (
    "fmt"
    "sync"
)

type Counter struct {
    mu sync.Mutex
    n  int
}

func (c *Counter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.n++
}

func (c *Counter) Value() int {
    c.mu.Lock()
    defer c.mu.Unlock()
    return c.n
}

func main() {
    var c Counter
    c.Inc()
    fmt.Println(c.Value())
}
```

## Ключевые понятия

| Понятие           | Смысл                        | Практическое следствие                              |
| ----------------- | ---------------------------- | --------------------------------------------------- |
| Value receiver    | Метод получает копию `T`     | Не меняет поля исходного struct присваиванием       |
| Pointer receiver  | Метод получает `*T`          | Может менять состояние и избегает копии struct      |
| Method set `T`    | Только методы с receiver `T` | `T` не реализует интерфейс, требующий pointer-метод |
| Method set `*T`   | Методы `T` и `*T`            | `*T` обычно имеет более широкий набор методов       |
| Addressable value | Значение с доступным адресом | Позволяет неявный `&` при обычном вызове            |

Нельзя объявлять метод на pointer или interface type, а также на не-local type: базовый именованный тип receiver должен быть определён в том же пакете. Для внешнего типа создайте свой named type или функцию-адаптер, не пытайтесь «добавить» ему метод.

## Типовые вопросы

1. **Почему `T` не реализует интерфейс с методом `func (*T) M()`?**
   - Method set `T` не содержит методов с pointer receiver; неявное взятие адреса разрешено только в конкретном вызове, но не при проверке интерфейса.
2. **Когда value receiver предпочтительнее?**
   - Для маленького неизменяемого value-типа, например `time.Duration`-подобного типа, когда копирование дешево и оба `T`/`*T` должны реализовывать интерфейс.
3. **Меняет ли value-метод элементы `slice`-поля?**
   - Может: копируется заголовок slice, но backing array остаётся общим. Присваивание новому slice-полю затронет только копию receiver.
4. **Почему нельзя вызвать pointer-метод у `m[key]`?**
   - Элемент map не addressable: map может переместить его. Нужно извлечь значение, изменить и записать обратно либо хранить `*T`.
5. **Нужно ли всегда брать pointer receiver для производительности?**
   - Нет. Это меняет семантику и interface compatibility; сначала важны мутабельность, copy safety и API.
6. **Что произойдёт при копировании struct с mutex?**
   - Появятся две независимые блокировки, которые могут защищать одно логическое состояние неправильно; такой код некорректен.

## Практика

- [ ] Реализуйте `BankAccount` с `Deposit`, `Withdraw` и `Balance`.
  - **Критерии готовности:** изменяющие методы имеют pointer receiver; отрицательная сумма отвергается; параллельный тест проходит `go test -race`.
- [ ] Сделайте тип `Point` с value-методом `Distance(Point) float64` и объясните выбор.
  - **Критерии готовности:** тип не содержит mutable shared state; оба `Point` и `*Point` удовлетворяют интерфейсу расстояния; тест покрывает нулевую точку.
- [ ] Напишите пример с `map[string]Counter`, исправьте ошибку вызова pointer-метода.
  - **Критерии готовности:** показаны оба решения — read-modify-write и `map[string]*Counter`; выбранный вариант объясняет владение и concurrency.

## Частые ошибки и ловушки

- Использовать value receiver у struct с mutex или `sync.Once`.
- Смешивать value и pointer receivers и неожиданно менять реализацию интерфейса.
- Считать, что pointer receiver автоматически делает все вложенные данные безопасными для concurrent access.
- Хранить `*T` в map только ради вызова метода, не определив, кто владеет объектом и когда он живёт.
- Принимать неявный `&` за правило интерфейсов: его нет при присваивании `var x I = value`.

## Связанные темы

- [[course/02-go/01-language/07-interfaces-nil-type-assertions|Интерфейсы, nil и type assertion]]
- [[course/02-go/01-language/09-defer-panic-recover|defer, panic и recover]]
- [[course/02-go/index|Модуль Go]]

## Источники

- [Go specification: Method declarations](https://go.dev/ref/spec#Method_declarations).
- [Go specification: Method sets](https://go.dev/ref/spec#Method_sets).
- [Go Code Review Comments: Receiver Type](https://go.dev/wiki/CodeReviewComments#receiver-type).
- [Go `sync` package](https://pkg.go.dev/sync).
