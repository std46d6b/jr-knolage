---
title: "Go runtime и управление памятью"
description: "Карта раздела: stack, heap, GC, лимиты памяти и безопасные границы unsafe/cgo."
tags:
  - go
  - runtime
  - memory
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Go runtime и управление памятью

Go runtime управляет стеками goroutine, heap и большей частью работы garbage collector (GC). Это не отменяет ответственности приложения: удерживаемые ссылки, неограниченные очереди, C-память и неверно выбранный memory budget могут привести к OOM или росту p99 независимо от того, насколько «автоматически» работает GC.

## Зачем это на интервью

Тема проверяет, способен ли разработчик объяснить рост RSS, частые циклы GC или медленный сервис через измеримые причины, а не через общее «утечка памяти». Для backend-сервиса нужно уметь отличить высокий allocation rate от retention, выбрать безопасный лимит контейнера и не применять `unsafe`, finalizer или `sync.Pool как универсальную оптимизацию`.

## Минимум для E4

- [ ] Различать stack goroutine, Go heap, RSS процесса и память, выделенную C-библиотекой.
- [ ] Знать: escape analysis компилятора выбирает stack/heap для конкретной сборки; heap allocation сам по себе не ошибка.
- [ ] Объяснять, что GC трассирует достижимые Go-объекты, работает преимущественно concurrent и не обязан сразу вернуть свободные страницы ОС.
- [ ] Знать назначение `GOGC` и `GOMEMLIMIT`: первое — цель роста heap, второе — soft limit runtime, а не лимит RSS или защита от OOM.
- [ ] Считать finalizer ненадёжным механизмом освобождения ресурса; для внешнего ресурса применять явный `Close`.

## Углубление для E5/Senior

Память планируют как бюджет процесса, а не только как `HeapAlloc`: сюда входят live heap, временный рост heap, goroutine stacks, runtime metadata, binary, mmap, сетевые буферы и память cgo. `GOMEMLIMIT` оставляют ниже лимита cgroup с запасом на эти части. При тесном лимите pacer может увеличить долю CPU на GC, ухудшив throughput до OOM.

Измерение предшествует тюнингу: сравнивают `runtime/metrics`, heap profile (`inuse_space` и `alloc_space`), CPU/p99 и cgroup memory events на репрезентативной нагрузке. Рост retained heap после снятия нагрузки — гипотеза о retention; высокий `alloc_space` при стабильном `inuse_space` — гипотеза о churn. Оба случая требуют поиска владельца ссылки или allocation site, а не произвольной смены `GOGC`.

## Ключевые понятия

| Понятие         | Суть                                                               | Не означает                      |
| --------------- | ------------------------------------------------------------------ | -------------------------------- |
| Stack           | память вызовов одной goroutine, растущая и копируемая runtime      | фиксированный потоковый stack ОС |
| Heap            | область объектов, срок жизни которых нельзя ограничить stack frame | всю память процесса              |
| Escape          | решение компилятора о размещении значения                          | доказательство bottleneck        |
| Live heap       | объекты, достижимые после mark                                     | RSS                              |
| Allocation rate | байты/объекты, выделяемые за время                                 | размер живого heap               |
| STW             | короткая фаза, где мир goroutine остановлен для работы GC          | весь GC-цикл                     |

## Типовые вопросы

1. **Почему RSS может не падать после GC?**
   - Runtime может удерживать освобождённые spans для будущих аллокаций; RSS также содержит stacks, metadata, mmap и non-Go memory. Сначала смотрят heap profile и метрики, а не требуют немедленного возврата страниц ОС.
2. **Когда heap allocation — проблема?**
   - Когда профиль показывает существенную стоимость в hot path или удержание нарушает budget. Вне него простая аллокация часто лучше сложного кода.
3. **Почему GC не освобождает файл или сокет вовремя?**
   - GC знает о достижимости Go-объекта, не о жизненном цикле внешнего ресурса. Нужен детерминированный `Close`, обычно через `defer` в ограниченной области.
4. **Ставит ли `GOMEMLIMIT` жёсткий предел памяти?**
   - Нет. Это ориентир для runtime; общий процесс всё равно может превысить budget из-за не-Go памяти и накладных расходов.
5. **Почему указатель на маленькую подстроку может удержать большой буфер?**
   - Slice/string может разделять backing storage; пока существует ссылка на часть, весь массив остаётся достижимым.

## Практика

- [ ] **Снимите baseline памяти.** Запустите сервис под фиксированной нагрузкой и сохраните heap profile, `/memory/classes/heap/objects:bytes`, RSS и p99.
  - Критерии готовности: workload и версия Go записаны; отдельно названы live heap, allocation rate и общий memory budget.
- [ ] **Проверьте allocation-гипотезу.** Выполните `go test -bench=. -benchmem -memprofile mem.out ./...` и исследуйте `go tool pprof -http=:0 mem.out`.
  - Критерии готовности: найден конкретный allocation site; изменение подтверждено тестом и сравнением не менее трёх запусков.
- [ ] **Спроектируйте container headroom.** Укажите cgroup limit, резерв на non-heap память и значение `GOMEMLIMIT`.
  - Критерии готовности: нагрузочный тест содержит CPU, p99, memory.events и вывод о запасе до OOM.

## Частые ошибки и ловушки

- Называть любой рост RSS «утечкой», не разделив live heap, cache/idle pages и non-Go memory.
- Оптимизировать под один вывод `-gcflags=-m`, не проверив benchmark и профиль.
- Ставить `GOMEMLIMIT` равным лимиту pod/container.
- Оставлять неограниченную очередь или кэш в надежде на GC.
- Передавать владение C-ресурсом finalizer вместо явного `Close`.

## Связанные темы

[[course/02-go|Go]] · [[course/02-go/05-runtime-memory/01-stack-growth-escape-heap|Стек, escape analysis и heap]] · [[course/02-go/05-runtime-memory/02-garbage-collector-tricolor|Трёхцветный GC]] · [[course/02-go/05-runtime-memory/03-gc-pacing-memory-limit-stw|Пейсинг GC и лимиты]] · [[course/01-foundations/02-performance/05-allocation-rate-gc-pressure|Аллокации и GC pressure]]

## Источники

- [Go: A Guide to the Go Garbage Collector](https://go.dev/doc/gc-guide) (проверено 2026-10-02).
- [Package runtime](https://pkg.go.dev/runtime) (проверено 2026-10-02).
- [runtime/metrics](https://pkg.go.dev/runtime/metrics) (проверено 2026-10-02).
- [Go cgo documentation](https://pkg.go.dev/cmd/cgo) (проверено 2026-10-02).
