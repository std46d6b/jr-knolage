---
title: Throughput, latency и tail latency
description: Как измерять скорость, время ответа и хвосты распределения, не подменяя пользовательский опыт средним значением.
tags:
  - performance
  - latency
  - throughput
  - sre
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Throughput, latency и tail latency

**Throughput** — объём завершённой полезной работы за время: например, requests/s при явно заданном успехе. **Latency** — время одного запроса от выбранного начала до конца. Они связаны с конкурентностью и очередями, но не являются взаимозаменяемыми метриками. **Tail latency** — высокие квантили распределения, такие как p95/p99/p99.9; именно там часто живёт опыт части пользователей и риск превышения SLO.

## Зачем это на интервью

Вопрос проверяет, способны ли вы установить измеримую цель вместо «сделаем быстро». В сервисе можно поднять средний RPS, создавая очередь и ухудшая p99, или улучшить server latency, не заметив client-side retry и error rate. На уровне E4 нужно выбрать корректные границы измерения и объяснить p99; на E5 — учитывать очереди, fan-out, saturation, load generation и SLO/error budget.

## Минимум для E4

- [ ] Ясно определять единицу полезной работы, success/error policy, начало и конец замера.
- [ ] Различать среднее, median и percentile; p99 — значение, ниже которого находится примерно 99% наблюдений в выбранном окне и способе агрегации.
- [ ] Понимать, что рост concurrency после насыщения обычно растит queueing delay и tail latency.
- [ ] Отдельно собирать rate, errors, duration и saturation; низкая средняя latency не доказывает здоровье сервиса.
- [ ] Не усреднять percentiles разных инстансов: для fleet percentile нужны histogram/сырые распределения с согласованными buckets.

## Углубление для E5/Senior

### Очередь — источник нелинейности

В простой стабильной системе Little’s Law связывает среднее число объектов в системе $L$, arrival rate $\lambda$ и среднее время в системе $W$:

$$
L = \lambda W
$$

Это не формула для расчёта p99 и не лицензия игнорировать условия: система должна быть стабильна, единицы измерения согласованы, а $L$ включает ожидающих и обслуживаемых. Однако она полезна как sanity check: если одновременно растут in-flight requests и latency при близком к пределу throughput, вероятна очередь. При utilisation, близкой к 100%, небольшая вариация service time вызывает непропорциональный рост ожидания.

Backpressure ограничивает admission или concurrency до того, как очередь съест память и deadline. Возможные механизмы: bounded queue, semaphore, connection pool, rate limit, load shedding и timeout. Каждый имеет контракт: что отклоняется, кто повторяет, есть ли приоритеты, как клиент отличает временную перегрузку от ошибки. Бесконечная очередь не повышает capacity — она переносит отказ во времени и делает его менее предсказуемым.

### Хвосты, fan-out и coordinated omission

Если запрос ждёт несколько зависимостей, вероятность хотя бы одной медленной ветви растёт. Поэтому end-to-end p99 нельзя вывести из среднего dependency latency; нужны трассировки, per-dependency histogram и budget на каждый hop. Retries способны улучшить успех отдельных запросов, но под saturation увеличивают нагрузку и хвост; retry budget, jitter и deadline должны быть общими для цепочки.

Нагрузочный генератор, который отправляет следующий запрос только после ответа, пропускает интервалы, в которых реальный клиент продолжал бы приходить. Это **coordinated omission**: замер занижает хвосты в период паузы. Для open-loop/arrival-rate сценария фиксируйте целевой arrival process, concurrency, timeout, payload, warm-up и backpressure. Не публикуйте p99 с малым числом запросов: для редких квантилей нужна достаточная выборка и окно.

### Метрики и SLO

Для latency полезны histogram buckets, совместимые между сервисами, и exemplars/trace IDs для редких хвостов. Summary с локальными quantiles нельзя безопасно агрегировать между instance. SLO должен говорить о конкретном индикаторе: например, доля успешных `POST /checkout`, завершённых сервером за 300 ms, за 30 дней. Ошибки, отмены по deadline и деградация могут быть отдельными или объединёнными событиями — это фиксируют явно, иначе команда «улучшит» разные числа.

Throughput измеряйте как completed work, а не только accepted requests. При перегрузке accepted RPS может выглядеть высоким, когда success RPS падает. Сравнивайте также CPU, run queue, throttling, pool saturation, queue depth и downstream limits: [[course/01-foundations/01-os/02-cpu-scheduling-context-switch|планирование CPU]] объясняет лишь одну из возможных очередей.

## Ключевые понятия

| Понятие        | Суть                                                   | Не путать с                           |
| -------------- | ------------------------------------------------------ | ------------------------------------- |
| Throughput     | Завершённая полезная работа за секунду                 | Числом открытых соединений            |
| Service time   | Время фактической обработки                            | Полным временем с ожиданием в очереди |
| Queueing delay | Ожидание до обслуживания                               | Работой CPU/БД над запросом           |
| p99            | Высокий квантиль распределения в заданном окне         | Средним 99% запросов                  |
| Saturation     | Использование ограничивающего ресурса или рост очереди | Просто высоким RPS                    |
| Backpressure   | Управляемое ограничение потока работы                  | Бесконечной буферизацией              |

## Типовые вопросы

1. **Можно ли усреднить p99 двух pod?**
   - Нет. Percentile не аддитивен. Нужны объединяемые histogram buckets или сырые наблюдения; среднее из p99 может скрыть перегруженный pod.
2. **Почему средняя latency нормальна, а пользователи жалуются?**
   - Распределение может иметь длинный хвост: большинство быстры, часть ждёт очередь, GC, lock, I/O или медленную зависимость. Смотреть p95/p99, errors и trace хвостовых запросов.
3. **Как увеличить throughput без ухудшения p99?**
   - Найти bottleneck, уменьшить service time или добавить capacity, ограничить concurrency на ресурсе и проверить нагрузочным тестом. Большее число workers после saturation обычно не подходит.
4. **Почему timeout не лечит перегрузку сам по себе?**
   - Timeout останавливает ожидание клиента, но работа может продолжаться, а retries добавят нагрузку. Нужны cancellation, bounded queues и политика admission.
5. **Что такое coordinated omission?**
   - Когда генератор прекращает посылать запросы во время медленного ответа, он не измеряет ожидавшие в этот период запросы и занижает tail latency.
6. **Почему fan-out делает p99 опаснее?**
   - Ответ ждёт максимум нескольких независимых задержек; шанс встретить хотя бы одну хвостовую ветвь растёт с числом зависимостей.

## Практика

- [ ] **Нарисуйте границы SLI.** Для HTTP-метода выберите start/end, success policy, label cardinality и buckets histogram.
  - Критерии готовности: есть одна фраза SLI, пример metric name/labels, исключены user ID и URL с параметрами, определено обращение с cancelled/error запросами.
- [ ] **Найдите knee point.** Нагрузите сервис фиксированными payload и timeout, последовательно повышая arrival rate до отказа.
  - Критерии готовности: для каждого шага записаны success throughput, error rate, p50/p95/p99, in-flight/queue depth и saturation; warm-up и длительность шага указаны, а предел назван по данным.
- [ ] **Добавьте backpressure.** В учебный handler добавьте bounded semaphore и понятный ответ при исчерпании; сравните с неограниченной очередью.
  - Критерии готовности: есть тест на отмену контекста, метрика rejected requests, измерение p99 и памяти под overload, а политика retry/documentation не обещает бесконечные повторы.

## Частые ошибки и ловушки

- Называть среднее latency «скоростью сервиса» и не публиковать распределение.
- Складывать или усреднять p99 инстансов вместо агрегации histograms.
- Менять одновременно payload, connection reuse, rate и concurrency в benchmark, теряя причинность.
- Мерить только closed-loop нагрузку и делать вывод об отсутствии хвостов.
- Поднимать лимиты очередей, не проверив memory, deadline и downstream saturation.
- Забывать, что allocation/GC и [[course/01-foundations/02-performance/04-false-sharing|cache coherence]] — лишь некоторые источники очередей.

## Связанные темы

[[course/01-foundations/index|Модуль Foundations]] · [[course/10-observability|Наблюдаемость]] · [[course/01-foundations/01-os/02-cpu-scheduling-context-switch|Планирование CPU]] · [[course/01-foundations/02-performance/05-allocation-rate-gc-pressure|Скорость аллокаций и GC]] · [[course/01-foundations/02-performance/07-performance-profiling|Профилирование производительности]] · [[course/08-system-design|System Design]]

## Источники

- Google SRE Book, главы _Service Level Objectives_ и _Addressing Cascading Failures_.
- Google Cloud, _The Tail at Scale_ (Jeff Dean, Luiz André Barroso).
- Marc Brooker, _The Tail at Scale_ и материалы о очередях и backpressure.
- Prometheus documentation: _Histograms and summaries_.
- John D. C. Little, _A Proof for the Queuing Formula: L = λW_.
