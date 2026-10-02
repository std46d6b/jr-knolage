---
title: "JSON: encoding/json, теги и custom marshal"
description: "Контракты JSON в Go: поля, omitempty, ошибки и собственные MarshalJSON/UnmarshalJSON."
tags:
  - go
  - json
  - api
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# JSON: encoding/json, теги и custom marshal

## Зачем это на интервью

JSON — граница API и хранения. Вопрос проверяет, умеет ли кандидат отделить внешний контракт от Go-модели, валидировать вход и не скрывать ошибки сериализации.

## Минимум для E4

- [ ] Использовать экспортируемые поля и struct tags.
- [ ] Понимать `omitempty` и различие `nil`/пустого slice в JSON.
- [ ] Проверять ошибку каждого `Encode`/`Decode`.

## Углубление для E5/Senior

`encoding/json` по умолчанию терпимо к лишним полям и при повторяющихся ключах действует по правилам пакета; на границе строгого API решите это явно (`Decoder.DisallowUnknownFields`). `Decode` одного значения из network body не доказывает отсутствие trailing JSON: проверяйте контракт. Числа в `interface{}` становятся `float64`, если не включить `UseNumber`. Custom marshaler применяют для стабильного формата/инвариантов, избегая рекурсии через alias type. Не сериализуйте внутренние сущности напрямую, если API должен жить независимо от схемы.

## Ключевые понятия

```go
type User struct {
	ID    string   `json:"id"`
	Name  string   `json:"name"`
	Roles []string `json:"roles,omitempty"`
	Token string   `json:"-"`
}

func decodeUser(r io.Reader) (User, error) {
	var u User
	d := json.NewDecoder(r)
	d.DisallowUnknownFields()
	if err := d.Decode(&u); err != nil { return User{}, err }
	if u.ID == "" { return User{}, errors.New("id is required") }
	return u, nil
}

type Status uint8
func (s Status) MarshalJSON() ([]byte, error) {
	if s > 1 { return nil, fmt.Errorf("invalid status: %d", s) }
	return json.Marshal(map[Status]string{0: "new", 1: "done"}[s])
}
```

`omitempty` убирает zero value: `0`, `false`, `""`, nil pointer/interface и nil либо пустой slice/map. Если «отсутствует» и «пустой» различаются для API, моделируйте это отдельно (например, pointer или custom type).

## Типовые вопросы

1. **Почему поле не попало в JSON?**
   - Непубличное поле игнорируется; также его мог исключить тег `json:"-"`.
2. **Что делает `omitempty`?**
   - Не выводит поле с пустым значением по правилам пакета.
3. **Как отклонить неизвестные поля?**
   - `Decoder.DisallowUnknownFields()` до `Decode`.
4. **Когда писать `MarshalJSON`?**
   - Когда внешний формат или инвариант не выражается тегами; обычные struct tags предпочтительнее.
5. **Почему нельзя игнорировать ошибку Encoder?**
   - Запись в `io.Writer` может не выполниться; ответ клиенту окажется неполным.

## Практика

- [ ] Опишите request DTO с обязательным `id` и скрытым секретом. **Готово:** unit-тесты проверяют tag, unknown field, пустой id и отсутствие секрета.
- [ ] Реализуйте enum с custom JSON. **Готово:** неизвестное значение не сериализуется, а round-trip допустимых значений проходит.

## Частые ошибки и ловушки

- Полагаться на default field names как на долговечный публичный контракт.
- Путать `null`, `[]` и отсутствующее поле.
- Читать unbounded JSON body без ограничения размера на HTTP-границе.

## Связанные темы

[[course/02-go/02-collections|Коллекции и работа с данными]] · [[course/01-foundations/04-http-web|HTTP и Web]]

## Источники

- [package encoding/json](https://pkg.go.dev/encoding/json)
- [JSON and Go](https://go.dev/blog/json)
- [json.Decoder](https://pkg.go.dev/encoding/json#Decoder)
