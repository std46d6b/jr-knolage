---
title: io, os, filepath и fs
description: Потоковый ввод-вывод, владение ресурсами, безопасная работа с путями и абстракция файловой системы в Go.
tags: [go, io, filesystem, security]
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# io, os, filepath и fs

`io.Reader` поставляет байты, `io.Writer` принимает байты, `io.Closer` освобождает ресурс. Малые интерфейсы делают pipeline композиционным: файл можно ограничить `LimitReader`, распаковать и одновременно хешировать без обязательного `[]byte`. `os` работает с ОС, `path/filepath` — с путями текущей ОС, а `io/fs` описывает переносимую read-only файловую систему.

## Зачем это на интервью

E4 должен назвать владельца `Close`, правильно проверить partial I/O и не разрешить path traversal в файловом endpoint. E5 обсуждает memory pressure, atomic publish, symlink races, виртуальные FS в тестах и ограничения доверенной границы.

## Минимум для E4

- [ ] Принимать `io.Reader`/`io.Writer`, когда алгоритм не требует random access или всего буфера.
- [ ] Вызывать `Close` у ресурса, который открыла функция, и документировать иной контракт.
- [ ] Проверять `n` вместе с `err`; `io.EOF` после успешно прочитанных байтов — нормальная граница потока.
- [ ] Пользоваться `filepath.Join`, `Clean`, `Rel` для локальных путей, не `path`.
- [ ] Ограничивать размер недоверенного файла и проверять, что разрешённый путь остаётся внутри root.

## Углубление для E5/Senior

`fs.FS` использует slash-separated, относительные имена без `.` и `..`; `fs.ValidPath` проверяет именно этот формат. `os.DirFS(root)` удобен, но не является sandbox против symlink-escape: если attacker может менять дерево, проверка строкового пути недостаточна. Для изоляции нужны права ОС, отдельный mount/container или API с дескрипторным обходом, где это доступно.

`os.WriteFile` удобно для небольших файлов, но не делает publish атомарным. Для конфигурации/артефакта пишут временный файл в том же каталоге, проверяют `Close`/`Sync` по требованиям durability и делают `Rename`; семантика rename и fsync каталога зависит от платформы и файловой системы. Не следуйте symlink и не доверяйте `Stat`-then-open при hostile FS без специальной защиты от TOCTOU.

## Ключевые понятия

```go
package files

import (
    "fmt"
    "io"
    "io/fs"
    "os"
    "path/filepath"
)

func OpenUnder(root, name string) (*os.File, error) {
    if !fs.ValidPath(name) { return nil, fmt.Errorf("invalid relative path %q", name) }
    root = filepath.Clean(root)
    full := filepath.Join(root, filepath.FromSlash(name))
    rel, err := filepath.Rel(root, full)
    if err != nil || rel == ".." || filepath.IsAbs(rel) { return nil, fmt.Errorf("path escapes root") }
    return os.Open(full)
}

func CopyLimited(dst io.Writer, src io.Reader, max int64) (int64, error) {
    n, err := io.Copy(dst, io.LimitReader(src, max+1))
    if err != nil { return n, err }
    if n > max { return n, fmt.Errorf("input exceeds %d bytes", max) }
    return n, nil
}
```

Проверка выше защищает от `../` и абсолютного пути в обычной модели, но не является защитой от конкурентной замены каталогов/симлинков. Сначала определите threat model; для trusted upload directory часто достаточно ограничений имени и прав процесса.

## Типовые вопросы

1. **Когда reader возвращает `n > 0` и `err == io.EOF`?**
   - Это допустимо; caller обязан сначала обработать `n` байтов, а EOF трактовать как конец после них.
2. **`io.Copy` закрывает источник или назначение?**
   - Нет. Он только копирует; владелец open resource закрывает его явно.
3. **`filepath` и `path`?**
   - `filepath` учитывает separator текущей ОС для файлов; `path` предназначен для slash-путей, например URL или `fs.FS` имени.
4. **Безопасен ли `filepath.Join(root, userPath)` сам по себе?**
   - Нет: `..`, абсолютные и symlink path могут выйти из ожидаемой области; нужна валидация и подходящая модель доверия.
5. **Зачем `fs.FS`?**
   - Код может читать `os.DirFS`, `embed.FS` или `fstest.MapFS` по одному контракту, что упрощает тестирование и упаковку статических файлов.

## Практика

- [ ] Реализуйте upload с лимитом и поточным SHA-256. **Критерий готовности:** body больше лимита отвергается, тест не использует гигабайтный буфер, файлы закрываются при ошибке копирования.
- [ ] Добавьте static-file reader поверх `fs.FS`. **Критерий готовности:** unit test использует `fstest.MapFS`; запросы `../secret` и абсолютный путь отклоняются.
- [ ] Реализуйте atomic write для конфигурации. **Критерий готовности:** временный файл расположен в целевом каталоге, ошибки `Close` обработаны, тест не видит частично записанный файл.

## Частые ошибки и ловушки

- Игнорировать `Close` gzip/file writer и терять финальный буфер или checksum.
- Использовать `io.ReadAll` на HTTP body без лимита.
- Считать `filepath.Clean` авторизацией пути.
- Открывать тысячи файлов с `defer` в одном длительном цикле.
- Путать `fs.ValidPath` для virtual FS с OS absolute path.

## Связанные темы

[[course/02-go/06-stdlib-practical|Практический Go]] · [[course/02-go/06-stdlib-practical/05-encoding-crypto-compress|Encoding, crypto и compress]] · [[course/01-foundations/01-os/05-file-descriptors-stdio|Файловые дескрипторы]]

## Источники

- [package io](https://pkg.go.dev/io)
- [package io/fs](https://pkg.go.dev/io/fs)
- [package os](https://pkg.go.dev/os)
- [package path/filepath](https://pkg.go.dev/path/filepath)
