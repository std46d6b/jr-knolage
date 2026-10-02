---
title: Pipelines и cancellation в Go
description: Построение отменяемых конвейеров без утечек goroutine, зависших send и потерянных причин ошибок.
tags:
  - go
  - concurrency
  - context
  - pipeline
status: complete
difficulty: e5
created: 2026-10-02
updated: 2026-10-02
aliases:
  - Отмена pipeline в Go
draft: false
---

# Pipelines и cancellation в Go

## Зачем это на интервью

Pipeline показывает, умеете ли вы связывать стадии обработки без утечек. Интервьюер почти наверняка спросит: что будет, если downstream прочитал один результат и вернулся, кто закрывает каждый канал и как отмена попадает в блокирующий send.

## Минимум для E4

Pipeline — последовательность stages, где каждая читает входной канал и публикует выходной. У stage должен быть явный контракт: кто владеет и закрывает output, как завершается input, что происходит при ошибке и `ctx.Done()`.

`context.Context` передают первым параметром и не хранят внутри struct. Его не используют для optional-параметров. Отмена кооперативна: она не убивает goroutine. Код обязан проверять `ctx.Done()` перед потенциально долгой работой и в каждой операции send/receive, которая может ждать.

```go
package pipeline

import "context"

func Generate(ctx context.Context, values ...int) <-chan int {
	out := make(chan int)
	go func() {
		defer close(out)
		for _, value := range values {
			select {
			case out <- value:
			case <-ctx.Done():
				return
			}
		}
	}()
	return out
}

func Square(ctx context.Context, in <-chan int) <-chan int {
	out := make(chan int)
	go func() {
		defer close(out)
		for {
			select {
			case value, ok := <-in:
				if !ok {
					return
				}
				select {
				case out <- value * value:
				case <-ctx.Done():
					return
				}
			case <-ctx.Done():
				return
			}
		}
	}()
	return out
}
```

Владелец `cancel` вызывает его ровно когда результат больше не нужен или запрос завершён; обычно `defer cancel()` сразу после `context.WithCancel/WithTimeout`. Стадии закрывают только созданный ими `out`.

## Углубление для E5/Senior

Cancellation — часть resource budget. Верхний HTTP deadline нужно распространять вниз, а не ставить каждому вызову новый независимый timeout, способный пережить родительский запрос. Оставляйте запас на сериализацию, fallback и возврат ответа. `context.WithCancelCause` позволяет передать причину завершения внутренним участникам; наружу ошибку всё равно маппят по контракту API.

Для fan-in нужна отмена на **каждом** input и выходе. Если один stage возвращает ошибку, coordinator отменяет общий context, закрывает лишь собственные каналы и ждёт всех запущенных goroutine. Используйте `errgroup.WithContext` для request-scoped работ: `Wait` даёт ошибку, context прекращает siblings. Не выпускайте goroutine, которой некуда сообщить результат.

Отделяйте graceful draining от cancellation. При нормальном shutdown может быть допустимо прекратить приём новых задач, но дочитать bounded очередь до deadline; при отмене клиентского запроса часто правильнее немедленно остановить работу. Политика должна быть выражена отдельно, а не выведена из случайного закрытия канала.

## Ключевые понятия

| Событие              | Правильная реакция                                       |
| -------------------- | -------------------------------------------------------- |
| Input закрыт         | дочитать уже полученное, закрыть свой output и вернуться |
| Context отменён      | прекратить блокирующие send/receive, освободить ресурсы  |
| Consumer ушёл раньше | coordinator отменяет context или producer иначе утечёт   |
| Ошибка stage         | сообщить координатору, отменить siblings, дождаться их   |
| Normal EOF           | не равен ошибке и не требует отмены                      |

## Типовые вопросы

1. **Почему одного `<-ctx.Done()` в начале goroutine недостаточно?**
   - Goroutine может застрять позднее на receive, send или I/O. Отменяемой должна быть каждая потенциально блокирующая точка.
2. **Кто закрывает канал pipeline?**
   - Stage, который его создал и является единственным sender-ом/координатором sender-ов. Receiver не закрывает input.
3. **Что такое goroutine leak в pipeline?**
   - Goroutine остаётся ждать операцию, которую никто не завершит: например producer посылает в канал после раннего возврата consumer-а.
4. **Можно ли передать `nil` context?**
   - Нет. Для отсутствия специального контекста передают `context.Background()` или `context.TODO()` в соответствии с назначением.
5. **Отменяет ли `context` сетевой вызов сам?**
   - Только API, принимающее context и реализующее реакцию, например `http.NewRequestWithContext` или `database/sql` methods с `Context`. Ваш произвольный код должен реагировать сам.
6. **Чем close канала отличается от cancel context?**
   - Close сообщает конец конкретного потока данных; cancel — широкое сигнализирование lifecycle. Не стоит закрывать shared done channel из нескольких мест.

## Практика

- [ ] Соедините `Generate → Square → Sum`. Критерии: при чтении первых трёх значений и `cancel()` все goroutine завершаются, output закрывается один раз, тест проходит с `-race`.
- [ ] Добавьте stage с ошибкой. Критерии: первая ошибка возвращается вызывающему, соседние stages прекращаются, нет зависания при полном output buffer.
- [ ] Проверьте утечку. Критерии: test создаёт и отменяет pipeline 100 раз, после завершения goroutine count возвращается к разумному baseline с допустимой дельтой.
- [ ] Нарисуйте timeout budget endpoint → service → DB/RPC. Критерии: дочерние deadline не длиннее родительского и оставлен budget на ответ.

## Частые ошибки и ловушки

- Создавать context через `context.Background()` внутри глубокой функции и тем самым терять отмену родителя.
- Передавать context в struct «на потом» или использовать `context.Value` вместо явного параметра.
- Закрывать `ctx.Done()`: он принадлежит context и только читается.
- Закрывать input channel на стороне consumer-а.
- Считать `time.After` в горячем цикле без управления таймером; это создаёт лишние таймеры и усложняет остановку.

## Связанные темы

[[course/02-go|Go]] · [[course/02-go/03-concurrency/07-fanout-fanin-worker-pool|Fan-out, fan-in и worker pool]] · [[course/02-go/03-concurrency/10-graceful-shutdown|Graceful shutdown]] · [[course/02-go/03-concurrency/06-race-deadlock-livelock-starvation|Race и deadlock]]

## Источники

- [context package](https://pkg.go.dev/context)
- [Go blog: Pipelines and cancellation](https://go.dev/blog/pipelines)
- [Go blog: Context](https://go.dev/blog/context)
- [Go Concurrency Patterns: Context](https://go.dev/blog/context-and-structs)
