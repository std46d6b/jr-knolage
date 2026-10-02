---
title: "pprof: CPU, heap, goroutine, mutex и block profiles"
description: Выбор, сбор и интерпретация Go pprof-профилей без ложных выводов.
tags: [go, pprof, profiling, performance, interview]
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# pprof: CPU, heap, goroutine, mutex и block profiles

`pprof` собирает агрегированные профили runtime. Начинать нужно с симптома и воспроизводимой нагрузки: CPU profile отвечает «где исполнялся CPU-код», heap — «что удержано», alloc — «где выделяли», mutex/block — «где наблюдалось ожидание».

## Зачем это на интервью

Сильный ответ различает типы профиля, `flat` и `cum`, не называет верхнюю строку автоматически причиной p99 и повторяет измерение после исправления.

## Минимум для E4

- [ ] Снимать CPU и memory profiles тестом или `net/http/pprof`.
- [ ] Открывать `go tool pprof -http=:0 profile` и читать `top`, `list`, flame graph.
- [ ] Отличать `inuse_space` от `alloc_space`.
- [ ] Ограничивать pprof endpoint сетью и аутентификацией.

```bash
go test ./... -run '^$' -bench '^BenchmarkParse$' -cpuprofile=cpu.out -memprofile=mem.out
go tool pprof -http=:0 cpu.out
go tool pprof -sample_index=alloc_space mem.out
curl -o cpu.pb.gz 'http://127.0.0.1:6060/debug/pprof/profile?seconds=20'
go tool pprof cpu.pb.gz
```

## Углубление для E5/Senior

Импорт blank `net/http/pprof` регистрирует handlers на DefaultServeMux; не подключайте его к публичному mux случайно. CPU profile sampling-овый и не показывает время ожидания I/O. Heap profile по умолчанию фокусируется на in-use; `-sample_index=alloc_space` помогает искать allocation rate и GC pressure. Goroutine profile — снимок стеков текущих goroutine; рост сам по себе требует сравнения и классификации состояний.

Mutex и block profiles имеют sampling/overhead-настройки (`runtime.SetMutexProfileFraction`, `runtime.SetBlockProfileRate`) и включаются осознанно на короткий период. При lock contention изучают владельца lock, длительность critical section и архитектуру данных, а не просто меняют `Mutex` на `RWMutex`. Всегда сравнивают одинаковый workload и сопровождают оптимизацию correctness tests и сервисными SLI.

## Ключевые понятия

| Профиль     | Вопрос                                       |
| ----------- | -------------------------------------------- |
| CPU         | где процесс исполнял инструкции              |
| heap/inuse  | что удерживалось в момент снимка             |
| alloc       | где выделено больше всего за период          |
| goroutine   | какие стеки и goroutine существуют           |
| mutex/block | где наблюдалось ожидание locks/синхронизации |

## Типовые вопросы

1. **Что такое flat и cum?** — Flat относится к самой функции, cumulative включает вызовы ниже в стеке.
2. **`alloc_space` — это leak?** — Нет: это поток аллокаций; leak ищут по удержанию (`inuse`) и тренду после нагрузки.
3. **Почему CPU profile не объясняет p99?** — Хвост может быть I/O, очередью, GC или lock waiting, где CPU не занят.
4. **Когда нужен goroutine profile?** — При подозрении на leak, зависшие workers или неожиданный рост concurrency; стеки сравнивают во времени.
5. **Безопасен ли `/debug/pprof/`?** — Нет по умолчанию: доступ ограничивают, профиль берут кратко и удаляют артефакт по политике.

## Практика

- [ ] Создайте CPU-hotspot и allocation-hotspot. **Готово:** собраны profile files, выбран верный sample index и различены результаты.
- [ ] Добавьте lock contention. **Готово:** mutex/block profile сопоставлен с workload, исправление подтверждено повтором и тестом.

## Частые ошибки и ловушки

- Сравнивать profiles с разным traffic или duration.
- Объявлять любую аллокацию утечкой.
- Оставлять pprof публичным или тяжёлое профилирование включённым постоянно.

## Связанные темы

[[course/02-go/07-tools|Инструменты Go]] · [[course/02-go/07-tools/04-benchmarks-benchmem|Бенчмарки]] · [[course/02-go/07-tools/06-trace-escape-analysis|Trace и escape analysis]]

## Источники

- [runtime/pprof](https://pkg.go.dev/runtime/pprof)
- [net/http/pprof](https://pkg.go.dev/net/http/pprof)
- [Profiling Go Programs](https://go.dev/blog/pprof)
- [Go diagnostics](https://go.dev/doc/diagnostics)
