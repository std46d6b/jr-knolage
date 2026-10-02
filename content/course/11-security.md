---
title: Безопасность
description: Безопасные API, данные и инфраструктурные границы ответственности backend-разработчика.
tags:
  - go
  - interview
  - 11-security
status: in-progress
difficulty: e4
draft: false
---

# Безопасность

Безопасные API, данные и инфраструктурные границы ответственности backend-разработчика.

## Результат модуля

После модуля вы можете объяснить ключевые понятия, выбрать подход под условия задачи и показать это на коде, запросе или архитектурной схеме.

## Темы

- OWASP Top 10: injection, broken access control, SSRF, XSS, security misconfiguration.
- Authentication vs authorization; sessions, JWT, opaque tokens, OAuth2/OIDC.
- RBAC/ABAC, resource-level authorization, password hashing and token lifecycle.
- CORS, CSRF, input validation, output encoding, upload security, rate limiting.
- TLS, secrets rotation, IAM least privilege, encryption, backups, PII retention.
- Secure Go: crypto/rand, parameterized SQL, URL handling, body limits, timeouts, gosec.

## Минимум для E4

- Знать определения без заученных «магических» формулировок.
- Объяснять ограничения каждого подхода и называть минимум одну альтернативу.
- Приводить практический пример: код, схема, запрос или production-сценарий.
- Учитывать ошибки, наблюдаемость и безопасный rollout там, где это применимо.

## Углубление для E5/Senior

- Оценивать масштаб, стоимость, эксплуатационные риски и совместимость изменений.
- Проектировать постепенную эволюцию решения, а не только целевую схему.
- Защищать решение через требования и измеримые trade-offs.

## Типовые вопросы

1. **Почему JWT нельзя просто отозвать без дополнительного состояния?**
   - Подготовьте ответ с примером из production или практики.
1. **Как предотвращать SSRF?**
   - Подготовьте ответ с примером из production или практики.
1. **Какие данные нельзя класть в логи?**
   - Подготовьте ответ с примером из production или практики.

## Практика

- [ ] Проведите threat model для endpoint загрузки файла и составьте список mitigations.
- [ ] Сформулируйте три частые ошибки по модулю и признаки их проявления.
- [ ] Добавьте в личные карточки определения и решения, которые не удалось воспроизвести без подсказки.

## Связанные темы

[[index|Главная]] · [[course/02-go|Go]] · [[course/05-postgresql|PostgreSQL]] · [[course/08-system-design|System Design]] · [[course/15-interview-practice|Интервью-практика]]

## Источники

- Официальная документация используемого языка, БД или платформы.
- Production-документация команды и проверенные технические разборы.
- Конкретные ссылки добавляйте при наполнении темы, вместе с датой проверки актуальности.
