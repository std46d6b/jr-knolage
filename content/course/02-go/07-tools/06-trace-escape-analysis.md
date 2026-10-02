---
title: go tool trace и escape analysis
description: Временная диагностика runtime и чтение решений компилятора об escape в Go.
tags: [go, trace, compiler, memory, performance, interview]
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# go tool trace и escape analysis

Trace показывает временную историю событий runtime: goroutine, scheduler, GC, syscalls и blocking. Escape analysis — решение компилятора о том, может ли значение жить на stack, или ему нужна heap-аллокация; это реализация, а не API-контракт.

## Зачем это на интервью

Нужно уметь выбрать trace при вопросе «почему работа ждёт», а не пытаться найти эту причину только CPU profile, и не оптимизировать escapes по выводу компилятора без измерения.

## Минимум для E4

- [ ] Записывать trace: `go test ./... -run '^$' -trace=trace.out` или `runtime/trace` в контролируемом сценарии.
- [ ] Открывать `go tool trace trace.out` и искать периоды runnable/running/blocked, GC и syscalls.
- [ ] Запускать `go test -gcflags='-m=2' ./pkg/...` для объяснений escape.
- [ ] Подтверждать performance-вывод benchmark/pprof, а не только `-m`.

```bash
go test ./internal/queue -run '^TestBurst$' -trace=trace.out
go tool trace trace.out
go test -gcflags='-m=2' ./internal/codec
```

## Углубление для E5/Senior

Trace полезен для scheduler latency, плохого `GOMAXPROCS`, долгого GC, network/syscall blocking и неравномерности goroutine. Он даёт временные связи, но артефакт может быть крупным и добавлять overhead; production-сбор согласуют, ограничивают длительностью и защищают так же, как profile. В trace сопоставляют задержку с workload, метриками и downstream-зависимостями.

Escape случается, если компилятор не может доказать безопасную stack-границу: например, адрес переживает вызов, значение помещается в interface или замыкание, размер слишком велик. Это не означает «любой pointer = heap», и конкретное решение меняется между Go releases. `-m=2` даёт причины, а `-gcflags` следует применять к нужному пакету, избегая шума всего dependency graph. Изменение API ради одной аллокации оправдано только после профиля и оценки читаемости/безопасности.

## Ключевые понятия

| Инструмент | Сигнал                               | Не заменяет                     |
| ---------- | ------------------------------------ | ------------------------------- |
| trace      | timeline runtime и goroutine         | агрегированный CPU/heap профиль |
| `-m=2`     | объяснения inline/escape компилятора | измерение allocations           |
| benchmark  | стоимость фиксированной операции     | сервисный load test             |

## Типовые вопросы

1. **Когда trace лучше pprof?** — При scheduler/blocking/GC timeline; pprof лучше агрегированно ранжирует CPU или allocations.
2. **Escape всегда плохо?** — Нет, heap необходим для корректности и часто не является bottleneck.
3. **Pointer всегда escape?** — Нет, компилятор анализирует lifetime и может оставить объект на stack.
4. **Почему вывод `-m` меняется?** — Escape/inlining — детали оптимизатора, зависящие от версии и контекста сборки.
5. **Можно ли снять trace в production?** — Только контролируемо: короткий интервал, доступ, overhead и политика хранения должны быть определены.

## Практика

- [ ] Воспроизведите goroutine blocking и снимите trace. **Готово:** указаны состояние, временной интервал, причина и подтверждающая метрика.
- [ ] Найдите allocation через `-m=2` и pprof. **Готово:** показано, совпадает ли компиляторная гипотеза с `alloc_space`; изменение измерено benchmark.

## Частые ошибки и ловушки

- Делать вывод о p99 по одной дорожке trace без workload и метрик.
- Считать escape bug или обязателным поводом переписать API.
- Снимать долгий trace в production и хранить его без контроля доступа.

## Связанные темы

[[course/02-go/07-tools|Инструменты Go]] · [[course/02-go/07-tools/05-pprof|pprof]] · [[course/01-foundations/02-performance|Производительность и память]]

## Источники

- [runtime/trace](https://pkg.go.dev/runtime/trace)
- [go tool trace](https://pkg.go.dev/cmd/trace)
- [Go compiler options](https://pkg.go.dev/cmd/compile)
- [Go diagnostics](https://go.dev/doc/diagnostics)
