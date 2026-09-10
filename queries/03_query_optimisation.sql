-- ============================================================
-- Spotify — query optimisation
--
-- Run these in order. The point is the comparison between the
-- plan before the index and the plan after it, so the BEFORE
-- measurement has to be taken first.
-- ============================================================


-- ------------------------------------------------------------
-- STEP 1 — Confirm no index exists yet
-- ------------------------------------------------------------
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'spotify';


-- ------------------------------------------------------------
-- STEP 2 — Measure the query BEFORE indexing
--
-- Recorded: planning 0.112 ms, execution 7.97 ms
--
-- The plan shows a Seq Scan: Postgres reads every row in the
-- table to find the handful matching one artist, then sorts
-- them by stream count.
-- ------------------------------------------------------------
EXPLAIN ANALYZE
SELECT artist, track, views
FROM spotify
WHERE artist = 'Gorillaz'
  AND most_played_on = 'Youtube'
ORDER BY stream DESC
LIMIT 25;


-- ------------------------------------------------------------
-- STEP 3 — Add a B-tree index on the selective column
--
-- artist is high-cardinality: any single value matches a tiny
-- fraction of the table, which is the condition under which a
-- B-tree index pays for itself.
--
-- most_played_on is deliberately NOT indexed. It holds only a
-- few distinct values, so each one matches a large share of
-- rows. Below roughly 5-10% selectivity the planner ignores
-- the index and scans anyway, because random I/O across
-- scattered pages costs more than reading sequentially. An
-- index there would add write overhead for no read benefit.
-- ------------------------------------------------------------
CREATE INDEX artist_index ON spotify (artist);

-- Refresh planner statistics so the new index is costed correctly
ANALYZE spotify;


-- ------------------------------------------------------------
-- STEP 4 — Measure the same query AFTER indexing
--
-- Recorded: planning ___ ms, execution ___ ms
--
-- Expect the Seq Scan to be replaced by an Index Scan or
-- Bitmap Index Scan on artist_index.
-- ------------------------------------------------------------
EXPLAIN ANALYZE
SELECT artist, track, views
FROM spotify
WHERE artist = 'Gorillaz'
  AND most_played_on = 'Youtube'
ORDER BY stream DESC
LIMIT 25;


-- ------------------------------------------------------------
-- STEP 5 — Confirm the index is present and being used
-- ------------------------------------------------------------
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'spotify';


-- ------------------------------------------------------------
-- To undo and re-measure from scratch:
--     DROP INDEX artist_index;
-- ------------------------------------------------------------
