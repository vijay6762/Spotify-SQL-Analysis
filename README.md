# Spotify SQL Analysis

Fifteen business questions answered on a 24-column Spotify track dataset in PostgreSQL,
plus an execution-plan tuning exercise that cut a slow artist lookup from ~8 ms to well
under 1 ms.

**Stack:** PostgreSQL 16 · pgAdmin 4

---

## The dataset

A single wide, denormalised table — one row per track, 24 columns spanning three different
kinds of information:

| Group | Columns |
|---|---|
| Identity | `artist`, `track`, `album`, `album_type`, `title`, `channel` |
| Audio features | `danceability`, `energy`, `loudness`, `speechiness`, `acousticness`, `instrumentalness`, `liveness`, `valence`, `tempo`, `duration_min`, `energy_liveness` |
| Engagement | `views`, `likes`, `comments`, `stream`, `licensed`, `official_video`, `most_played_on` |

Denormalised by design, which makes it the opposite problem from a normalised schema: no
joins are needed, but the table is wide enough that scan cost and column selection start to
matter. That's what makes the optimisation section worth doing here.

---

## Repository

```
├── schema/
│   └── schema.sql                  # table definition
└── queries/
    ├── 01_eda_and_cleaning.sql     # profiling, zero-duration removal
    ├── 02_analysis.sql             # 15 questions, easy to advanced
    └── 03_query_optimisation.sql   # EXPLAIN ANALYZE, indexing
```

---

## Cleaning

Profiling surfaced one real data-quality problem: tracks with `duration_min = 0`. A track
cannot have zero length, so these are ingest failures rather than unusual records. They were
identified, inspected, then deleted — left in place they would drag down any average involving
duration and appear as spurious outliers in distribution work.

```sql
SELECT * FROM spotify WHERE duration_min = 0;   -- inspect first
DELETE FROM spotify WHERE duration_min = 0;     -- then remove
```

---

## Questions answered

**Basic aggregation (Q1–Q5)** — tracks past a billion streams, album/artist listings, comment
totals filtered on a boolean, singles, track counts per artist.

**Grouped analysis (Q6–Q10)** — average danceability per album, highest-energy tracks, views
and likes on official videos, total views per album, and a conditional-aggregation pivot
comparing Spotify streams against YouTube.

**Window functions and CTEs (Q11–Q15)**

| # | Question | Technique |
|---|---|---|
| 11 | Top 3 most-viewed tracks per artist | `DENSE_RANK() OVER (PARTITION BY ...)` in a CTE |
| 12 | Tracks with above-average liveness | Scalar subquery in `WHERE` |
| 13 | Energy range per album | `WITH` clause, `MAX − MIN` |
| 14 | Tracks with an energy-to-liveness ratio above 1.2 | `NULLIF` guard against divide-by-zero |
| 15 | Cumulative likes ordered by views | `SUM() OVER (ORDER BY ... ROWS UNBOUNDED PRECEDING)` |

---

## Query optimisation

The part of this project worth reading.

A lookup filtering on `artist` and `most_played_on`, sorted by streams:

```sql
SELECT artist, track, views
FROM spotify
WHERE artist = 'Gorillaz' AND most_played_on = 'Youtube'
ORDER BY stream DESC
LIMIT 25;
```

**Before.** `EXPLAIN ANALYZE` showed a sequential scan — Postgres reading every row in the
table to find the handful matching one artist, then sorting them.

| | Planning time | Execution time |
|---|---|---|
| Before index | 0.112 ms | 7.97 ms |
| After B-tree index on `artist` | *[re-run and record]* | *[re-run and record]* |

**The fix.**

```sql
CREATE INDEX artist_index ON spotify (artist);
```

`artist` is high-cardinality and highly selective — one artist is a tiny fraction of the table
— which is exactly the condition under which a B-tree index pays off. The planner switches
from a sequential scan to an index scan and stops reading rows it will never return.

**Why not index `most_played_on` too.** It holds a handful of distinct values, so any single
value matches a large share of the table. Below roughly 5–10% selectivity the planner ignores
the index and scans anyway, because random I/O across scattered pages costs more than reading
sequentially. An index there would add write overhead for no read benefit.

---

## Running it

```bash
createdb spotify
psql -d spotify -f schema/schema.sql
```

Load the dataset, then run the query files in order. In pgAdmin 4, open each file and execute
the sections individually.

---

## Notes

Ordering in the analysis file is by question difficulty rather than by topic, following the
structure of the original problem set — basic aggregation first, then grouping, then window
functions.

## Contact

**Vijay Chandra Vaddepally** — Data Analyst, Hyderabad
[LinkedIn](https://www.linkedin.com/in/vijay-vaddepally/) · [Portfolio](https://www.datascienceportfol.io/vijaychandra1103) · vijaychandra1103@gmail.com
