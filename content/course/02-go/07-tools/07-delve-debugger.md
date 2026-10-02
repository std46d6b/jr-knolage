---
title: "Delve: отладчик Go"
description: Практичная отладка Go-программ в Delve с breakpoints, goroutines и безопасной диагностикой.
tags: [go, debugging, delve, interview]
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Delve: отладчик Go

Delve (`dlv`) — source-level debugger для Go. Он запускает или присоединяется к процессу, останавливает выполнение в breakpoint и показывает goroutines, stack frames, переменные и выражения. Отладчик отвечает на вопрос о конкретном воспроизведении; для статистических production-проблем чаще подходят метрики, profile и trace.

## Зачем это на интервью

Полезно объяснить, как локализовать неверное состояние, не менять код случайными print-логами и не использовать attach к production-процессу как обычный первый шаг.

## Минимум для E4

- [ ] Установить совместимую версию: `go install github.com/go-delve/delve/cmd/dlv@latest`.
- [ ] Запустить программу `dlv debug ./cmd/api -- -config test.yaml`.
- [ ] Поставить `break main.main`, выполнить `continue`, посмотреть `goroutines`, `stack`, `locals`, `print expr`.
- [ ] Отладить тест `dlv test ./internal/auth -- -test.run '^TestLogin$'`.

```text
(dlv) break service.go:42
(dlv) continue
(dlv) locals
(dlv) print req.UserID
(dlv) goroutines
(dlv) goroutine 12
(dlv) stack
(dlv) next
(dlv) step
(dlv) restart
```

## Углубление для E5/Senior

Сборка с оптимизациями и inlining может делать переменные «недоступными» или искажать удобство stepping. Для локальной диагностики используют `-gcflags=all='-N -l'`, понимая, что бинарник меняет timing и производительность; итог исправления обязано пройти обычную оптимизированную сборку и тесты. Conditional breakpoint (`break file:line if condition`) уменьшает шум, а `on breakpoint command` автоматизирует безопасную печать контекста.

`dlv attach PID` останавливает/влияет на работающий процесс и часто требует ptrace permissions. В production это исключение: нужны согласование владельца, изолированная реплика, минимальный интервал, контроль доступа и rollback. Remote debugging (`dlv --listen=... --headless`) никогда не открывают на публичном интерфейсе без защищённого канала; debugger способен читать память и выполнять выражения. Для deadlock исследуют все `goroutines` и stacks, а не только текущий breakpoint.

## Ключевые понятия

| Команда               | Назначение                              |
| --------------------- | --------------------------------------- |
| `dlv debug`           | собрать и начать debug пакета main      |
| `dlv test`            | запустить тестовый binary под debugger  |
| `break`               | поставить breakpoint, возможно условный |
| `next` / `step`       | перейти через строку / войти в вызов    |
| `goroutines`, `stack` | исследовать конкурентное состояние      |
| `attach`              | подключиться к существующему процессу   |

## Типовые вопросы

1. **`next` и `step`?** — `next` проходит вызов как одну операцию, `step` входит в вызываемую функцию.
2. **Почему debugger не видит переменную?** — Её мог оптимизировать или встроить compiler; локально помогает `-N -l`, но это не production-поведение.
3. **Как отладить один тест?** — `dlv test <package> -- -test.run '^TestName$'` передаёт тестовый флаг binary.
4. **Можно ли attach к production?** — Технически иногда да, но это остановка/доступ к памяти и operational-risk; сначала применяют менее инвазивные сигналы.
5. **Как искать deadlock?** — Снять stacks всех goroutine, найти ожидаемые locks/channels и сопоставить ownership; не полагаться на одну текущую goroutine.

## Практика

- [ ] Отладьте failing unit test без изменения production-кода. **Готово:** есть breakpoint, inspected variable, причина и обычный `go test` после фикса.
- [ ] Исследуйте учебный deadlock двух goroutine. **Готово:** сохранены stacks обоих участников, описан цикл ожидания и исправление проходит `go test -race`.
- [ ] Сравните debug и release сборку. **Готово:** объяснено влияние `-N -l`, а результат подтверждён без этих флагов.

## Частые ошибки и ловушки

- Принимать поведение неoptimised debug-binary за доказательство production timing.
- Открывать headless Delve наружу или сохранять memory dumps без политики доступа.
- Использовать `attach` первым средством при инциденте вместо метрик, logs, pprof и trace.
- Лечить deadlock `Sleep`, не устанавливая порядок владения и отмену.

## Связанные темы

[[course/02-go/07-tools|Инструменты Go]] · [[course/02-go/07-tools/03-go-test-race-count-run|go test и race detector]] · [[course/02-go/07-tools/05-pprof|pprof]] · [[course/02-go/07-tools/06-trace-escape-analysis|Trace и escape analysis]]

## Источники

- [Delve documentation](https://github.com/go-delve/delve/tree/master/Documentation)
- [Delve command reference](https://github.com/go-delve/delve/blob/master/Documentation/cli/README.md)
- [Go debugging guide](https://go.dev/doc/diagnostics)
