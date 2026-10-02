---
title: "Map: устройство, ограничения и конкурентный доступ"
description: "Концептуальная модель map, порядок обхода, non-addressable элементы и синхронизация."
tags:
  - go
  - collections
  - concurrency
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Map: устройство, ограничения и конкурентный доступ

## Зачем это на интервью

Map даёт среднюю амортизированную $O(1)$ операцию по ключу, но имеет ограничения языка и runtime. Неправильный конкурентный доступ может завершить процесс или создать data race.

## Минимум для E4

- [ ] Проверять наличие ключа через `v, ok := m[k]`.
- [ ] Не полагаться на порядок `range`.
- [ ] Не читать и не писать один обычный map одновременно без синхронизации.

## Углубление для E5/Senior

Map реализован runtime как хеш-таблица; детали bucket/роста не являются стабильным API. Ключ должен быть comparable; slice, map и function ключами быть не могут. Выбор между `sync.Mutex`, `sync.RWMutex`, sharding, copy-on-write и `sync.Map` делается по профилю чтений/записей, времени критической секции, типам ключей и измерениям. `sync.Map` специализирован, а не «быстрый map с mutex» по умолчанию.

## Ключевые понятия

Элемент map не адресуем: runtime может переместить его при росте, поэтому нельзя написать `m[k].Field = x`. Достаньте значение, измените и запишите обратно.

```go
type Counter struct{ N int }
m := map[string]Counter{"ok": {N: 1}}
c := m["ok"]
c.N++
m["ok"] = c

if v, ok := m["missing"]; !ok { fmt.Println("нет ключа") } else { fmt.Println(v) }
```

Для обычного map критическая секция охватывает все обращения:

```go
type Cache struct {
	mu sync.RWMutex
	m  map[string]string
}
func (c *Cache) Get(k string) (string, bool) { c.mu.RLock(); defer c.mu.RUnlock(); v, ok := c.m[k]; return v, ok }
func (c *Cache) Put(k, v string) { c.mu.Lock(); defer c.mu.Unlock(); c.m[k] = v }
```

`range` намеренно имеет нефиксированный порядок: для детерминированного вывода соберите и отсортируйте ключи.

## Типовые вопросы

1. **Почему `m[k].Field = x` не компилируется?**
   - Значение map не addressable; измените локальную копию и присвойте её обратно.
2. **Можно ли читать map параллельно?**
   - Несколько чтений без записей допустимы; любой конкурентный writer требует синхронизации всех обращений.
3. **Гарантирован ли порядок `range`?**
   - Нет; он не предназначен для стабильного порядка.
4. **Что означает нулевое значение при lookup?**
   - Оно не отличает отсутствующий ключ от ключа со значением zero value; нужен `ok`.
5. **Когда выбрать `sync.Map`?**
   - Для его документированных паттернов: write-once/read-many или разрозненные ключи; иначе часто проще map с mutex.

## Практика

- [ ] Реализуйте счётчик по ключу с `Mutex`. **Готово:** `go test -race` не находит race, а API не отдаёт внутренний map.
- [ ] Верните ключи map в лексикографическом порядке. **Готово:** тест не зависит от порядка `range`.

## Частые ошибки и ловушки

- Использовать nil map для записи: это panic; инициализируйте `make`.
- Защищать только записи, оставляя чтения без того же lock.
- Держать lock во время медленного I/O или callback.

## Связанные темы

[[course/02-go/02-collections|Коллекции и работа с данными]] · [[course/02-go/03-concurrency|Конкурентность]]

## Источники

- [Go specification: Map types](https://go.dev/ref/spec#Map_types)
- [Go specification: For statements with range](https://go.dev/ref/spec#For_statements)
- [sync.Map documentation](https://pkg.go.dev/sync#Map)
