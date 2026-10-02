---
title: "XML, CSV и base64"
description: "Выбор и безопасная обработка распространённых форматов данных в Go."
tags:
  - go
  - encoding
  - xml
  - csv
  - interview
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# XML, CSV и base64

## Зачем это на интервью

Не каждый интеграционный формат — JSON. Нужны точные границы: CSV — табличный текст, XML — структурированный документ, base64 — кодирование байтов, а не шифрование и не сжатие.

## Минимум для E4

- [ ] Читать CSV через `encoding/csv`, а не `strings.Split`.
- [ ] Описывать XML struct tags и обрабатывать ошибки decode.
- [ ] Уметь кодировать/декодировать base64 и понимать увеличение размера.

## Углубление для E5/Senior

Для больших XML/CSV применяйте streaming API, лимиты reader и контекст на уровне транспорта, а не загружайте весь файл без причины. CSV не имеет единой схемы: явно задайте delimiter, заголовки, число полей и правила пустых/невалидных значений. XML может содержать большие и глубоко вложенные документы; ограничивайте вход, валидируйте доменные поля и не принимайте «успешный parse» за безопасность. Base64 увеличивает размер примерно на треть и не обеспечивает ни конфиденциальности, ни целостности.

## Ключевые понятия

```go
// CSV: Reader корректно учитывает кавычки и экранирование.
r := csv.NewReader(input)
r.FieldsPerRecord = 3
for {
	record, err := r.Read()
	if errors.Is(err, io.EOF) { break }
	if err != nil { return err }
	_ = record
}

type Invoice struct { ID string `xml:"id,attr"`; Total int `xml:"total"` }
var inv Invoice
if err := xml.NewDecoder(xmlInput).Decode(&inv); err != nil { return err }

encoded := base64.StdEncoding.EncodeToString([]byte("binary\x00data"))
raw, err := base64.StdEncoding.DecodeString(encoded)
```

Для потоковой base64-кодировки используйте `base64.NewEncoder`, закрывая writer, чтобы дописать padding. Для CSV-записи завершайте `Flush` и проверяйте `w.Error()`.

## Типовые вопросы

1. **Почему CSV нельзя разбирать `Split(",")`?**
   - Поле может содержать запятую, кавычки и перевод строки по правилам CSV.
2. **Шифрует ли base64 данные?**
   - Нет, это обратимое текстовое представление байтов.
3. **Как обработать большой CSV?**
   - Читать запись за записью через `Reader`, не `ReadAll`, с лимитами входа.
4. **Чем XML tag отличается от JSON tag?**
   - XML описывает элементы, атрибуты и вложенность; формат tag другой.
5. **Почему после `csv.Writer.Flush` нужна `Error`?**
   - Ошибка записи может возникнуть асинхронно во время flush.

## Практика

- [ ] Импортируйте CSV из `io.Reader`. **Готово:** корректно обрабатываются quoted comma, неверное число колонок и I/O error.
- [ ] Реализуйте streaming base64-кодирование файла. **Готово:** decode даёт исходные байты, encoder закрывается, тест не читает файл целиком.

## Частые ошибки и ловушки

- Считать base64 защитой секрета.
- Не ограничивать размер загружаемого XML/CSV.
- Игнорировать `csv.Writer.Error()`.

## Связанные темы

[[course/02-go/02-collections|Коллекции и работа с данными]] · [[course/02-go/02-collections/06-json-encoding|JSON]]

## Источники

- [package encoding/csv](https://pkg.go.dev/encoding/csv)
- [package encoding/xml](https://pkg.go.dev/encoding/xml)
- [package encoding/base64](https://pkg.go.dev/encoding/base64)
