---
title: "GC pacing, GOGC, memory limit и stop-the-world"
description: "Как runtime выбирает темп GC, что регулируют GOGC и GOMEMLIMIT и почему короткие STW-фазы всё ещё важны."
tags:
  - go
  - runtime
  - garbage-collection
  - performance
status: complete
difficulty: e5
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# GC pacing, GOGC, memory limit и stop-the-world

Pacer Go выбирает объём и темп GC work, чтобы завершить mark до целевого роста heap. `GOGC` задаёт относительную цель роста heap от live heap; `GOMEMLIMIT`/`debug.SetMemoryLimit` добавляют soft memory limit, который может сделать цель существенно ниже. Эти механизмы регулируют компромисс между памятью, CPU и latency, но не заменяют capacity planning и лимит cgroup.

## Зачем это на интервью

В production часто предлагают «увеличить GOGC» или «поставить memory limit». Хороший ответ сначала называет live heap, allocation rate, non-Go memory, cgroup limit и SLO. Затем он описывает эксперимент с p99, GC CPU и OOM/reclaim метриками, потому что настройка, улучшающая throughput, может сделать pod менее устойчивым.

## Минимум для E4

- [ ] Объяснять грубую модель: при `GOGC=100` цель следующего heap примерно `live heap + 100% live heap` без учёта ограничений pacer.
- [ ] Знать, что больший `GOGC` обычно реже запускает GC и позволяет больше памяти; меньший — чаще собирает и тратит больше CPU.
- [ ] Знать, что `GOMEMLIMIT` — soft limit runtime, а `GOGC=off` не отключает GC при действующем memory limit.
- [ ] Перечислять источники памяти вне Go heap: stacks, metadata, binary, mmap, network buffers и C allocations.
- [ ] Знать, что concurrent GC содержит короткие stop-the-world фазы; «concurrent» не означает отсутствие влияния на tail latency.

## Углубление для E5/Senior

Pacer учитывает allocation rate, mark work и достижимую память; формула `GOGC` годится только для объяснения направления. При memory limit runtime может снижать effective GC goal ниже процента `GOGC`, чтобы удерживать memory usage около лимита. Если workload фактически требует больше достижимой памяти, runtime способен тратить почти всё время на GC, а не гарантировать невозможность OOM. Официальная документация рекомендует не задавать лимит ниже устойчивого memory footprint и оставлять headroom.

STW включает начало mark (подготовка и сканирование корней) и mark termination; их длительность зависит, в частности, от числа goroutine/stacks и объёма root work. Важны также GC assists и конкуренция за CPU: даже concurrent mark снижает доступный mutator CPU. Измеряйте trace/metrics и p99 на том же `GOMAXPROCS`, CPU quota и input mix, что в production.

```go
package main

import (
	"runtime/debug"
)

func configureMemory() {
	// Значение выбирают ниже лимита контейнера после измерений.
	// 512 MiB — пример, не переносимая production-настройка.
	debug.SetMemoryLimit(512 << 20)
	debug.SetGCPercent(100) // Возвращает прежнее значение; GOGC-аналог в коде.
}
```

Переменные окружения обычно проще стандартизировать в deployment: `GOGC=100` и `GOMEMLIMIT=...`. Не смешивайте их с догадкой о текущем cgroup limit: runtime не знает бюджета внешних библиотек.

## Ключевые понятия

| Понятие      | Суть                                         | Не путать с                      |
| ------------ | -------------------------------------------- | -------------------------------- |
| GC goal      | ориентир размера heap к завершению цикла     | жёстким лимитом RSS              |
| `GOGC`       | процент роста heap от live heap              | долей CPU GC                     |
| `GOMEMLIMIT` | soft limit памяти для runtime                | cgroup memory.max                |
| STW          | фаза остановки goroutine для части GC работы | продолжительностью полного цикла |
| GC assist    | mark work в allocating goroutine             | отдельным background worker      |

## Типовые вопросы

1. **Когда повышать `GOGC`?**
   - Когда профиль показывает значимый GC CPU/частоту циклов и есть проверенный memory headroom. Измеряют p99, RSS/cgroup и throughput, а не меняют переменную по умолчанию.
2. **Почему нельзя поставить `GOMEMLIMIT` равным 1 GiB container limit?**
   - Останется нулевой запас для stacks, runtime, mmap, C и колебаний RSS; OOM killer/cgroup видит процесс целиком.
3. **Что означает STW в современном Go?**
   - Не «всё приложение стоит весь GC-цикл», а короткие синхронизационные фазы. Они всё равно способны влиять на latency-sensitive путь.
4. **Избавляет ли малый `GOGC` от OOM?**
   - Нет: live data или non-Go memory могут превысить бюджет; частый GC ещё и снизит полезную работу.
5. **Почему p99 вырос, хотя STW короткий?**
   - Возможны assist, уменьшение доступного CPU concurrent marker-ами, очереди и наложение на запрос. Нужны trace, CPU и latency correlation.
6. **Как безопасно менять настройки?**
   - Canary на representative workload, лимиты/rollback, сравнение GC CPU, runtime metrics, cgroup events, RSS, throughput и percentiles.

## Практика

- [ ] **Снимите baseline pacer.** На постоянной нагрузке соберите `GODEBUG=gctrace=1` в тестовой среде, runtime metrics, CPU и p99.
  - Критерии готовности: лог не включён бесконтрольно в production; есть версия Go, `GOMAXPROCS` и workload.
- [ ] **Проверьте две политики.** Сравните baseline с другим `GOGC`, не меняя вход и CPU quota.
  - Критерии готовности: минимум три запуска, показаны RSS, GC CPU, throughput и p99; выбранный trade-off записан явно.
- [ ] **Задайте memory headroom.** В cgroup experiment установите `GOMEMLIMIT` ниже memory.max и проверьте низкий лимит как негативный случай.
  - Критерии готовности: учтены non-heap/cgo расходы и `memory.events`; вывод не называет soft limit гарантией от OOM.

## Частые ошибки и ловушки

- Превращать упрощённую формулу `GOGC` в точный прогноз capacity.
- Сравнивать настройки при разной нагрузке, версии Go или CPU quota.
- Ставить слишком низкий memory limit и интерпретировать падение throughput как «защиту».
- Смотреть только на среднюю latency и пропускать p99/p999.
- Отключать GC без ограниченного по времени диагностического эксперимента и memory budget.

## Связанные темы

[[course/02-go/05-runtime-memory|Go runtime и память]] · [[course/02-go/05-runtime-memory/02-garbage-collector-tricolor|Tri-color GC]] · [[course/01-foundations/02-performance/06-throughput-latency-tail-latency|Tail latency]] · [[course/10-observability|Наблюдаемость]]

## Источники

- [Go GC guide: GOGC and memory limit](https://go.dev/doc/gc-guide) (проверено 2026-10-02).
- [Package runtime/debug: `SetMemoryLimit`](https://pkg.go.dev/runtime/debug#SetMemoryLimit) (проверено 2026-10-02).
- [Go runtime metrics](https://pkg.go.dev/runtime/metrics) (проверено 2026-10-02).
- [Go execution tracer](https://go.dev/doc/diagnostics#execution-tracer) (проверено 2026-10-02).
