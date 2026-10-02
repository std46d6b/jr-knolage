# Курс подготовки к техническому интервью — Middle Go Developer (E4+)

> **Цель:** системно закрыть темы, которые проверяют на собеседованиях Go-разработчика уровня strong middle / E4 и выше: от языка и алгоритмов до проектирования, production-эксплуатации и коммуникации.
>
> **Как использовать дерево:** каждый узел будущей базы знаний — отдельная страница или папка. Для каждой темы стоит добавить: краткую теорию, типовые вопросы, практические задачи, частые ошибки, ссылки на первоисточники и карточки для повторения.

---

## 0. Карта курса и порядок изучения

```text
Подготовка к интервью Go E4+
├── 1. База разработки и Computer Science
├── 2. Go: язык, runtime и стандартная библиотека
├── 3. Проектирование Go-приложений
├── 4. Алгоритмы и структуры данных
├── 5. SQL и PostgreSQL
├── 6. NoSQL, кэш и поиск
├── 7. Распределённые системы и интеграции
├── 8. System Design
├── 9. Инфраструктура, Linux и сети
├── 10. Observability, monitoring и incident response
├── 11. Безопасность
├── 12. Тестирование и качество
├── 13. Delivery: Git, CI/CD, Docker, Kubernetes
├── 14. Архитектура, продукт и engineering practices
├── 15. Интервью-практика и поведенческая часть
└── 16. Траектории углубления для senior-границы
```

**Рекомендуемые этапы:**

1. Закрыть фундамент: `1 → 2 → 4 → 5`.
2. Научиться писать и сопровождать production-сервисы: `3 → 7 → 10 → 12 → 13`.
3. Тренировать проектирование: `6 → 8 → 9 → 11 → 14`.
4. Параллельно с первого дня решать задачи и проводить mock-интервью: `15`.
5. Для вакансий с ожиданиями выше E4 целенаправленно пройти `16`.

---

# 1. База разработки и Computer Science

```text
1. База разработки и Computer Science
├── 1.1. Модель вычислений и ОС
│   ├── Процессы, потоки, coroutine / goroutine
│   ├── Контекст-переключение и планирование CPU
│   ├── Виртуальная память: page, stack, heap, mmap
│   ├── Сегментация, paging, page fault, copy-on-write
│   ├── Файловые дескрипторы, stdin/stdout/stderr
│   ├── Сигналы Unix
│   ├── IPC: pipe, socket, shared memory
│   └── Syscall: стоимость, блокировки, границы user/kernel space
├── 1.2. Память и производительность
│   ├── Big O: time / space complexity
│   ├── Амортизированная сложность
│   ├── CPU cache: locality, cache line, false sharing
│   ├── Allocation rate и pressure на GC
│   ├── Профилирование CPU, памяти, блокировок
│   └── Throughput, latency, tail latency (p95/p99)
├── 1.3. Базовые принципы проектирования
│   ├── Separation of concerns
│   ├── Cohesion и coupling
│   ├── Composition over inheritance
│   ├── SOLID: практическое применение и границы
│   ├── DRY, KISS, YAGNI
│   ├── Dependency inversion и dependency injection
│   └── Trade-offs вместо «единственно правильной» архитектуры
└── 1.4. HTTP и Web-основы
    ├── HTTP request/response, headers, status codes
    ├── HTTP/1.1: keep-alive, connection reuse, chunked transfer
    ├── HTTP/2: multiplexing, streams, HPACK — концептуально
    ├── HTTP/3 и QUIC — назначение и отличия
    ├── REST: ресурсы, идемпотентность, пагинация, фильтрация
    ├── RPC и gRPC: когда выбирать
    ├── WebSocket, SSE, long polling
    ├── Cookies, sessions, CORS, CSRF
    └── API versioning и совместимость контрактов
```

# 2. Go: язык, runtime и стандартная библиотека

```text
2. Go: язык, runtime и стандартная библиотека
├── 2.1. Основы языка
│   ├── Packages, imports, visibility и naming
│   ├── Переменные, zero values, constants, iota
│   ├── Базовые типы, conversions, overflow
│   ├── Arrays, slices, maps, strings
│   ├── Struct, embedded fields, tags
│   ├── Functions, multiple returns, named results
│   ├── Variadic functions
│   ├── Pointers: когда нужны и когда нет
│   ├── Value semantics vs reference-like semantics
│   ├── Methods: value receiver vs pointer receiver
│   ├── Interfaces: implicit implementation, nil interface pitfall
│   ├── Type assertion, type switch, custom types
│   ├── Generics: type parameters, constraints, limitations
│   ├── defer: порядок выполнения, capture arguments, цена
│   ├── panic / recover: допустимые сценарии и анти-паттерны
│   └── errors: wrapping, errors.Is/As, sentinel vs typed errors
├── 2.2. Коллекции и работа с данными
│   ├── Slice internals: len, cap, append, reallocation
│   ├── Aliasing, memory retention и full slice expression
│   ├── Copying slices и structs
│   ├── Map internals на концептуальном уровне
│   ├── Ограничения maps: non-addressable elements, iteration order
│   ├── Concurrent map access и способы синхронизации
│   ├── Strings: UTF-8, bytes vs runes, indexing
│   ├── bytes.Buffer, strings.Builder
│   ├── JSON: encoding/json, tags, omitempty, custom marshal/unmarshal
│   ├── XML / CSV / base64 — по необходимости вакансии
│   └── Time: time.Time, monotonic clock, duration, timezone
├── 2.3. Concurrency
│   ├── Goroutine lifecycle
│   ├── GOMAXPROCS и scheduler model (G-M-P)
│   ├── Channels: unbuffered и buffered
│   ├── Send/receive, close, receive from closed channel
│   ├── Направленные каналы
│   ├── select: blocking, default, fairness, nil channels
│   ├── Ownership каналов: кто создаёт и закрывает
│   ├── sync.Mutex / RWMutex
│   ├── sync.WaitGroup: корректный жизненный цикл
│   ├── sync.Once, Cond, Pool, Map
│   ├── atomic operations и memory ordering на прикладном уровне
│   ├── Race condition, deadlock, livelock, starvation
│   ├── Data race и Go race detector
│   ├── Fan-out / fan-in
│   ├── Worker pool
│   ├── Pipeline и cancellation
│   ├── Semaphore и rate limiting
│   ├── Graceful shutdown
│   └── Типовые concurrency-задачи на интервью
├── 2.4. Context и управление жизненным циклом
│   ├── context.Context: назначение и правила передачи
│   ├── WithCancel, WithTimeout, WithDeadline, WithCancelCause
│   ├── Cancellation propagation
│   ├── Deadline budget в цепочке вызовов
│   ├── Context values: допустимые случаи и анти-паттерны
│   ├── Утечки goroutines и ресурсов
│   └── Shutdown HTTP/gRPC consumers и фоновых воркеров
├── 2.5. Go runtime и memory management
│   ├── Stack growth
│   ├── Escape analysis
│   ├── Heap allocations
│   ├── Garbage collector: tri-color marking, concurrent GC — концептуально
│   ├── GC pacing, GOGC, memory limit — назначение
│   ├── Stop-the-world pauses
│   ├── Finalizers: почему почти всегда не нужны
│   ├── unsafe: границы допустимого использования
│   └── cgo: стоимость, риски, когда оправдан
├── 2.6. Стандартная библиотека и практический Go
│   ├── net/http: Server, Handler, middleware
│   ├── http.Client: timeout, Transport, connection pool
│   ├── database/sql: pool, context, ошибки
│   ├── io: Reader, Writer, Closer и композиция интерфейсов
│   ├── os, filepath, fs
│   ├── encoding, crypto, compress
│   ├── log/slog: structured logging
│   ├── flag / env configuration
│   └── testing package
├── 2.7. Инструменты Go
│   ├── go mod: modules, versions, replace, vendor
│   ├── Semantic Import Versioning
│   ├── gofmt, goimports, go vet
│   ├── staticcheck и линтеры
│   ├── go test: package, cache, -race, -count, -run
│   ├── go test -bench, benchmem
│   ├── pprof: CPU, heap, goroutine, mutex, block profiles
│   ├── trace: scheduler, blocking, GC
│   ├── go tool compile -m: escape analysis
│   └── Delve debugger
└── 2.8. Go-код на интервью
    ├── Чтение и объяснение существующего кода
    ├── Рефакторинг без изменения поведения
    ├── Обработка ошибок и observability
    ├── Контракты интерфейсов и mockability
    ├── Публичный API пакета
    ├── Code review: race, leaks, nil, error handling
    └── Idiomatic Go vs преждевременная абстракция
```

# 3. Проектирование Go-приложений

```text
3. Проектирование Go-приложений
├── 3.1. Структура репозитория
│   ├── cmd/, internal/, pkg/ и их смысл
│   ├── Монолит, modular monolith, микросервисы
│   ├── Организация по слоям vs по фичам
│   ├── Границы пакетов и циклические зависимости
│   └── Конфигурация приложения
├── 3.2. Application architecture
│   ├── Clean Architecture / Hexagonal / Ports & Adapters
│   ├── Domain, application, infrastructure, delivery layers
│   ├── Use cases / services
│   ├── Repository pattern: польза и злоупотребления
│   ├── Unit of Work и транзакционные границы
│   ├── DTO, domain model, persistence model
│   ├── Dependency injection вручную
│   └── Composition root
├── 3.3. API и transport layer
│   ├── HTTP routing и middleware chain
│   ├── Request validation
│   ├── Error model и mapping ошибок в HTTP/gRPC
│   ├── Correlation / request ID
│   ├── Authentication и authorization boundaries
│   ├── Pagination: offset, cursor, keyset
│   ├── Idempotency keys
│   ├── Backward compatibility
│   └── OpenAPI / Protobuf contract-first development
├── 3.4. Фоновые задачи
│   ├── Job queue и worker model
│   ├── At-most-once, at-least-once, exactly-once как недостижимая гарантия end-to-end
│   ├── Retry, exponential backoff, jitter
│   ├── Dead-letter queue
│   ├── Idempotent consumer
│   ├── Scheduled jobs и distributed locks
│   └── Backpressure
└── 3.5. Конфигурация и twelve-factor app
    ├── Environment variables и config files
    ├── Secrets management
    ├── Feature flags
    ├── Runtime configuration vs deploy configuration
    └── Stateless processes
```

# 4. Алгоритмы и структуры данных

```text
4. Алгоритмы и структуры данных
├── 4.1. Техника решения задач
│   ├── Уточнение условия и примеры
│   ├── Brute force → оптимизация
│   ├── Оценка времени и памяти
│   ├── Проверка edge cases
│   ├── Объяснение решения во время кодинга
│   └── Тестирование на примерах
├── 4.2. Линейные структуры
│   ├── Array / slice
│   ├── String и two pointers
│   ├── Linked list
│   ├── Stack
│   ├── Queue / deque
│   ├── Hash table / set
│   ├── Prefix sums
│   ├── Sliding window
│   └── Monotonic stack / queue
├── 4.3. Trees и heaps
│   ├── Binary tree traversals: DFS/BFS
│   ├── Binary search tree
│   ├── Balanced tree — концептуально
│   ├── Trie
│   ├── Heap / priority queue
│   ├── Top K problems
│   └── Interval problems
├── 4.4. Поиск и сортировка
│   ├── Binary search и search on answer
│   ├── Quicksort, mergesort, heapsort — идея и сложности
│   ├── Stable vs unstable sort
│   ├── Sorting in Go: slices.SortFunc
│   └── Selection algorithms
├── 4.5. Graphs
│   ├── Представления графа
│   ├── BFS / DFS
│   ├── Connected components
│   ├── Topological sort
│   ├── Shortest path: Dijkstra, Bellman-Ford — когда применять
│   ├── Union-Find / DSU
│   ├── Cycle detection
│   └── Minimum spanning tree — обзорно
├── 4.6. Dynamic programming и backtracking
│   ├── Memoization / tabulation
│   ├── 1D и 2D DP
│   ├── Knapsack family
│   ├── Subsequences / strings DP
│   ├── Tree DP — базово
│   ├── Backtracking: permutations, combinations, subsets
│   └── Когда DP не нужен
└── 4.7. Набор обязательных паттернов
    ├── Two sum / frequency map
    ├── LRU cache
    ├── Producer-consumer
    ├── Merge intervals
    ├── K-way merge
    ├── Rate limiter
    ├── Consistent hashing — задача на дизайн
    └── Concurrent-safe cache
```

# 5. SQL и PostgreSQL

```text
5. SQL и PostgreSQL
├── 5.1. Реляционная модель и SQL
│   ├── Таблицы, строки, типы данных
│   ├── Primary / foreign / unique keys
│   ├── Normal forms: 1NF–3NF, денормализация
│   ├── DDL / DML / DCL / TCL
│   ├── SELECT, WHERE, ORDER BY, LIMIT
│   ├── JOIN: inner, left, right, full, cross
│   ├── GROUP BY, HAVING, aggregate functions
│   ├── Subqueries, CTE, recursive CTE
│   ├── Window functions
│   ├── UNION / INTERSECT / EXCEPT
│   ├── NULL: three-valued logic, COALESCE, IS DISTINCT FROM
│   ├── CASE
│   └── SQL injection и parameterized queries
├── 5.2. PostgreSQL internals
│   ├── Архитектура: processes, shared buffers, WAL
│   ├── MVCC: tuple versions, xmin/xmax — концептуально
│   ├── VACUUM, autovacuum, ANALYZE
│   ├── Transaction ID wraparound — причины и профилактика
│   ├── WAL, checkpoints, crash recovery
│   ├── Tablespaces — обзорно
│   ├── TOAST
│   └── System catalogs и pg_stat_* views
├── 5.3. Transactions и concurrency control
│   ├── ACID
│   ├── BEGIN / COMMIT / ROLLBACK
│   ├── Isolation levels: Read Committed, Repeatable Read, Serializable
│   ├── Dirty / non-repeatable / phantom reads
│   ├── Serializable Snapshot Isolation — концептуально
│   ├── Locks: row, table, advisory
│   ├── SELECT FOR UPDATE / NO KEY UPDATE / SKIP LOCKED
│   ├── Deadlocks: причины, диагностика, порядок блокировок
│   ├── Long-running transactions
│   └── Optimistic vs pessimistic locking
├── 5.4. Индексы и оптимизация запросов
│   ├── B-tree: default use cases
│   ├── Hash, GIN, GiST, BRIN
│   ├── Composite index и leftmost-prefix rule
│   ├── Partial indexes
│   ├── Covering indexes / INCLUDE
│   ├── Expression indexes
│   ├── Selectivity и cardinality
│   ├── EXPLAIN / EXPLAIN ANALYZE
│   ├── Seq scan, index scan, bitmap heap scan
│   ├── Join algorithms: nested loop, hash join, merge join
│   ├── Sort, work_mem и disk spill
│   ├── N+1 queries
│   └── Query rewrite и измерение результата
├── 5.5. Schema design и migrations
│   ├── Выбор типов: bigint, uuid, numeric, jsonb, timestamptz
│   ├── Natural vs surrogate keys
│   ├── Soft delete
│   ├── Audit fields и temporal data
│   ├── Constraints как слой целостности
│   ├── Миграции: up/down, versioning, порядок rollout
│   ├── Backward-compatible migrations
│   ├── Expand-contract migration pattern
│   ├── Large-table migrations без долгих lock
│   └── Data backfill
├── 5.6. PostgreSQL в production
│   ├── Connection limits и connection pooling
│   ├── pgBouncer: transaction/session pooling
│   ├── database/sql pool: MaxOpenConns, MaxIdleConns, lifetime
│   ├── Timeouts: statement, lock, idle transaction
│   ├── Репликация: streaming, replication lag
│   ├── Read replicas и read-after-write consistency
│   ├── Backup: logical vs physical, PITR
│   ├── Restore drills
│   ├── Partitioning: range/list/hash
│   ├── Retention и архивирование
│   ├── Мониторинг slow queries, locks, bloat
│   └── Высокая доступность — концептуально
└── 5.7. Go + PostgreSQL
    ├── database/sql lifecycle
    ├── pgx: особенности и преимущества
    ├── Context cancellation в запросах
    ├── Правильное закрытие rows
    ├── sql.ErrNoRows и domain errors
    ├── Transactions в Go: defer rollback, commit error
    ├── Batch insert/update
    ├── Prepared statements: польза и caveats
    ├── Работа с JSONB, UUID, arrays, time zones
    └── Тесты с реальной БД и test containers
```

# 6. NoSQL, кэш и поиск

```text
6. NoSQL, кэш и поиск
├── 6.1. Выбор хранилища
│   ├── Реляционная БД vs key-value vs document vs wide-column vs graph
│   ├── Access patterns first
│   ├── CAP theorem и PACELC
│   ├── Consistency models
│   ├── Data model и query model
│   └── Цена operational complexity
├── 6.2. Redis
│   ├── Структуры данных: string, hash, list, set, zset, stream
│   ├── TTL, eviction policies, memory limits
│   ├── Cache-aside, read-through, write-through, write-behind
│   ├── Cache invalidation
│   ├── Cache stampede, penetration, avalanche
│   ├── Distributed locks: risks, fencing tokens
│   ├── Pub/Sub и Streams
│   ├── Persistence: RDB, AOF
│   ├── Replication, Sentinel, Cluster — обзорно
│   └── Redis monitoring
├── 6.3. Document и wide-column databases
│   ├── MongoDB: documents, indexes, replica sets, sharding — основы
│   ├── Cassandra/Scylla: partition key, clustering key, consistency — основы
│   ├── DynamoDB: partition key, sort key, GSI/LSI, capacity — основы
│   ├── Hot partition
│   └── Денормализация под запросы
├── 6.4. Search engines
│   ├── Elasticsearch/OpenSearch: inverted index
│   ├── Index, shard, replica
│   ├── Analyzer, tokenizer, mapping
│   ├── Full-text search, filters, relevance
│   ├── Pagination pitfalls: from/size vs search_after
│   ├── Eventual consistency индекса
│   └── Синхронизация primary DB → search index
└── 6.5. Практические сценарии
    ├── Проектирование кэша каталога / профиля / permissions
    ├── Rate limiting на Redis
    ├── Idempotency storage
    ├── Leaderboard на sorted sets
    └── Outbox-to-search indexing pipeline
```

# 7. Распределённые системы и интеграции

```text
7. Распределённые системы и интеграции
├── 7.1. Базовые свойства
│   ├── Частичные отказы
│   ├── Network partitions
│   ├── Clock skew и time synchronization
│   ├── Latency как часть API contract
│   ├── Consistency, availability, durability
│   ├── Coordination cost
│   └── Backpressure и load shedding
├── 7.2. Надёжная коммуникация сервисов
│   ├── Timeouts: connect/read/write/overall deadlines
│   ├── Retry: only safe failures
│   ├── Exponential backoff и jitter
│   ├── Retry budget
│   ├── Circuit breaker
│   ├── Bulkhead / isolation
│   ├── Hedged requests — риски
│   ├── Idempotency
│   ├── Deduplication
│   └── Rate limit и quotas
├── 7.3. Messaging
│   ├── Queue vs pub/sub
│   ├── Kafka: topics, partitions, offsets, consumer groups
│   ├── Kafka ordering scope
│   ├── Kafka delivery semantics
│   ├── Consumer rebalance
│   ├── Retention и compaction
│   ├── RabbitMQ: exchanges, queues, routing, ack/nack
│   ├── Retry queues и DLQ
│   ├── Schema evolution: Protobuf / Avro / JSON schema
│   └── Poison messages
├── 7.4. Согласованность данных
│   ├── Distributed transaction и почему 2PC редко используют
│   ├── Saga: choreography vs orchestration
│   ├── Compensating actions
│   ├── Transactional outbox
│   ├── Inbox pattern
│   ├── Change Data Capture (CDC)
│   ├── Event sourcing: назначение и цена
│   ├── CQRS: когда оправдан
│   └── Exactly-once: что реально можно гарантировать
├── 7.5. Service-to-service API
│   ├── REST vs gRPC vs async messaging
│   ├── Protobuf: fields, compatibility, reserved fields
│   ├── gRPC deadlines, status codes, interceptors
│   ├── Streaming RPC
│   ├── Service discovery
│   ├── Load balancing
│   └── Contract testing
└── 7.6. Resilience exercises
    ├── Падение зависимости
    ├── Дубликаты событий
    ├── Reordering событий
    ├── Consumer restart
    ├── Database failover
    ├── Частично выполненная операция
    └── Traffic spike
```

# 8. System Design

```text
8. System Design
├── 8.1. Методика ответа
│   ├── Уточнить функциональные и нефункциональные требования
│   ├── Оценить масштаб: RPS, DAU/MAU, payload, storage, growth
│   ├── Определить SLO: latency, availability, durability
│   ├── Нарисовать минимальную high-level архитектуру
│   ├── Выделить data model и API
│   ├── Найти bottlenecks и failure modes
│   ├── Объяснить trade-offs
│   └── Предложить этапы эволюции решения
├── 8.2. Базовые компоненты
│   ├── DNS, CDN, load balancer, reverse proxy
│   ├── API gateway / BFF
│   ├── Stateless application instances
│   ├── SQL DB, replicas, sharding
│   ├── Cache
│   ├── Object storage
│   ├── Message broker
│   ├── Search index
│   ├── Scheduler / worker fleet
│   ├── Service discovery / config
│   └── Observability stack
├── 8.3. Масштабирование данных
│   ├── Vertical vs horizontal scaling
│   ├── Replication
│   ├── Sharding и shard key
│   ├── Consistent hashing
│   ├── Rebalancing
│   ├── Hot keys / hot partitions
│   ├── Read/write splitting
│   ├── Partitioning и archival
│   └── Multi-region: active-passive / active-active
├── 8.4. Типовые design-задачи
│   ├── URL shortener
│   ├── Rate limiter
│   ├── Notification service
│   ├── Chat / realtime messaging
│   ├── News feed
│   ├── File upload and processing
│   ├── Payment/order workflow
│   ├── Booking system / inventory reservation
│   ├── Web crawler
│   ├── Metrics/log ingestion
│   ├── Search autocomplete
│   ├── Feature flag service
│   ├── Distributed task scheduler
│   └── API for high-load read-heavy catalog
└── 8.5. Критерии качества решения
    ├── Correctness
    ├── Scalability
    ├── Availability и graceful degradation
    ├── Consistency guarantees
    ├── Security и privacy
    ├── Operability
    ├── Cost awareness
    └── Simplicity и evolvability
```

# 9. Инфраструктура, Linux и сети

```text
9. Инфраструктура, Linux и сети
├── 9.1. Linux для разработчика
│   ├── Filesystem hierarchy и permissions
│   ├── Users, groups, sudo
│   ├── Processes, threads, signals
│   ├── systemd: service, logs, restart policy
│   ├── Environment variables
│   ├── ulimit и file descriptors
│   ├── Disk: df, du, inode exhaustion
│   ├── Memory: RSS, virtual memory, OOM killer
│   ├── CPU load average
│   └── Базовая диагностика: ps, top/htop, lsof, strace
├── 9.2. Сети
│   ├── OSI / TCP-IP model
│   ├── TCP handshake, retransmission, flow/congestion control
│   ├── UDP и QUIC: область применения
│   ├── IP, CIDR, routing, NAT
│   ├── DNS: records, TTL, caching, failure modes
│   ├── TLS: certificates, handshake, termination
│   ├── Proxy: forward/reverse, L4/L7 load balancing
│   ├── Firewall / security groups
│   ├── Connection exhaustion и ephemeral ports
│   └── Диагностика: curl, dig, ss, tcpdump
└── 9.3. Cloud-концепции
    ├── Compute, storage, managed DB, network
    ├── Availability zones и regions
    ├── IAM: principle of least privilege
    ├── Autoscaling
    ├── Managed service trade-offs
    ├── Cost drivers
    └── Disaster recovery: RPO/RTO
```

# 10. Observability, monitoring и incident response

```text
10. Observability, monitoring и incident response
├── 10.1. Основы observability
│   ├── Logs, metrics, traces: назначение и взаимосвязь
│   ├── Golden signals: latency, traffic, errors, saturation
│   ├── RED method и USE method
│   ├── Structured logging
│   ├── Correlation ID, trace ID, span ID
│   ├── Cardinality: польза и опасность
│   ├── Sampling
│   └── Privacy и редактирование PII/secrets в telemetry
├── 10.2. Metrics и Prometheus
│   ├── Pull model и scrape
│   ├── Counter, gauge, histogram, summary
│   ├── Buckets и histogram quantiles
│   ├── Labels и cardinality explosion
│   ├── PromQL: selectors, rates, aggregations, joins
│   ├── Recording rules
│   ├── Alert rules
│   ├── Alertmanager: routing, grouping, inhibition
│   ├── Service discovery
│   └── Go instrumentation: prometheus client
├── 10.3. Logging
│   ├── Уровни и структура событий
│   ├── Что логировать, а что не логировать
│   ├── Centralized logging (Loki / ELK / OpenSearch)
│   ├── Log retention и стоимость
│   ├── Поиск и агрегации
│   ├── Ошибки с context fields
│   └── Audit logs
├── 10.4. Distributed tracing
│   ├── OpenTelemetry: traces, metrics, logs
│   ├── Trace context propagation: HTTP, gRPC, messaging
│   ├── Spans и attributes
│   ├── Sampling strategies
│   ├── Jaeger / Tempo — концептуально
│   └── Поиск latency bottleneck по trace
├── 10.5. SRE-практики
│   ├── SLI, SLO, SLA
│   ├── Error budget
│   ├── Alert fatigue и actionable alerts
│   ├── Symptom-based vs cause-based alerting
│   ├── Runbook
│   ├── Incident lifecycle и роли
│   ├── Mitigation vs root cause fix
│   ├── Postmortem без поиска виноватых
│   └── Capacity planning
└── 10.6. Практическая диагностика Go-сервиса
    ├── Рост latency: p50 vs p99
    ├── Рост error rate
    ├── Memory leak / высокий allocation rate
    ├── Goroutine leak
    ├── Lock contention
    ├── DB connection pool exhaustion
    ├── Slow query
    ├── Kafka consumer lag
    ├── Cache hit-rate drop
    └── Dependency outage
```

# 11. Безопасность

```text
11. Безопасность
├── 11.1. Web/API security
│   ├── OWASP Top 10: обзор и прикладные примеры
│   ├── Authentication vs authorization
│   ├── Session, JWT, opaque token: trade-offs
│   ├── OAuth 2.0 / OpenID Connect: роли и flows
│   ├── Password storage: bcrypt/argon2, salts
│   ├── RBAC, ABAC, resource-level permissions
│   ├── CORS
│   ├── CSRF
│   ├── XSS: stored/reflected/DOM — даже для backend-разработчика
│   ├── SSRF
│   ├── Request validation и output encoding
│   ├── Rate limiting и abuse prevention
│   └── File upload security
├── 11.2. Data и infrastructure security
│   ├── TLS in transit, encryption at rest
│   ├── Secrets: vault, rotation, non-logging
│   ├── IAM и least privilege
│   ├── Network segmentation
│   ├── Dependency / supply-chain security
│   ├── Container image scanning
│   ├── Backups и доступ к ним
│   └── PII, retention, deletion
└── 11.3. Secure Go
    ├── crypto/rand vs math/rand
    ├── Проверка TLS certificates
    ├── SQL parameterization
    ├── Безопасная работа с URLs и redirects
    ├── Context-aware request limits
    ├── Resource exhaustion: body size, decompression, timeouts
    ├── gosec и dependency scanning
    └── Threat modeling для нового endpoint/service
```

# 12. Тестирование и качество

```text
12. Тестирование и качество
├── 12.1. Стратегия тестирования
│   ├── Test pyramid / testing trophy
│   ├── Unit, integration, contract, E2E tests
│   ├── Что тестировать на каждом уровне
│   ├── Deterministic tests
│   ├── Flaky tests: причины и лечение
│   └── Test data management
├── 12.2. Go testing
│   ├── Table-driven tests
│   ├── t.Run, t.Helper, t.Cleanup
│   ├── Parallel tests и shared state
│   ├── Error assertions
│   ├── Testify — плюсы и минусы
│   ├── Mock, stub, fake, spy: различия
│   ├── Генерация mocks и риск тестирования implementation details
│   ├── httptest
│   ├── TestMain
│   ├── Fuzzing
│   ├── Property-based testing — основы
│   ├── Benchmark tests
│   ├── Race detector
│   └── Coverage: что измеряет и чего не гарантирует
├── 12.3. Integration testing
│   ├── Реальный PostgreSQL/Redis/Kafka в тестах
│   ├── Testcontainers / Docker Compose для тестов
│   ├── Изоляция схемы и cleanup
│   ├── Миграции в тестовом окружении
│   ├── Contract testing для HTTP/gRPC/events
│   └── Consumer-driven contracts — обзорно
└── 12.4. Code review и maintainability
    ├── Readability и API design
    ├── Error handling
    ├── Concurrency safety
    ├── Resource cleanup
    ├── Security review
    ├── Performance review по измерениям
    ├── Обратная совместимость
    └── Технический долг: идентификация и приоритизация
```

# 13. Delivery: Git, CI/CD, Docker, Kubernetes

```text
13. Delivery: Git, CI/CD, Docker, Kubernetes
├── 13.1. Git
│   ├── Commit, branch, merge, rebase
│   ├── Merge conflicts
│   ├── Reset, revert, reflog
│   ├── Cherry-pick
│   ├── Conventional commits — если принято в команде
│   ├── Trunk-based development vs GitFlow
│   ├── Pull request workflow
│   └── Code ownership
├── 13.2. CI/CD
│   ├── Build, lint, test, security scan stages
│   ├── Artifact and image versioning
│   ├── Immutable artifacts
│   ├── Environment promotion
│   ├── Database migration в pipeline
│   ├── Rollback strategy
│   ├── Feature flags vs deployment
│   ├── Blue-green, canary, rolling deployment
│   └── Supply-chain provenance — обзорно
├── 13.3. Docker
│   ├── Image, container, layer, registry
│   ├── Dockerfile: multi-stage build for Go
│   ├── Кэш слоёв
│   ├── Minimal images и CA certificates
│   ├── Non-root user
│   ├── Environment, volumes, networks
│   ├── Healthcheck
│   ├── Docker Compose для локальной разработки
│   └── Диагностика контейнера
└── 13.4. Kubernetes
    ├── Cluster, node, pod
    ├── Deployment, StatefulSet, DaemonSet, Job, CronJob
    ├── Service, Ingress, Gateway — основы
    ├── ConfigMap, Secret
    ├── Requests, limits, QoS
    ├── Liveness, readiness, startup probes
    ├── HPA и cluster autoscaling — концептуально
    ├── Rolling update и rollback
    ├── Namespace, RBAC, NetworkPolicy
    ├── Persistent volumes — основы
    ├── Helm / Kustomize
    ├── kubectl: logs, describe, exec, events
    └── Типовые причины CrashLoopBackOff / Pending / 503
```

# 14. Архитектура, продукт и engineering practices

```text
14. Архитектура, продукт и engineering practices
├── 14.1. Архитектурные решения
│   ├── Monolith first и критерии выделения сервиса
│   ├── Modular monolith
│   ├── Microservices: выгоды и стоимость
│   ├── Domain-driven design: bounded context, ubiquitous language
│   ├── Anti-corruption layer
│   ├── ADR: фиксация решения и trade-offs
│   └── Управление техническим долгом
├── 14.2. Работа с требованиями
│   ├── Functional / non-functional requirements
│   ├── Уточняющие вопросы
│   ├── Acceptance criteria
│   ├── Edge cases и failure modes
│   ├── Оценка рисков и зависимостей
│   ├── Декомпозиция задач
│   └── Оценка сроков при неопределённости
├── 14.3. Продуктовое мышление
│   ├── Метрики продукта vs технические метрики
│   ├── Стоимость latency / errors для пользователя
│   ├── MVP и инкрементальная поставка
│   ├── Build vs buy
│   ├── Cost-performance trade-offs
│   └── Privacy и UX как ограничения дизайна
└── 14.4. Командная работа уровня E4+
    ├── Содержательный code review
    ├── Менторинг и knowledge sharing
    ├── Техническая коммуникация с product/QA/DevOps
    ├── Ownership компонента в production
    ├── Эскалация рисков
    ├── Несогласие с решением конструктивно
    └── Технические презентации и RFC
```

# 15. Интервью-практика и поведенческая часть

```text
15. Интервью-практика и поведенческая часть
├── 15.1. Форматы технических интервью
│   ├── Go language deep dive
│   ├── Live coding
│   ├── Algorithms
│   ├── SQL live task
│   ├── Debugging / code review
│   ├── System design
│   ├── Project deep dive
│   └── Hiring manager / behavioral interview
├── 15.2. Истории по STAR / CAR
│   ├── Сложная production-инцидент
│   ├── Оптимизация latency / стоимости
│   ├── Сложный технический выбор
│   ├── Ошибка и выводы
│   ├── Конфликт или несогласие
│   ├── Инициатива вне прямой задачи
│   ├── Менторинг / повышение уровня команды
│   ├── Проваленный проект или отменённое решение
│   └── Ownership от идеи до результата
├── 15.3. Разбор собственного опыта
│   ├── Архитектура каждого значимого проекта
│   ├── Масштабы: RPS, данные, команда, SLA
│   ├── Личный вклад, а не только вклад команды
│   ├── Самое трудное решение и trade-off
│   ├── Production проблемы и как диагностировали
│   ├── Метрики до/после
│   ├── Долг и что сделали для его уменьшения
│   └── Что бы изменили сейчас
├── 15.4. Практический режим
│   ├── Ежедневно: 1 алгоритмическая задача
│   ├── 2–3 раза в неделю: Go/concurrency задача
│   ├── 2 раза в неделю: SQL/PostgreSQL задача
│   ├── 1 раз в неделю: system design с таймером
│   ├── 1 раз в неделю: mock interview
│   ├── Ведение журнала ошибок
│   ├── Spaced repetition карточек
│   └── Ретроспектива слабых тем
└── 15.5. Чек-лист сильного ответа
    ├── Начать с требований и assumptions
    ├── Проговаривать ограничения
    ├── Называть альтернативы
    ├── Объяснять выбранный trade-off
    ├── Покрывать ошибки, observability и rollout
    ├── Не притворяться, что знаешь неизвестное
    └── Завершать кратким итогом решения
```

# 16. Траектории углубления для senior-границы

```text
16. Траектории углубления для senior-границы
├── 16.1. Highload backend
│   ├── Capacity modeling
│   ├── Queueing theory: Little's law — прикладной уровень
│   ├── Load testing и bottleneck analysis
│   ├── Multi-region design
│   ├── Cost optimization
│   └── Disaster recovery drills
├── 16.2. Platform / infrastructure
│   ├── Kubernetes internals
│   ├── Service mesh
│   ├── Infrastructure as Code (Terraform)
│   ├── GitOps
│   ├── Advanced networking
│   └── Internal developer platform
├── 16.3. Data-intensive systems
│   ├── CDC pipelines
│   ├── Stream processing
│   ├── Lakehouse / warehouse — основы
│   ├── Schema registry and governance
│   ├── Data quality
│   └── Data privacy
├── 16.4. Security-focused backend
│   ├── Threat modeling
│   ├── Identity and access systems
│   ├── Zero trust
│   ├── Secure SDLC
│   └── Incident response
└── 16.5. Техническое лидерство
    ├── RFC и architecture review
    ├── Roadmap технических улучшений
    ├── Cross-team dependencies
    ├── Стандарты и platform thinking
    ├── Менторинг
    └── Влияние без формальных полномочий
```

---

## Приоритеты для E4 / strong middle

| Приоритет                       | Темы                                                                                                                                                                                                                                       |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Обязательно**                 | Go core и concurrency, context, error handling, HTTP/gRPC, алгоритмические паттерны, SQL, PostgreSQL transactions/indexes/EXPLAIN, Redis, Docker, тестирование, Git, Linux/network basics, monitoring fundamentals, базовый system design. |
| **Нужно уверенно объяснять**    | Kafka/RabbitMQ semantics, retries/idempotency/outbox, Kubernetes fundamentals, profiling Go, SLO/alerting, security для API, schema migrations, distributed consistency trade-offs.                                                        |
| **Отличает сильного кандидата** | PostgreSQL internals и production tuning, tail latency и capacity, trace-based debugging, graceful degradation, multi-region trade-offs, RFC/ownership/incident stories.                                                                   |
| **Углублять под вакансию**      | Конкретный облачный провайдер, Kafka/ClickHouse/Elasticsearch, Kubernetes/Helm/Terraform, финансовые workflow, ML/data pipelines, безопасность.                                                                                            |

## Шаблон страницы будущей базы знаний

```markdown
# <Название темы>

## Зачем это на интервью

## Минимум для E4

## Углубление для E5/Senior

## Ключевые понятия

## Типовые вопросы и короткие ответы

## Практика

- Задача / лабораторная работа
- Разбор production-сценария
- Кодовая задача

## Частые ошибки и ловушки

## Связанные темы

## Источники

- Официальная документация
- Книга / статья / доклад
```

## Результат подготовки

К моменту интервью кандидат должен уметь:

1. Писать идиоматичный, безопасный по concurrency Go-код и объяснять поведение runtime.
2. Проектировать API и сервис с PostgreSQL, кэшем и асинхронной обработкой.
3. Диагностировать production-проблему через логи, метрики, трассировки и профили.
4. Обосновывать архитектурные решения числами, требованиями и trade-offs.
5. Решать базовые и средние алгоритмические задачи в ограниченное время.
6. Обсуждать реальный опыт как владелец компонента: результат, риски, инциденты и выводы.
