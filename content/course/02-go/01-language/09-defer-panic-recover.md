---
title: defer, panic и recover в Go
description: Детерминированная очистка ресурсов, раскрутка стека и узкие допустимые границы восстановления после panic.
tags:
  - go
  - language
  - defer
  - panic
  - recover
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
aliases:
  - Отложенные вызовы и panic
  - Recover в Go
draft: false
---

# defer, panic и recover в Go

## Зачем это на интервью

`defer` упрощает освобождение ресурсов, но порядок исполнения, момент вычисления аргументов и взаимодействие с named results регулярно становятся причиной багов. `panic` и `recover` показывают инженерную зрелость: в прикладном сервисе ожидаемые сбои возвращаются как `error`, а recovery допустим лишь на контролируемой границе, где процесс может продолжить работу безопасно.

## Минимум для E4

- [ ] Знать, что deferred calls исполняются LIFO при обычном `return` и при panic.
- [ ] Понимать, что receiver и аргументы defer вычисляются в момент объявления `defer`.
- [ ] Применять `defer` сразу после успешного захвата ресурса.
- [ ] Возвращать `error` для ожидаемых отказов, не использовать panic для validation или I/O.

`defer` обычно размещают после проверки ошибки от `Open`, `Lock` или `Begin`. Он привязывает cleanup к lexical scope, а не к числу ветвей return.

```go
package main

import (
    "fmt"
    "os"
)

func firstByte(name string) (byte, error) {
    file, err := os.Open(name)
    if err != nil {
        return 0, err
    }
    defer file.Close() // error Close здесь намеренно не теряется в write path

    var buf [1]byte
    _, err = file.Read(buf[:])
    return buf[0], err
}

func main() {
    _, _ = firstByte("input.txt")
    fmt.Println("finished")
}
```

Аргументы capture-ятся сразу, а closure читает внешнюю переменную при выполнении. Это различие важно при логировании и loop-переменных.

```go
package main

import "fmt"

func main() {
    n := 1
    defer fmt.Println("argument:", n)
    defer func() { fmt.Println("closure:", n) }()
    n = 2
}
```

## Углубление для E5/Senior

`recover` работает только при вызове непосредственно из deferred function в той же goroutine. Panic в worker goroutine не может быть восстановлена defer-ом управляющей goroutine; worker должен сам иметь защитную оболочку, если политика сервиса это допускает. Даже успешный `recover` не отменяет уже выполненные side effects и не возвращает систему к консистентному состоянию.

HTTP middleware может восстановить panic на границе одного request, записать structured log и вернуть 500, но не должен скрывать причину. Нужны stack trace, request ID и метрика. В background processing стратегия зависит от семантики: иногда правильнее завершить процесс и дать supervisor перезапустить его, чем продолжать с потенциально повреждённым состоянием.

В цикле `defer` выполняется лишь при выходе из окружающей функции. Если на каждой итерации открывается ресурс, вынесите тело в helper function или закройте ресурс явно; иначе file descriptors и память удерживаются до конца цикла. Цена `defer` в современном Go часто невелика, но hot loop измеряют; не жертвуйте корректностью без профиля.

Особый случай — ошибка `Close`, `Commit` или `Flush`: на read path её иногда можно залогировать, но на write path она может означать потерю данных. Используйте named result или явный cleanup, чтобы не затереть основную ошибку.

```go
package main

import (
    "errors"
    "fmt"
)

type tx interface {
    Commit() error
    Rollback() error
}

func save(t tx, fail bool) (err error) {
    defer func() {
        if err != nil {
            _ = t.Rollback()
            return
        }
        err = t.Commit()
    }()
    if fail {
        return errors.New("validation failed")
    }
    return nil
}

func main() {
    fmt.Println("transaction pattern")
}
```

В этом шаблоне контракт `Commit` важен: commit error возвращается вызывающему, а rollback после failed commit обычно не обещает отменить неизвестный итог транзакции. Конкретный драйвер и БД определяют дальнейшую диагностику.

## Ключевые понятия

| Понятие         | Смысл                                       | Практическое правило                 |
| --------------- | ------------------------------------------- | ------------------------------------ |
| `defer`         | Отложенный вызов до выхода из функции       | Ставить после успешного acquire      |
| LIFO            | Последний defer выполняется первым          | Учитывать порядок unlock/close       |
| Stack unwinding | Выполнение defer при распространении panic  | Cleanup всё равно запускается        |
| `panic`         | Нештатное прекращение normal flow goroutine | Не заменяет ожидаемый `error`        |
| `recover`       | Перехват panic внутри deferred function     | Только локальная goroutine и граница |

`runtime.Goexit` завершает goroutine после выполнения defers, но не является panic: `recover` вернёт `nil`. `os.Exit` завершает процесс немедленно и не выполняет deferred calls — не используйте его глубоко в библиотечном коде.

## Типовые вопросы

1. **В каком порядке выполняются несколько defer?**
   - В обратном порядке объявления, как стек.
2. **Когда вычисляются аргументы `defer f(x)`?**
   - Сразу при выполнении `defer`, до последующих изменений `x`.
3. **Можно ли recover panic дочерней goroutine в main?**
   - Нет; recover действует только в deferred function той же goroutine.
4. **Когда panic оправдан?**
   - При нарушенном внутреннем инварианте, невозможной инициализации программы или в API, чей контракт явно допускает panic; не для обычной ошибки пользователя.
5. **Почему опасен `defer rows.Close()` в бесконечном loop?**
   - Закрытие отложится до выхода функции, и ресурсы будут накапливаться.
6. **Как вернуть ошибку `Close`?**
   - На важном write path используйте named result/явный close и объедините или приоритизируйте ошибки по контракту.

## Практика

- [ ] Напишите функцию копирования в файл с корректной обработкой ошибок `Create`, `Copy` и `Close`.
  - **Критерии готовности:** файл закрывается на всех return paths; ошибка записи не теряется ошибкой close; тест применяет writer, который падает на `Close`.
- [ ] Создайте worker pool, где один worker panic-ует.
  - **Критерии готовности:** объяснена выбранная политика; если recovery нужен, он расположен внутри worker goroutine, логирует stack и не подтверждает невыполненную работу.
- [ ] Исправьте loop с `defer file.Close()` на каждой итерации.
  - **Критерии готовности:** максимальное число открытых файлов ограничено; тест проверяет cleanup; причина lifetime показана в комментарии или review.

## Частые ошибки и ловушки

- Вызывать `recover` вне deferred function и ожидать перехват panic.
- Маскировать все panic middleware-ом без log, stack trace и метрики.
- Использовать `panic` как обычную обработку некорректного ввода.
- Не проверять ошибку `Close` после записи критичных данных.
- Ожидать выполнения defer после `os.Exit`.

## Связанные темы

- [[course/02-go/01-language/10-errors|Ошибки]]
- [[course/02-go/01-language/06-methods-receivers|Методы и receivers]]
- [[course/01-foundations/01-os/06-unix-signals|Сигналы Unix]]
- [[course/02-go/index|Модуль Go]]

## Источники

- [Go specification: Defer statements](https://go.dev/ref/spec#Defer_statements).
- [Go specification: Handling panics](https://go.dev/ref/spec#Handling_panics).
- [Go blog: Defer, Panic, and Recover](https://go.dev/blog/defer-panic-and-recover).
- [Go `os` package: Exit](https://pkg.go.dev/os#Exit).
