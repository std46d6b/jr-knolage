---
title: Профилирование производительности
description: "Дисциплина поиска bottleneck: репрезентативная нагрузка, профиль, проверяемая гипотеза и повторное измерение."
tags:
  - performance
  - profiling
  - go
  - observability
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Профилирование производительности

Профилирование — это получение измерений о том, где программа тратит CPU, память, время ожидания и системные ресурсы. Его цель не «найти самую дорогую функцию» в вакууме, а проверить гипотезу на репрезентативной нагрузке: какой пользовательский SLI нарушен, какой ресурс насыщен, какой участок является причиной и улучшает ли изменение целевую метрику без регрессии.

## Зачем это на интервью

Сильный кандидат не предлагает «оптимизировать всё» и не верит одному flame graph. Он формулирует workload, снимает baseline, выбирает профиль по симптомам, интерпретирует sampling корректно и показывает результат повторным измерением. Для Go это означает различать CPU, heap/allocs, goroutine, block, mutex и execution trace; для Linux — дополнять их `perf`, cgroup и системными метриками.

## Минимум для E4

- [ ] До оптимизации определить SLI, workload, baseline, версию бинарника, окружение и критерий успеха.
- [ ] Уметь собрать CPU profile (`pprof`), heap/allocs profile и benchmark с `-benchmem` для Go-кода.
- [ ] Отличать `flat` от `cum`: flat показывает время в самой функции, cumulative — время в ней и вызовах ниже.
- [ ] Выбирать профиль по вопросу: CPU — где исполнялись инструкции, allocs — где создавались объекты, block/mutex — где ожидали, trace — как планировались goroutine.
- [ ] Делать одно узкое изменение, сохранять тесты и повторять тот же замер; не считать визуальную смену flame graph доказательством.

## Углубление для E5/Senior

### Сначала эксперимент, затем инструмент

Нагрузочный сценарий фиксирует входные данные, arrival/concurrency model, длительность, warm-up, CPU quota, настройки runtime и cache state. Иначе сравнение профилей не причинно: один прогон может отличаться сетевым состоянием, другой — частотой CPU или количеством ошибок. Для latency-sensitive сервисов одновременно записывают success throughput, errors, p50/p95/p99 и saturation из [[course/01-foundations/02-performance/06-throughput-latency-tail-latency|распределения latency]].

Sampling CPU profile статистичен: он показывает, где поток исполнялся в момент выборок, и может не уловить редкий stall. CPU profile не доказывает, что функция вызвала p99; она могла эффективно занимать CPU в быстрых запросах. Для хвоста нужны trace, exemplars, профили под перегрузкой и корреляция с зависимостями. С другой стороны, wall-clock profile без понимания блокировок может обвинить функцию, которая лишь стоит выше ожидающего вызова.

### Go-профили по назначению

```bash
go test ./internal/handler -run '^$' -bench '^BenchmarkDecode$' \
  -benchmem -count=5 -cpuprofile=cpu.out -memprofile=mem.out

go tool pprof -http=:0 cpu.out
go tool pprof -sample_index=alloc_space mem.out
```

Heap profile отвечает на два разных вопроса. `inuse_space` показывает удерживаемую память на момент снимка; `alloc_space` — места, которые выделили много байтов за весь интервал. Первое ищет retention/leak, второе — GC pressure. Block и mutex profiles требуют настройки частоты sampling и могут иметь overhead; включайте их на коротком контролируемом интервале. `go tool trace` показывает scheduling, network/syscall blocking и GC, но файл trace может быть большим и сам влиять на нагрузку.

Профили с production endpoint должны быть защищены: pprof не публикуют в интернет, доступ ограничивают сетью и аутентификацией, интервалы и overhead согласуют с владельцем сервиса. Сырые profile/trace могут содержать имена функций, пути и данные контекста — храните их как чувствительные operational artifacts по политике команды.

### Системная граница и differential profiling

Если CPU профайл приложения «чистый», это не означает отсутствия bottleneck. Процесс может ждать сеть, filesystem, scheduler, cgroup throttling или remote dependency. Смотрите runtime metrics, `/proc`, PSI, cgroup `cpu.stat`/`memory.events`, distributed trace и, когда безопасно, `perf`. `perf record`/`perf report` дают kernel+user view, но символы, права и overhead влияют на качество результата.

Полезный метод — differential profiling: собрать baseline и candidate при том же workload, затем сравнить изменившиеся hotspots, allocation sites и SLI. Но уменьшение функции в профиле не всегда выигрыш: перенос работы в другую функцию, падение throughput или рост ошибок создают ложную победу. Результат должен включать guardrails: correctness tests, CPU/memory budget и rollback condition.

## Ключевые понятия

| Понятие             | Суть                                   | Не путать с                     |
| ------------------- | -------------------------------------- | ------------------------------- |
| Baseline            | Воспроизводимое измерение до изменения | Личным ощущением «медленно»     |
| CPU profile         | Сэмплы исполнявшегося CPU кода         | Полным wall-clock путём запроса |
| Heap in-use         | Удерживаемая память в снимке           | Всеми аллокациями за период     |
| Allocation profile  | Места выделений за интервал            | Утечкой автоматически           |
| Block/mutex profile | Наблюдаемое ожидание блокировок/lock   | Причиной всех context switches  |
| Flame graph         | Визуализация стека и веса              | Доказательством причинности     |

## Типовые вопросы

1. **Почему top CPU function не всегда надо оптимизировать?**
   - Она может быть ожидаемой полезной работой, не связанной с нарушенным SLI, или уже эффективной. Нужны доля затрат, альтернатива, стоимость изменения и измеренный выигрыш end-to-end.
2. **Чем `alloc_space` отличается от `inuse_space`?**
   - `alloc_space` показывает общий поток выделений за период и помогает искать GC pressure; `inuse_space` показывает то, что удерживается в момент профиля, и полезен для retention.
3. **Когда брать mutex profile?**
   - Когда есть гипотеза о lock contention: рост waiting, ухудшение p99, много конкурирующих goroutine. Включить на ограниченный интервал и сопоставить с workload, а не постоянно без причины.
4. **Почему benchmark может врать?**
   - Компилятор способен исключить неиспользуемую работу; данные могут быть нереалистичны, cache тёплым, а concurrency иной. Результат надо потреблять, фиксировать вход и сверять с интеграционным SLI.
5. **Что делать, если pprof не показывает CPU hotspot, а p99 плохой?**
   - Проверить очереди, blocking, GC, scheduler, I/O, cgroup throttling и downstream traces. P99 может быть ожиданием, не CPU-вычислением.
6. **Как безопасно снять профиль в production?**
   - Ограничить доступ к endpoint, выбрать короткий согласованный интервал и реплику/канарейку, оценить overhead, не записывать секреты и заранее иметь план удаления артефакта.

## Практика

- [ ] **Постройте воспроизводимый baseline.** Для небольшого Go handler подготовьте benchmark и интеграционный load test, который формирует реалистичный payload.
  - Критерии готовности: указаны commit/binary, Go version, CPU quota, duration, warm-up, `-count=5`, p50/p95/p99, success RPS и error rate; benchmark возвращает результат работы, чтобы его не выкинул оптимизатор.
- [ ] **Проведите одну оптимизацию по профилю.** Соберите CPU и alloc profiles, выберите один подтверждённый allocation/hotspot, внесите минимальный change и повторите весь сценарий.
  - Критерии готовности: сохранены исходный и итоговый профили, объяснены `flat`/`cum` или `alloc_space`/`inuse_space`, тесты проходят, а выигрыш и отсутствие регрессии показаны числами.
- [ ] **Разберите не-CPU деградацию.** Добавьте искусственную задержку mutex либо downstream I/O и сравните CPU, block/mutex profile, `go tool trace` и HTTP histogram.
  - Критерии готовности: сделана корректная гипотеза о типе ожидания, CPU profile не объявлен причиной, есть trace/метрика очереди и предложен bounded fix с критерием rollback.

## Частые ошибки и ловушки

- Начинать с оптимизации до baseline и затем выбирать удобный график как доказательство.
- Путать cumulative время вызывающей функции с её собственным CPU.
- Искать memory leak по `alloc_space` или GC pressure только по `inuse_space`.
- Снимать profile под другой нагрузкой после изменения и сравнивать картинки.
- Включать тяжёлые профили/trace бесконечно в production или оставлять pprof публично доступным.
- Делать вывод о коде без проверки [[course/01-foundations/01-os/02-cpu-scheduling-context-switch|scheduler]], cgroup и зависимостей.

## Связанные темы

[[course/01-foundations/index|Модуль Foundations]] · [[course/02-go|Go]] · [[course/10-observability|Наблюдаемость]] · [[course/01-foundations/02-performance/05-allocation-rate-gc-pressure|Скорость аллокаций и GC]] · [[course/01-foundations/02-performance/04-false-sharing|Ложное разделение]] · [[course/01-foundations/02-performance/06-throughput-latency-tail-latency|Throughput и tail latency]]

## Источники

- Go documentation: `runtime/pprof`, `net/http/pprof`, `go test` flags и _Execution Tracer_.
- Go blog: _Profiling Go Programs_ и _Diagnostics_.
- Linux `perf` documentation: `perf-record(1)`, `perf-report(1)` и `perf-stat(1)`.
- Brendan Gregg, _Systems Performance_, главы о методах наблюдаемости и профилировании.
- Google SRE Book, _Monitoring Distributed Systems_.
