---
title: "Finalizers, unsafe и cgo: границы допустимого"
description: "Почему внешние ресурсы закрывают явно, чем опасен unsafe и какую цену платит Go-код на границе cgo."
tags:
  - go
  - runtime
  - unsafe
  - cgo
  - security
status: complete
difficulty: e5
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Finalizers, unsafe и cgo: границы допустимого

Finalizer, `unsafe` и cgo нужны для узких задач взаимодействия с внешним миром, а не для обычной оптимизации Go-кода. Они ослабляют привычные гарантии языка: момент finalizer непредсказуем, `unsafe` переносит обязанность за layout/lifetime к автору, а cgo добавляет границу планировщика, правила указателей, сложную сборку и память вне видимости Go GC.

## Зачем это на интервью

Зрелый ответ начинается с безопасной альтернативы: `io.Closer`, чистый Go-пакет, официальный binding или изолированный процесс. Если низкоуровневый слой действительно нужен, кандидат формулирует ownership, lifetime, cancellation, errors, benchmark и проверку на всех целевых платформах — а не только демонстрирует преобразование указателя.

## Минимум для E4

- [ ] Для файла, сокета, транзакции и native handle применять детерминированный `Close`, не finalizer.
- [ ] Знать, что finalizer может не запуститься до завершения процесса, запуститься намного позже и не имеет порядка относительно другого finalizer.
- [ ] Использовать `unsafe` только при документированной необходимости и соблюдать правила пакета `unsafe`.
- [ ] Понимать, что вызов cgo дороже обычного Go-вызова и усложняет portability, профилирование и deployment.
- [ ] Не передавать C pointer на Go-память для хранения после вызова и не позволять C хранить Go pointers без разрешённого механизма.

## Углубление для E5/Senior

Finalizer допустим как аварийная страховка для диагностируемого native resource, но не как контракт освобождения. Он может удержать объект дольше, чем ожидается, resurrect object и создать цикл finalizer/GC. API должен иметь идемпотентный `Close`, документированное владение и тесты, не зависящие от времени GC. Для защиты lifetime при вызове C, когда последний видимый доступ к Go-объекту уже прошёл, используют `runtime.KeepAlive(x)` после cgo-вызова.

`unsafe.Pointer` не даёт права обходить сборщик, правила aliasing или границы массива. Преобразование pointer → `uintptr` полезно только для немедленного вычисления адреса в одном выражении; `uintptr` не удерживает объект живым. `unsafe.Slice`, `unsafe.String` и `unsafe.Add` используют только с доказанными length, alignment, lifetime и версией Go; предпочитайте безопасные API (`encoding/binary`, copy, slices) пока профиль не доказал необходимость.

cgo вызов может блокировать OS thread, ограничивать масштабирование и требует корректной передачи ошибок/отмены. GC не управляет `C.malloc`, поэтому native memory включают в memory budget и освобождают парным C API. При долгой работе C нужен отдельный lifecycle: timeout в Go не способен принудительно остановить произвольную C-функцию; иногда граница процесса безопаснее.

```go
package resource

import (
	"errors"
	"sync"
)

type Handle struct {
	once    sync.Once
	release func() error
}

func (h *Handle) Close() (err error) {
	if h == nil {
		return nil
	}
	h.once.Do(func() { err = h.release() })
	return err
}

func Open(release func() error) (*Handle, error) {
	if release == nil {
		return nil, errors.New("release function is required")
	}
	return &Handle{release: release}, nil
}
```

`sync.Once` делает закрытие идемпотентным, но этот упрощённый пример сохраняет только ошибку первого вызова, которая не будет автоматически возвращена повторным `Close`. Реальный API должен явно задокументировать это решение; finalizer его не заменяет.

## Ключевые понятия

| Понятие          | Суть                                            | Безопасная альтернатива                  |
| ---------------- | ----------------------------------------------- | ---------------------------------------- |
| Finalizer        | callback после того, как объект стал недостижим | явный `Close`/`defer`                    |
| `unsafe.Pointer` | мост к низкоуровневому представлению            | обычные types, `copy`, `encoding/binary` |
| `uintptr`        | целое адресного размера, не GC-root             | хранить typed pointer пока объект нужен  |
| cgo              | вызовы Go ↔ C с особыми правилами pointers      | Go library, RPC/process isolation        |
| `KeepAlive`      | продлевает достижимость до точки вызова         | явное владение плюс корректный bridge    |

## Типовые вопросы

1. **Почему finalizer не заменяет `Close`?**
   - Время запуска и порядок не гарантированы, а процесс может завершиться раньше. Внешний ресурс требует детерминированного освобождения и обработки ошибки.
2. **Когда оправдан `unsafe`?**
   - После профиля и при невозможности безопасного API: например, узкий системный binding или проверенная бинарная раскладка. Код изолируют, документируют инварианты и покрывают тестами.
3. **Почему нельзя хранить Go pointer в C после возврата?**
   - Его lifetime и возможная память подчинены GC; правила cgo запрещают C удерживать такие pointers. Передают копию C-памяти или `runtime/cgo.Handle` для Go value по разрешённому контракту.
4. **Освободит ли GC `C.malloc`?**
   - Нет. Native allocation освобождают соответствующим C API и учитывают в лимите процесса.
5. **Нужен ли `runtime.KeepAlive` в каждом cgo-вызове?**
   - Нет. Он нужен, когда компилятор может посчитать Go-объект мёртвым до момента, когда C завершило его использование; это подтверждают API/lifetime анализом.
6. **Почему timeout context не всегда отменяет C?**
   - Context сообщает Go-коду отмену, но не прерывает произвольный блокирующий C-код. Нужны поддержка cancellation в native API, ограничение ресурса или process boundary.

## Практика

- [ ] **Спроектируйте владение.** Оберните mock native handle в тип с `Close`, повторным закрытием и тестом освобождения при normal/error path.
  - Критерии готовности: ownership и порядок `defer` описаны; тест не вызывает `runtime.GC` для проверки закрытия.
- [ ] **Проведите unsafe-аудит.** Найдите одно применение `unsafe` и запишите тип, alignment, bounds, lifetime и версию Go, от которых оно зависит.
  - Критерии готовности: есть безопасная альтернатива и benchmark, обосновывающий исключение; код изолирован в маленьком пакете.
- [ ] **Оцените cgo boundary.** Сделайте benchmark batched и per-item вызова native API, а также нагрузочный тест memory budget.
  - Критерии готовности: измерены latency/throughput, C-memory lifecycle и поведение при отмене; решение включает portability/CI plan.

## Частые ошибки и ловушки

- Использовать finalizer для закрытия DB connection, file descriptor или mutex-protected handle.
- Вызывать `runtime.GC()` в тесте как доказательство корректного освобождения ресурса.
- Превращать pointer в `uintptr`, сохранять его и ожидать, что объект останется жив.
- Создавать Go slice поверх C memory без ясных lifetime, bounds и освобождения.
- Передавать каждую запись через cgo вместо batch/streaming API.
- Забывать, что `-race` не доказывает корректность C-кода и не заменяет sanitizer/native tests.

## Связанные темы

[[course/02-go/05-runtime-memory|Go runtime и память]] · [[course/02-go/05-runtime-memory/01-stack-growth-escape-heap|Stack и escape analysis]] · [[course/02-go/04-context-lifecycle|Context и жизненный цикл]] · [[course/01-foundations/02-performance/05-allocation-rate-gc-pressure|Память и GC pressure]]

## Источники

- [Package runtime: `SetFinalizer` и `KeepAlive`](https://pkg.go.dev/runtime#SetFinalizer) (проверено 2026-10-02).
- [Package unsafe](https://pkg.go.dev/unsafe) (проверено 2026-10-02).
- [cgo command documentation](https://pkg.go.dev/cmd/cgo) (проверено 2026-10-02).
- [Go proposal: cgo pointer passing rules](https://go.dev/wiki/cgo#Go_pointers_passing_to_C) (проверено 2026-10-02).
- [Package runtime/cgo: Handle](https://pkg.go.dev/runtime/cgo#Handle) (проверено 2026-10-02).
