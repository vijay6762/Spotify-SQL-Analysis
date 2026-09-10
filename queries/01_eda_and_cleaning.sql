-- ============================================================
-- Spotify — exploratory profiling and cleaning
-- ============================================================


-- ------------------------------------------------------------
-- Size and cardinality
-- ------------------------------------------------------------
SELECT COUNT(*)                AS total_tracks   FROM spotify;
SELECT COUNT(DISTINCT artist)  AS total_artists  FROM spotify;
SELECT COUNT(DISTINCT album)   AS total_albums   FROM spotify;


-- ------------------------------------------------------------
-- Categorical columns — check the value sets before relying
-- on them in WHERE clauses. Cheap, and catches casing or
-- whitespace problems early.
-- ------------------------------------------------------------
SELECT DISTINCT album_type     FROM spotify;
SELECT DISTINCT most_played_on FROM spotify;
SELECT DISTINCT channel        FROM spotify ORDER BY 1;


-- ------------------------------------------------------------
-- Duration range
-- ------------------------------------------------------------
SELECT MIN(duration_min) AS shortest,
       MAX(duration_min) AS longest,
       AVG(duration_min) AS mean_duration
FROM spotify;


-- ------------------------------------------------------------
-- Data quality: zero-duration tracks
--
-- A track cannot be zero minutes long, so these are ingest
-- failures rather than unusual records. Left in place they
-- would drag down any duration average and show up as
-- spurious outliers.
--
-- Inspect before deleting.
-- ------------------------------------------------------------
SELECT artist, track, album, duration_min
FROM spotify
WHERE duration_min = 0;

DELETE FROM spotify
WHERE duration_min = 0;

-- Confirm the deletion
SELECT COUNT(*) AS remaining_zero_duration
FROM spotify
WHERE duration_min = 0;
