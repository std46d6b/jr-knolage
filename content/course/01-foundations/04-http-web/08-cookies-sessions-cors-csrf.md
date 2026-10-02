---
title: "Cookies, сессии, CORS и CSRF"
description: "Модель браузерной аутентификации: cookie-атрибуты, серверные сессии, origin-политика, CORS и защита от CSRF."
tags:
  - browser-security
  - cookies
  - cors
  - csrf
  - web
status: complete
difficulty: e4
created: 2026-10-02
updated: 2026-10-02
draft: false
---

# Cookies, сессии, CORS и CSRF

Cookie — пара имени и значения, которую браузер автоматически прикладывает к подходящим запросам по правилам domain, path, scheme и `SameSite`. Сессия обычно хранит на сервере состояние пользователя, а в cookie лежит непрозрачный случайный идентификатор. CORS — механизм, которым сервер разрешает JavaScript чужого origin читать response; он не является аутентификацией и не защищает сервер от всех запросов. CSRF использует автоматическую отправку credential browser-ом, чтобы заставить уже вошедшего пользователя выполнить действие с чужой страницы.

## Зачем это на интервью

Здесь проверяют различение браузерных политик. Важен ответ «CORS запрещает чтение response скриптом, но не обязательно отправку request», понимание `SameSite`, `HttpOnly`, preflight и выбранной защиты для cookie-based mutations.

## Минимум для E4

- [ ] Ставить session cookie с `Secure`, `HttpOnly`, подходящим `SameSite`, узкими `Path`/`Domain` и разумными `Max-Age`/`Expires`.
- [ ] Генерировать session ID криптографически случайно, хранить server-side или подписывать/шифровать по явному дизайну; ротировать ID после login и изменения привилегий.
- [ ] Проверять авторизацию на сервере для каждого запроса, не доверять только UI или CORS.
- [ ] Разрешать CORS конкретным origin; при credentials не использовать `Access-Control-Allow-Origin: *`.
- [ ] Для небезопасных cookie-auth запросов применять CSRF-защиту: synchronizer token либо double-submit с проверкой origin и корректной реализацией.
- [ ] Не хранить долгоживущие bearer tokens в `localStorage` без осознанной модели XSS-риска.

## Углубление для E5/Senior

Origin — схема, host и port. `https://app.example.com` и `https://api.example.com` — разные origins, но обычно same-site: `SameSite` использует schemeful site, а не origin. Поэтому `SameSite` не заменяет CORS и не даёт автоматически CSRF-защиту между sibling subdomain. Cookie с `Domain=.example.com` доступна всем subdomain; если один из них менее доверен, host-only cookie безопаснее. Префиксы `__Host-` требуют `Secure`, path `/` и отсутствия `Domain`, уменьшая риск shadowing cookie.

CORS preflight — `OPTIONS` перед cross-origin request, когда метод/заголовки/content type не simple. Сервер отвечает allow-списками, а браузер решает, можно ли продолжить и раскрыть response JavaScript. Non-browser клиент CORS не ограничивает. `credentials: "include"` требует точного `Access-Control-Allow-Origin` и `Access-Control-Allow-Credentials: true`; cache должен учитывать `Origin` через `Vary: Origin`, иначе CDN может отдать разрешение не тому сайту.

CSRF token доказывает, что request инициирован страницей, которая могла прочитать секрет. Synchronizer token хранится в server-side session и передаётся в форму/response; сервер сравнивает его константным временем. Double-submit cookie работает только при защите от attacker-controlled subdomain и корректной привязке/подписи. Проверка `Origin` для state-changing requests — полезный дополнительный барьер; `Referer` может отсутствовать, поэтому не должен быть единственным механизмом. `SameSite=Lax` ослабляет классический CSRF, но не заменяет политику для всех flows и не защищает от XSS.

HttpOnly не останавливает XSS: вредоносный script не прочитает cookie, но может выполнять авторизованные действия со страницы. Нужны output encoding, CSP, безопасная работа с DOM и ограничение опасных endpoint. Logout должен инвалидировать сессию на сервере, а не только удалить cookie у браузера; parallel session и device lifecycle проектируют отдельно.

## Ключевые понятия

| Механизм         | Что делает                                    | Чего не делает                                        |
| ---------------- | --------------------------------------------- | ----------------------------------------------------- |
| `HttpOnly`       | Запрещает JS читать cookie                    | Не мешает XSS отправлять запросы                      |
| `Secure`         | Посылает cookie только по HTTPS               | Не шифрует данные на сервере                          |
| `SameSite`       | Ограничивает cross-site отправку cookie       | Не заменяет auth, CORS или XSS-защиту                 |
| CORS             | Управляет доступом JS к cross-origin response | Не блокирует curl и не авторизует пользователя        |
| CSRF token       | Связывает mutation с доверенной страницей     | Не предотвращает XSS на доверенном origin             |
| Session rotation | Меняет ID после смены auth state              | Не отзывает украденный токен без server-side контроля |

```http
Set-Cookie: __Host-session=opaque-random-id; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=28800
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Credentials: true
Vary: Origin
```

Для SPA на отдельном origin сервер также разрешает нужные request headers, отвечать на preflight и применяет CSRF-контракт к изменяющим методам. Не отражайте `Origin` в allow-заголовке без allowlist.

## Типовые вопросы

1. **Почему `HttpOnly` cookie лучше токена в `localStorage`?**
   - Скрипт при XSS не может прочитать cookie напрямую. Но XSS всё ещё может отправить запрос, поэтому это не полная защита.
2. **Почему CORS не заменяет CSRF?**
   - CORS в основном запрещает чужому JS читать ответ; браузер всё ещё может отправить простую form submission с cookie.
3. **Почему нельзя сочетать `Allow-Credentials: true` и `Allow-Origin: *`?**
   - Спецификация и браузеры не допускают wildcard для credentialed response: origin должен быть явным.
4. **Когда нужен preflight?**
   - Например, для `PATCH`, `Authorization` или JSON с неподходящим simple content type при cross-origin fetch; браузер сначала отправит `OPTIONS`.
5. **Что даёт `SameSite=Lax`?**
   - Обычно не посылает cookie в cross-site subresource/fetch, но может послать при top-level безопасной navigation; поведение должно соответствовать вашему login/payment flow.
6. **Почему нужно ротировать session ID после login?**
   - Это уменьшает session fixation: attacker не должен заранее навязать пользователю известный ID и получить его после аутентификации.

## Практика

- [ ] Реализуйте server-side login session.
  - Критерии приёмки: ID генерируется CSPRNG; cookie имеет `Secure`, `HttpOnly`, `SameSite` и host-only scope; ID меняется после login; logout инвалидирует запись на сервере; тест фиксирует session fixation.
- [ ] Настройте CORS для отдельного SPA origin.
  - Критерии приёмки: allowlist принимает только точный origin; credentialed preflight разрешает необходимые method/header; response содержит `Vary: Origin`; тесты отклоняют unknown origin и wildcard с credentials.
- [ ] Защитите mutation от CSRF.
  - Критерии приёмки: корректный token и origin выполняют запрос; нет token/неверный token/чужой origin получают отказ; безопасные `GET` не меняют состояние; integration test моделирует cross-site form POST.

## Частые ошибки и ловушки

- Принимать CORS за сетевой firewall или серверную авторизацию.
- Отражать любой `Origin` и одновременно разрешать credentials.
- Ставить `SameSite=None` без `Secure` либо без необходимости cross-site flow.
- Сохранять session ID до login и не ротировать его.
- Использовать только `Referer` для CSRF и не учитывать его отсутствие.
- Передавать access token в URL, логи, `Referer` или browser history.

## Связанные темы

[[course/01-foundations/index|База разработки и Computer Science]] · [[course/01-foundations/04-http-web/05-rest-api-design|REST-дизайн API]] · [[course/01-foundations/04-http-web/07-websocket-sse-long-polling|WebSocket, SSE и long polling]] · [[course/01-foundations/04-http-web/09-api-versioning-compatibility|Версионирование и совместимость API]]

## Источники

- RFC 6265 и draft RFC 6265bis — HTTP State Management Mechanism.
- Fetch Standard — CORS, credentials и preflight.
- OWASP Cheat Sheet Series: Session Management, Cross-Site Request Forgery Prevention, CORS.
- MDN Web Docs: Set-Cookie, SameSite cookies, CORS.
