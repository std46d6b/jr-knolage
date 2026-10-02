---
title: Git, CI/CD, Docker и Kubernetes
description: Путь изменения от локального кода до безопасного production rollout.
tags:
  - go
  - interview
  - 13-delivery
status: in-progress
difficulty: e4
draft: false
---

# Git, CI/CD, Docker и Kubernetes

Путь изменения от локального кода до безопасного production rollout.

## Результат модуля

После модуля вы можете объяснить ключевые понятия, выбрать подход под условия задачи и показать это на коде, запросе или архитектурной схеме.

## Темы

- Git: rebase/merge/revert/reflog, PR workflow, trunk-based development.
- CI: lint/test/security scan/build/artifact; immutable versions and promotion.
- Deploy strategies: rolling, blue-green, canary; rollback и feature flags.
- Docker: multi-stage builds, layers, non-root, minimal images, healthcheck, Compose.
- Kubernetes: Pod, Deployment, StatefulSet, Job/CronJob, Service, Ingress.
- Resources, probes, ConfigMap/Secret, HPA, RBAC/NetworkPolicy, Helm/Kustomize.
- Diagnosing Pending, CrashLoopBackOff, 503 and image pull failures.

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

1. **Чем readiness отличается от liveness?**
   - Подготовьте ответ с примером из production или практики.
1. **Почему migration нельзя бездумно запускать при каждом replica rollout?**
   - Подготовьте ответ с примером из production или практики.
1. **Как откатить несовместимый change базы?**
   - Подготовьте ответ с примером из production или практики.

## Практика

- [ ] Соберите Go service в multi-stage image и подготовьте Deployment с probes, limits и безопасным rollout.
- [ ] Сформулируйте три частые ошибки по модулю и признаки их проявления.
- [ ] Добавьте в личные карточки определения и решения, которые не удалось воспроизвести без подсказки.

## Связанные темы

[[index|Главная]] · [[course/02-go|Go]] · [[course/05-postgresql|PostgreSQL]] · [[course/08-system-design|System Design]] · [[course/15-interview-practice|Интервью-практика]]

## Источники

- Официальная документация используемого языка, БД или платформы.
- Production-документация команды и проверенные технические разборы.
- Конкретные ссылки добавляйте при наполнении темы, вместе с датой проверки актуальности.
