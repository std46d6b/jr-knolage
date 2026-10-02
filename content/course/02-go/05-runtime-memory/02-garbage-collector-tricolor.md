---
title: "Garbage collector Go: трёхцветная маркировка и concurrent GC"
description: "Концептуальная модель tri-color marking, write barrier и стоимость concurrent garbage collector Go."
tags:
  - go
  - runtime
  - garbage-collection
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Garbage collector Go: трёхцветная маркировка и concurrent GC

GC Go определяет, какие heap-объекты достижимы из корней, и делает память недостижимых объектов доступной allocator. Практическая модель — concurrent, tracing, non-moving mark-and-sweep collector с трёхцветной маркировкой. Она объясняет, почему важны граф указателей, write barrier и allocation rate, но не является точной схемой всех внутренних фаз runtime.

## Зачем это на интервью

Интервьюер ожидает не исходный код runtime, а причинную модель: GC не делает `free` в момент, когда переменная вышла из области видимости; он обходит достижимый граф. Поэтому длинноживущие ссылки, pointer-rich объекты и высокая скорость выделений влияют на CPU, память и задержки.

## Минимум для E4

- [ ] Назвать GC Go tracing и преимущественно concurrent, non-moving mark-and-sweep.
- [ ] Объяснить цвета: белый — ещё не доказанно живой, серый — найден и ожидает сканирования, чёрный — просканирован.
- [ ] Знать, что корни включают globals, stacks goroutine и runtime roots; достижимые от них объекты остаются живыми.
- [ ] Понимать назначение write barrier во время concurrent marking: сохранить инвариант маркировки при изменении указателей mutator-ом.
- [ ] Не обещать нулевые паузы: у цикла есть короткие STW-фазы, а mutator может выполнять GC assist.

## Углубление для E5/Senior

В полезной модели GC начинает с белых объектов, делает корни серыми, сканирует серые объекты и красит их чёрными; недостижимое белое после mark можно sweep-ить. Concurrent mutator может записать ссылку из уже чёрного объекта на белый, «спрятав» живой объект от обхода. Hybrid write barrier runtime поддерживает корректность, сохраняя нужные объекты доступными маркировке; это не повод вручную управлять barrier в обычном Go-коде.

Стоимость mark зависит не только от байтов. Сканирование pointer slots и большого графа маленьких объектов может быть дороже, чем сканирование такого же объёма pointer-free data. Но заменять структуру на сырой буфер можно лишь с сохранением инвариантов, кодировки и наблюдаемости. Оптимизация — удалить ненужное владение или промежуточные объекты, затем измерить CPU, `alloc_space`, `inuse_space` и p99.

```go
package main

import "runtime"

type node struct {
	next *node
	data []byte
}

func main() {
	head := &node{data: make([]byte, 1024)}
	head.next = &node{data: make([]byte, 1024)}

	// Пока head достижим, достижима и вся цепочка через next.
	head = nil
	runtime.GC() // Только для демонстрации/теста; не механизм управления памятью в сервисе.
}
```

Присваивание `nil` освобождает ссылку приложения, но не даёт гарантии момента sweep или возврата страниц ОС.

## Ключевые понятия

| Понятие       | Суть                                                               | Практическое следствие                      |
| ------------- | ------------------------------------------------------------------ | ------------------------------------------- |
| Root          | исходная точка достижимости                                        | ссылка в global/stack может удерживать граф |
| Mark          | поиск живых объектов                                               | цена зависит от live graph и pointers       |
| Sweep         | подготовка памяти недостижимых объектов к повторному использованию | не равен немедленному снижению RSS          |
| Write barrier | код runtime при записи pointers во время mark                      | защищает корректность concurrent GC         |
| GC assist     | часть mark work выполняет allocating goroutine                     | может попасть в latency path                |

## Типовые вопросы

1. **Почему GC не использует reference counting?**
   - Tracing collector естественно обрабатывает циклы. Детали реализации — выбор runtime, но приложению важнее достижимость, а не счётчик ссылок.
2. **Что ломается без write barrier?**
   - Concurrent программа может сделать белый объект достижимым из уже просканированного чёрного объекта, и marker пропустит живые данные. Barrier поддерживает инвариант маркировки.
3. **Освободит ли `runtime.GC()` память ОС?**
   - Нет гарантии: он запускает GC, но свободная память может остаться у runtime; вызов в production часто лишь маскирует retention или создаёт overhead.
4. **Почему объект с `[]byte` может быть дешевле graph из pointers?**
   - У byte slice обычно меньше pointer slots для сканирования. Но полная стоимость включает копии, codec и lifetime, поэтому нужен профиль.
5. **Может ли GC собрать объект, который ещё использует cgo?**
   - Да, если компилятор считает Go-ссылку больше не нужной. В корректном bridging-коде используют `runtime.KeepAlive` после последнего обращения C к объекту.
6. **Собирает ли GC goroutine?**
   - Он собирает недостижимые heap-объекты; зависшая goroutine остаётся runtime-сущностью и может удерживать stack, context и данные. Её завершают протоколом cancellation.

## Практика

- [ ] **Постройте граф удержания.** Создайте cache с явным `Delete`, затем вариант без удаления и снимите `inuse_space` profiles.
  - Критерии готовности: показан retaining path; тест не полагается на точный момент GC.
- [ ] **Отделите churn от retention.** Нагрузите функцию короткоживущими объектами, сохраните `alloc_space` и `inuse_space`.
  - Критерии готовности: вывод объясняет разницу профилей, CPU и частоты GC.
- [ ] **Проверьте latency.** Замерьте p99 и GC CPU при двух разных формах данных с одинаковой семантикой.
  - Критерии готовности: названы pointer density, allocation rate и trade-off, а не только один benchmark number.

## Частые ошибки и ловушки

- Говорить, что white object «точно мусор» до завершения mark.
- Путать concurrent GC с отсутствием пауз или CPU overhead.
- Вручную вызывать `runtime.GC` после каждого большого запроса.
- Делать вывод о leak по `alloc_space`: этот профиль показывает все выделения, включая уже освобождённые.
- Держать ссылку на root cache/queue без eviction policy.

## Связанные темы

[[course/02-go/05-runtime-memory|Go runtime и память]] · [[course/02-go/05-runtime-memory/03-gc-pacing-memory-limit-stw|Пейсинг, memory limit и STW]] · [[course/02-go/04-context-lifecycle|Context и жизненный цикл]] · [[course/01-foundations/02-performance/05-allocation-rate-gc-pressure|GC pressure]]

## Источники

- [A Guide to the Go Garbage Collector](https://go.dev/doc/gc-guide) (проверено 2026-10-02).
- [Getting to Go: The Journey of Go's Garbage Collector](https://go.dev/blog/ismmkeynote) (проверено 2026-10-02).
- [Package runtime: `KeepAlive`](https://pkg.go.dev/runtime#KeepAlive) (проверено 2026-10-02).
- [Go runtime source: `mbarrier.go`](https://go.dev/src/runtime/mbarrier.go) (проверено 2026-10-02).
