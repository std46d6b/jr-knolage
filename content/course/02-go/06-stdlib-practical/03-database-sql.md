---
title: "database/sql: pool, context и ошибки"
description: Как пользоваться database/sql как пулом соединений, соблюдать отмену операций и корректно обрабатывать результаты запросов.
tags: [go, database, sql, backend]
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# database/sql: pool, context и ошибки

`database/sql` задаёт переносимый интерфейс к SQL-драйверу. `*sql.DB` не является соединением: это concurrent-safe пул, который открывает и переиспользует соединения по необходимости. Драйвер импортируется отдельно; его особенности по placeholder, isolation и отмене нельзя скрывать общим API.

## Зачем это на интервью

E4 должен не допустить SQL injection, зависший запрос и утечку `Rows`. E5 должен объяснить, почему пул вызывает очередь, как настроить lifetime, как провести транзакцию и почему retry transaction требует понимания конкретной СУБД.

## Минимум для E4

- [ ] Вызвать `sql.Open`, затем проверить доступность через `PingContext` с timeout.
- [ ] Создать один `*sql.DB` на datasource и закрыть его при shutdown.
- [ ] Использовать `QueryContext`, `QueryRowContext`, `ExecContext` с context запроса.
- [ ] Закрыть `rows`, вызвать `rows.Err()` после цикла и проверять `Scan`.
- [ ] Передавать значения параметрами, а не склеивать SQL из пользовательской строки.

## Углубление для E5/Senior

`SetMaxOpenConns` ограничивает число соединений; при исчерпании запрос ждёт, поэтому слишком малый предел повышает latency, а слишком большой перегружает БД. `SetMaxIdleConns` удерживает warm connections. `SetConnMaxLifetime` помогает переживать лимиты/балансировщики, но одновременная ротация создаёт reconnect storm; добавляйте запас и наблюдайте `DB.Stats()`. `SetConnMaxIdleTime` освобождает давно idle connections.

Транзакция использует одно соединение. Все запросы должны идти через `tx`, а `defer tx.Rollback()` безопасен: после успешного `Commit` он вернёт `sql.ErrTxDone`. Не вызывайте `db.QueryContext` внутри логической транзакции — это другое соединение и другая атомарность. Контекст отменяет ожидание и, если драйвер поддерживает, запрос; не гарантирует, что сервер БД не успел применить side effect.

## Ключевые понятия

```go
package users

import (
    "context"
    "database/sql"
    "errors"
    "fmt"
    "time"
)

type User struct { ID int64; Email string }

type Repository struct { db *sql.DB }

func Open(ctx context.Context, driver, dsn string) (*Repository, error) {
    db, err := sql.Open(driver, dsn)
    if err != nil { return nil, err }
    db.SetMaxOpenConns(20)
    db.SetMaxIdleConns(10)
    db.SetConnMaxLifetime(30 * time.Minute)
    db.SetConnMaxIdleTime(5 * time.Minute)
    if err := db.PingContext(ctx); err != nil { db.Close(); return nil, fmt.Errorf("ping database: %w", err) }
    return &Repository{db: db}, nil
}

func (r *Repository) Find(ctx context.Context, id int64) (User, error) {
    var u User
    err := r.db.QueryRowContext(ctx, `SELECT id, email FROM users WHERE id = $1`, id).Scan(&u.ID, &u.Email)
    if errors.Is(err, sql.ErrNoRows) { return User{}, fmt.Errorf("user %d: %w", id, err) }
    if err != nil { return User{}, fmt.Errorf("select user: %w", err) }
    return u, nil
}

func (r *Repository) Close() error { return r.db.Close() }
```

Placeholder `$1` характерен для PostgreSQL, но `database/sql` не нормализует placeholder между драйверами. Контракт repository должен отделять `sql.ErrNoRows` или превращать его в доменную ошибку у границы приложения.

## Типовые вопросы

1. **Что делает `sql.Open`?**
   - Валидирует/создаёт handle через зарегистрированный driver; не обязан открывать TCP-соединение. Проверка доступности — `PingContext`.
2. **Почему `rows.Err()` после `Next`?**
   - Некоторые ошибки чтения появляются во время итерации, когда `Next` уже завершил цикл.
3. **Можно ли несколько goroutine на `*sql.DB`?**
   - Да, DB safe for concurrent use. `*sql.Tx` не следует использовать concurrent-но, если конкретный сценарий/driver не документирует это явно.
4. **Почему нельзя сделать `defer rows.Close()` в длинном цикле запросов?**
   - Закрытие отложится до выхода из функции и может удержать connection из pool. Нужна функция-итерация или явное `Close`.
5. **Что возвращает `QueryRowContext` при отсутствии строки?**
   - Сам `QueryRowContext` возвращает placeholder; `sql.ErrNoRows` появляется при `Scan`.

## Практика

- [ ] Напишите repository `Find` и `List`. **Критерий готовности:** параметризация есть во всех запросах, `List` закрывает rows и проверяет `rows.Err()`.
- [ ] Настройте pool и экспортируйте `DB.Stats()`. **Критерий готовности:** нагрузочный тест демонстрирует ожидание при `MaxOpenConns=1`, а отчёт содержит `WaitCount` и `WaitDuration`.
- [ ] Оберните перевод денег в транзакцию. **Критерий готовности:** обе записи используют `tx`, rollback выполняется при любой ошибке, test фиксирует отсутствие частичного обновления.

## Частые ошибки и ловушки

- Держать глобальную транзакцию или соединение для всего приложения.
- Увеличивать `MaxOpenConns`, не проверив лимиты БД и число реплик.
- Игнорировать `context.Canceled`/`DeadlineExceeded` и повторять операцию без понимания результата.
- Вставлять имя колонки/table из пользователя параметром: placeholders работают для значений, не идентификаторов.
- Скрывать ошибку `Close` у rows, когда driver может сообщить deferred error.

## Связанные темы

[[course/02-go/06-stdlib-practical|Практический Go]] · [[course/05-postgresql|PostgreSQL]] · [[course/02-go/06-stdlib-practical/06-slog-configuration-testing|Логи, конфигурация и тесты]]

## Источники

- [package database/sql](https://pkg.go.dev/database/sql)
- [Managing connections](https://go.dev/doc/database/manage-connections)
- [Executing transactions](https://go.dev/doc/database/execute-transactions)
