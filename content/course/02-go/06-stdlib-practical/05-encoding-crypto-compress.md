---
title: encoding, crypto и compress
description: Выбор форматов, проверенные криптографические примитивы и безопасная потоковая компрессия в Go-сервисах.
tags: [go, encoding, crypto, compression, security]
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# encoding, crypto и compress

Пакеты `encoding/*` преобразуют данные между представлениями; это не защита. `crypto/*` реализует криптографические примитивы, но безопасность зависит от правильной композиции, случайности и управления ключами. `compress/*` сокращает данные, но распаковка недоверенного входа требует лимитов из-за decompression bomb.

## Зачем это на интервью

Кандидат должен не назвать base64 шифрованием, выбрать `crypto/rand`, сравнить секреты без утечки по времени и не распаковать неограниченный HTTP payload в память. Senior дополнительно объясняет AEAD, ротацию ключей, совместимость wire-format и компрессионные side channels.

## Минимум для E4

- [ ] Использовать `encoding/json` с явными структурами, лимитом reader и обработкой ошибок encode/decode.
- [ ] Отличать JSON, base64 и hex (кодирование) от hash и encryption.
- [ ] Генерировать security token через `crypto/rand`, не `math/rand`.
- [ ] Для симметричного шифрования использовать AEAD (`aes.NewCipher` + `cipher.NewGCM`) с уникальным nonce для каждого сообщения.
- [ ] Ограничивать compressed input и decompressed output; закрывать compressor для записи trailer.

## Углубление для E5/Senior

AEAD одновременно шифрует и аутентифицирует ciphertext и optional associated data. Nonce для GCM должен быть уникальным для ключа; случайный nonce из `crypto/rand` приемлем при корректном ограничении объёма, но счётчик/управляемая схема требуют durable state. Формат должен содержать версию, nonce и ciphertext, но не ключ. Самостоятельно не выбирайте «свою» схему derivation: используйте проверенный протокол/библиотеку и KMS для хранения/ротации ключей.

Сжатие перед шифрованием обычно эффективнее, но сжатие секретных и контролируемых attacker-ом данных в одном контексте может открыть CRIME/BREACH-подобный side channel. Для HTTP учитывайте `Content-Encoding`, `Accept-Encoding`, лимит body до и после распаковки и `Vary: Accept-Encoding`. `gzip.Reader.Close` не закрывает underlying reader; `gzip.Writer.Close` обязателен для финализации потока.

## Ключевые понятия

```go
package token

import (
    "crypto/rand"
    "crypto/subtle"
    "encoding/base64"
    "fmt"
    "io"
)

func New() (string, error) {
    raw := make([]byte, 32)
    if _, err := io.ReadFull(rand.Reader, raw); err != nil { return "", fmt.Errorf("random token: %w", err) }
    return base64.RawURLEncoding.EncodeToString(raw), nil
}

func Equal(expected, supplied string) bool {
    a, errA := base64.RawURLEncoding.DecodeString(expected)
    b, errB := base64.RawURLEncoding.DecodeString(supplied)
    if errA != nil || errB != nil || len(a) != len(b) { return false }
    return subtle.ConstantTimeCompare(a, b) == 1
}
```

`subtle.ConstantTimeCompare` уменьшает утечку по времени только для равных длин и не исправляет архитектурные ошибки. Не храните bearer token в логах и не сравнивайте password с самодельным hash; для паролей нужен специализированный password-hashing алгоритм и policy, обычно из проверенной внешней библиотеки/identity provider.

## Типовые вопросы

1. **Base64 шифрует данные?**
   - Нет, это обратимое текстовое кодирование байтов; любой может декодировать его без ключа.
2. **Почему `math/rand` нельзя для token?**
   - Его генератор предсказуем и предназначен для моделирования/случайного выбора, не для security. Нужен `crypto/rand.Reader`.
3. **Hash и MAC?**
   - Hash даёт digest без секрета; MAC (например HMAC) аутентифицирует сообщение для владеющих secret key.
4. **Зачем AEAD?**
   - Оно проверяет целостность и происхождение ciphertext вместе с confidentiality; шифрование без authentication допускает опасные атаки на ciphertext.
5. **Почему gzip может быть DoS?**
   - Небольшой compressed stream может распаковаться в огромный объём или потребовать CPU; ограничивайте вход, выход и время обработки.

## Практика

- [ ] Напишите JSON endpoint с `DisallowUnknownFields` там, где строгий контракт нужен. **Критерий готовности:** неизвестное поле и oversized payload возвращают контролируемую ошибку; test фиксирует wire contract.
- [ ] Сгенерируйте URL-safe token. **Критерий готовности:** token декодируется в 32 байта, тест не сравнивает конкретную случайную строку, ошибка entropy source обрабатывается через injected reader.
- [ ] Реализуйте gzip upload с лимитом распакованного размера. **Критерий готовности:** нормальный stream читается, повреждённый gzip отвергается, тест с «бомбой» прекращается на лимите.

## Частые ошибки и ловушки

- Называть base64/hex encryption или хранить secret в base64 «защищённым».
- Повторять nonce с тем же GCM key.
- Использовать `md5`/`sha1` для нового security-контракта или хешировать пароль быстрым SHA-256.
- Доверять `Content-Length` как единственному лимиту тела.
- Забыть `gzip.Writer.Close` и получить обрезанный stream.

## Связанные темы

[[course/02-go/06-stdlib-practical|Практический Go]] · [[course/02-go/06-stdlib-practical/04-io-os-filepath-fs|I/O и файловая система]] · [[course/11-security|Безопасность]]

## Источники

- [package encoding/json](https://pkg.go.dev/encoding/json)
- [package crypto/rand](https://pkg.go.dev/crypto/rand)
- [package crypto/cipher](https://pkg.go.dev/crypto/cipher)
- [package compress/gzip](https://pkg.go.dev/compress/gzip)
- [Go security policy](https://go.dev/security)
