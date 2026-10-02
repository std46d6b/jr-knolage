---
title: "Code review: idiomatic Go и production-риски"
description: "Чек-лист ревью Go-кода: корректность, race, leaks, nil, ошибки, API и обоснованные абстракции."
tags:
  - go
  - code-review
  - concurrency
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Code review: idiomatic Go и production-риски

## Зачем это на интервью

В ревью проверяют приоритеты. Хороший кандидат сначала находит проблему корректности, безопасности, утечки или совместимости, объясняет последствия и предлагает конкретное исправление. Замечание о стиле полезно только после существенных рисков и не должно маскировать субъективный вкус.

## Минимум для E4

Проверяйте путь успеха и каждый failure path: ошибки не игнорируются, `context.Context` передан дальше, response body/rows/file закрыты, `nil` не приводит к panic, а shared state защищён. Запускайте `gofmt`, `go vet` и tests; для затронутой конкурентности — `-race`. Не утверждайте, что код «быстрее», без benchmark/profile.

```go
package fetch

import (
	"context"
	"fmt"
	"io"
	"net/http"
)

func ReadBody(ctx context.Context, client *http.Client, url string) ([]byte, error) {
	if client == nil {
		return nil, fmt.Errorf("read body: nil client")
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("do request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return nil, fmt.Errorf("unexpected HTTP status: %s", resp.Status)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}
	return body, nil
}
```

В ревью можно попросить лимит тела через `io.LimitReader`/`http.MaxBytesReader` в зависимости от boundary: `io.ReadAll` без лимита допускает resource exhaustion при недоверенном ответе. У `http.Client` должен быть timeout или transport-level timeouts, заданные владельцем клиента.

## Углубление для E5/Senior

Ревьюйте эксплуатационный контракт: retry безопасен ли для операции, наблюдаем ли отказ, ограничен ли ресурс, совместим ли JSON/schema, есть ли rollout/rollback для миграции. Для goroutine назовите owner, условие выхода и кто закрывает канал. Проверьте race не только в map: опасны shared pointer, захват переменной, повторное использование buffer и callback после shutdown.

Idiomatic Go означает ясность в местном контексте: небольшие функции, прямой control flow, zero value и узкие интерфейсы. Это не запрет на абстракции. Абстракция оправдана повторяющейся изменчивостью или границей эффекта, но не предполагаемым будущим.

## Ключевые понятия

| Проверка       | Вопрос ревьюера                                                              |
| -------------- | ---------------------------------------------------------------------------- |
| Correctness    | Что будет на пустом вводе, частичной ошибке, retry и повторном вызове?       |
| Error handling | Сохраняется ли причина и не раскрывается ли внутренность клиенту?            |
| Resources      | Кто и когда закрывает body, rows, file, channel и goroutine?                 |
| Concurrency    | Есть ли owner shared state, lock/atomic discipline и завершение workers?     |
| API            | Не ломает ли изменение экспорт, JSON, семантику timeout или старого клиента? |
| Simplicity     | Решает ли abstraction текущую вариативность дешевле прямого кода?            |

## Типовые вопросы

1. **В каком порядке оставлять комментарии в ревью?**
   - Сначала blocking: корректность, security, data loss, race/leak, API break; затем важные улучшения; стиль — последним и не блокирует без правила команды.
2. **Почему `go test -race` не доказывает отсутствие всех concurrency bugs?**
   - Он видит только выполненные пути и data races; deadlock, starvation и неисполненные ветви требуют дизайна, тестов и диагностики.
3. **Как распознать goroutine leak?**
   - У goroutine нет гарантированного пути выхода: она ждёт канал/IO без отмены, а owner не закрывает/не отменяет ресурс.
4. **Когда `defer resp.Body.Close()` недостаточен?**
   - Когда тело не ограничено, не дочитывается для connection reuse в нужном сценарии или `Close`-ошибка значима для записи.
5. **Что такое преждевременная абстракция?**
   - Общий слой создан до подтверждённой вариативности и усложняет чтение, тесты и изменение без реального текущего выигрыша.

## Практика

- [ ] Проведите ревью примера: добавьте лимит чтения, тест не-2xx ответа и timeout клиента.
- [ ] Найдите в учебном проекте goroutine без owner/stop path и добавьте `context` plus `WaitGroup`.
- [ ] Разметьте десять замечаний как blocking, important или nit и напишите одно предложение с риском для каждого blocking.

**Критерии готовности:** комментарии воспроизводимы и привязаны к строке/сценарию; blocking-замечания имеют последствия и проверяемое исправление; код форматирован и проверен `go vet ./...`, `go test ./...`, а конкурентный код — `go test -race ./...`.

## Частые ошибки и ловушки

- Обсуждать имена, пропустив ignored error, SSRF, race или утечку ресурса.
- Закрывать channel со стороны получателя или из нескольких producers.
- Создавать goroutine в цикле без cancellation и ожидания завершения.
- Добавлять mutex «на всякий случай» без единого ownership-протокола или удерживать lock во время внешнего I/O.
- Требовать паттерн из другого проекта вместо объяснения конкретного trade-off.

## Связанные темы

[[course/02-go/08-interview-code|Go-код на интервью]] · [[course/02-go/08-interview-code/01-code-reading-refactoring|Рефакторинг]] · [[course/02-go/08-interview-code/04-package-api-design|API пакета]] · [[course/12-testing|Тестирование]]

## Источники

- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments) — проверено 2026-10-02.
- [Data Race Detector](https://go.dev/doc/articles/race_detector) — проверено 2026-10-02.
- [Package net/http](https://pkg.go.dev/net/http) — проверено 2026-10-02.
- [Effective Go: Concurrency](https://go.dev/doc/effective_go#concurrency) — проверено 2026-10-02.
