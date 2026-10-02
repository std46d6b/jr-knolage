---
title: Алгоритмы и структуры данных
description: Паттерны, достаточные для live coding и алгоритмических секций middle-интервью.
tags:
  - go
  - interview
  - 04-algorithms
status: in-progress
difficulty: e4
draft: false
---

# Алгоритмы и структуры данных

Паттерны, достаточные для live coding и алгоритмических секций middle-интервью.

## Результат модуля

После модуля вы можете объяснить ключевые понятия, выбрать подход под условия задачи и показать это на коде, запросе или архитектурной схеме.

## Темы

- Оценка time/space complexity; уточнение условия, brute force и edge cases.
- Arrays/slices, hash map/set, stack/queue/deque, two pointers, sliding window, prefix sums.
- Trees: DFS/BFS, BST, trie; heap/priority queue и Top K.
- Binary search, sorting, intervals, monotonic stack/queue.
- Graphs: BFS/DFS, topological sort, Dijkstra, union-find, cycle detection.
- Backtracking и dynamic programming: memoization, tabulation, 1D/2D patterns.

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

1. **Как выбрать между sliding window и prefix sums?**
   - Подготовьте ответ с примером из production или практики.
1. **Когда Dijkstra некорректен?**
   - Подготовьте ответ с примером из production или практики.
1. **Почему hash map даёт амортизированное O(1), а не строгое?**
   - Подготовьте ответ с примером из production или практики.

## Практика

- [ ] Решите и объясните LRU cache, merge intervals, top K frequent, course schedule и number of islands на Go.
- [ ] Сформулируйте три частые ошибки по модулю и признаки их проявления.
- [ ] Добавьте в личные карточки определения и решения, которые не удалось воспроизвести без подсказки.

## Связанные темы

[[index|Главная]] · [[course/02-go|Go]] · [[course/05-postgresql|PostgreSQL]] · [[course/08-system-design|System Design]] · [[course/15-interview-practice|Интервью-практика]]

## Источники

- Официальная документация используемого языка, БД или платформы.
- Production-документация команды и проверенные технические разборы.
- Конкретные ссылки добавляйте при наполнении темы, вместе с датой проверки актуальности.
