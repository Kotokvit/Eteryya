# 🗺 КАРТА ТЕХНОЛОГИЙ GOOGLE: ОТКРЫТЫЕ ИСХОДНИКИ, СТАТЬИ И OPEN-SOURCE ФОРКИ

---

## 1. СТРАТЕГИЯ GOOGLE: «ПУБЛИКУЕМ НАУЧНУЮ СТАТЬЮ — МИР ПИШЕТ OPEN SOURCE»

Google редко выкладывает внутренний код своих боевых серверов (он написан под их проприетарную инфраструктуру `Borg` и `Monorepo`). 

Вместо этого Google публикует **фундаментальные научные статьи (Whitepapers)** с подробнейшим описанием архитектуры, алгоритмов и структур данных. На основе этих статей сообщество создало открытый стек мирового уровня:

```
    ТЕХНОЛОГИЯ GOOGLE (СТАТЬЯ)          ПРЯМОЙ OPEN SOURCE АНАЛОГ (ИСХОДНЫЙ КОД)
 ┌───────────────────────────────┐     ┌────────────────────────────────────────┐
 │ 1. Google File System (GFS)   │ ──► │ Apache Hadoop HDFS (Java) / MooseFS   │
 │ 2. MapReduce (2004)           │ ──► │ Apache Hadoop MapReduce / Apache Spark │
 │ 3. Bigtable (2006)            │ ──► │ Apache HBase / Apache Cassandra / Scylla│
 │ 4. Percolator (2010, Realtime)│ ──► │ TiKV / TiDB (написан на чистом Rust!) │
 │ 5. Spanner (2012, TrueTime)   │ ──► │ CockroachDB (Go) / YugabyteDB          │
 │ 6. Dremel (2010, Interactive) │ ──► │ Apache Drill / ClickHouse              │
 │ 7. Borg (Оркестрация)         │ ──► │ Kubernetes (K8s) — Полностью открыт!   │
 └───────────────────────────────┘     └────────────────────────────────────────┘
```

---

## 2. ГДЕ ПОСМОТРЕТЬ ИСХОДНИКИ И СТАТЬИ (ПРЯМЫЕ ССЫЛКИ):

### А. Официальные исходники самого Google (100% Open Source):
1. **Chromium (Краулинг и браузерный движок):**
   * Репозиторий: `https://github.com/chromium/chromium`
2. **Kubernetes (Borg нового поколения):**
   * Репозиторий: `https://github.com/kubernetes/kubernetes`
3. **Snappy & LevelDB (Движки сжатия и локального B-Tree хранения):**
   * LevelDB (основа Bigtable): `https://github.com/google/leveldb`
   * Snappy (алгоритм сжатия на лету): `https://github.com/google/snappy`
4. **gRPC & Protocol Buffers (Сетевая шина Google):**
   * Репозиторий: `https://github.com/grpc/grpc`
   * Репозиторий: `https://github.com/protocolbuffers/protobuf`

---

### Б. Открытые поисковые движки на тех же принципах (Inverted Index + Top-K):
1. **Tantivy (Поисковый движок на чистом RUST — «Rust Lucene»):**
   * Делает ровно то же: стриминг `mmap`, SIMD-декомпрессия и бинарные кучи Top-K.
   * Репозиторий: `https://github.com/quickwit-oss/tantivy`
2. **TiKV (Открытая реализация Google Percolator + Spanner на Rust):**
   * Распределенная транзакционная база с транзакциями Percolator.
   * Репозиторий: `https://github.com/tikv/tikv`

---

### В. Легендарные научные статьи Google (Google Research Papers):
* **GFS (2003):** `https://research.google/pubs/the-google-file-system/`
* **MapReduce (2004):** `https://research.google/pubs/mapreduce-simplified-data-processing-on-large-clusters/`
* **Bigtable (2006):** `https://research.google/pubs/bigtable-a-distributed-storage-system-for-structured-data/`
* **Percolator (2010):** `https://research.google/pubs/large-scale-incremental-computation-using-distributed-transactions-and-notifications/`
* **Spanner (2012):** `https://research.google/pubs/spanner-googles-globally-distributed-database/`
