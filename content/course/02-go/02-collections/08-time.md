---
title: "Time: time.Time, duration и timezone"
description: "Момент времени, монотонные часы, длительности и корректная работа с часовыми поясами."
tags:
  - go
  - time
  - datetime
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Time: time.Time, duration и timezone

## Зачем это на интервью

Время — источник редких, дорогих багов: DST, локальная зона сервера, округление и смешение момента с календарной датой. Go различает wall clock и монотонное измерение длительности.

## Минимум для E4

- [ ] Хранить и передавать моменты в UTC, применять location на границе отображения.
- [ ] Использовать `time.Duration`, а не голые числа миллисекунд.
- [ ] Парсить время с явным layout и проверять ошибку.

## Углубление для E5/Senior

`time.Now()` содержит wall-clock и, внутри процесса, монотонное чтение; `time.Since(start)` использует его для устойчивого измерения интервала. Сериализация, `Round`, `Truncate`, `UTC` и некоторые преобразования могут отбросить monotonic component — не используйте JSON-время для измерения elapsed. `time.Time` описывает момент, не всегда бизнес-дату: для «дня платежа» нужен доменный тип и явно выбранная location. Вокруг DST локальное время может быть неоднозначным или несуществующим.

## Ключевые понятия

```go
start := time.Now()
// work()
elapsed := time.Since(start) // duration, удобна для метрик

loc, err := time.LoadLocation("Europe/Moscow")
if err != nil { return err }
t, err := time.ParseInLocation("2006-01-02 15:04", "2026-10-02 09:30", loc)
if err != nil { return err }
stored := t.UTC()
fmt.Println(stored.Format(time.RFC3339))

if deadline.Before(time.Now()) { return errors.New("deadline expired") }
```

Layout — эталонная дата `Mon Jan 2 15:04:05 MST 2006`, а не шаблон вроде `YYYY-MM-DD`. `time.Duration` — число наносекунд; пишите `5*time.Second`, избегая `5000` без единиц. Для внешнего API используйте RFC3339 или документированный формат и timezone.

## Типовые вопросы

1. **Что измеряет `time.Duration`?**
   - Интервал в наносекундах как целое значение; его создают с единицами `time.Second`, `time.Millisecond` и т.д.
2. **Почему UTC предпочтителен для хранения?**
   - Он устраняет неоднозначность zone/DST; локаль применяют при вводе и отображении.
3. **Что такое monotonic clock в `time.Time`?**
   - Внутреннее чтение для вычисления интервалов в процессе, устойчивое к смене wall clock.
4. **Как распарсить локальное время?**
   - `time.ParseInLocation(layout, value, loc)` с обработкой ошибки и явной зоной.
5. **Почему layout выглядит странно?**
   - Go использует конкретный reference time, его компоненты задают формат.

## Практика

- [ ] Реализуйте парсер RFC3339 с нормализацией в UTC. **Готово:** тесты покрывают offset, неверную строку и ожидаемое UTC-значение.
- [ ] Добавьте измерение операции. **Готово:** метрика использует `time.Since(start)`, а тест вводит clock/функцию now там, где нужно детерминированное время.

## Частые ошибки и ловушки

- Хранить timestamp без offset и надеяться на timezone сервера.
- Передавать число duration без единицы.
- Использовать `time.Now().Sub(savedJSONTime)` как точное монотонное измерение.

## Связанные темы

[[course/02-go/02-collections|Коллекции и работа с данными]] · [[course/01-foundations/04-http-web|HTTP и Web]]

## Источники

- [package time](https://pkg.go.dev/time)
- [Go FAQ: monotonic clocks](https://go.dev/doc/faq#monotonic_time)
- [time.ParseInLocation](https://pkg.go.dev/time#ParseInLocation)
