-- ============================================================
-- Spotify — analysis
-- 15 questions, basic aggregation through window functions
-- ============================================================


-- ============================================================
-- BASIC AGGREGATION
-- ============================================================


-- ------------------------------------------------------------
-- Q1. Tracks with more than 1 billion streams.
-- ------------------------------------------------------------
SELECT artist,
       track,
       stream
FROM spotify
WHERE stream > 1000000000
ORDER BY stream DESC;


-- ------------------------------------------------------------
-- Q2. All albums with their artists.
-- ------------------------------------------------------------
SELECT DISTINCT album,
       artist
FROM spotify
ORDER BY artist, album;


-- ------------------------------------------------------------
-- Q3. Total comments on licensed tracks.
--     licensed is BOOLEAN, so compare against TRUE rather
--     than the string 'true'. Postgres will coerce the string,
--     but the boolean form states the intent.
-- ------------------------------------------------------------
SELECT SUM(comments) AS total_comments
FROM spotify
WHERE licensed = TRUE;


-- ------------------------------------------------------------
-- Q4. Tracks released as singles.
-- ------------------------------------------------------------
SELECT artist,
       track,
       album_type
FROM spotify
WHERE album_type = 'single'
ORDER BY artist;


-- ------------------------------------------------------------
-- Q5. Track count per artist, most prolific first.
-- ------------------------------------------------------------
SELECT artist,
       COUNT(*) AS total_tracks
FROM spotify
GROUP BY artist
ORDER BY total_tracks DESC;


-- ============================================================
-- GROUPED ANALYSIS
-- ============================================================


-- ------------------------------------------------------------
-- Q6. Average danceability per album.
-- ------------------------------------------------------------
SELECT album,
       ROUND(AVG(danceability)::NUMERIC, 3) AS avg_danceability
FROM spotify
GROUP BY album
ORDER BY avg_danceability DESC;


-- ------------------------------------------------------------
-- Q7. The five highest-energy tracks.
--     No GROUP BY needed — energy is a per-row attribute, so
--     ordering the rows directly is both simpler and correct.
--     Grouping by track would silently merge different songs
--     that happen to share a title.
-- ------------------------------------------------------------
SELECT artist,
       track,
       energy
FROM spotify
ORDER BY energy DESC
LIMIT 5;


-- ------------------------------------------------------------
-- Q8. Views and likes for tracks with an official video.
-- ------------------------------------------------------------
SELECT artist,
       track,
       views,
       likes
FROM spotify
WHERE official_video = TRUE
ORDER BY views DESC;


-- ------------------------------------------------------------
-- Q9. Total views per album.
--     Grouping by album alone. Adding track to the GROUP BY
--     would return per-track totals, which is a different
--     question.
-- ------------------------------------------------------------
SELECT album,
       SUM(views) AS total_views,
       COUNT(*)   AS track_count
FROM spotify
GROUP BY album
ORDER BY total_views DESC;


-- ------------------------------------------------------------
-- Q10. Tracks streamed more on Spotify than on YouTube.
--
--      Conditional aggregation pivots most_played_on from
--      rows into columns. COALESCE turns the NULL that SUM
--      returns over an empty set into 0, so the comparison
--      works on every row.
--
--      Note: most_played_on holds one value per row, so both
--      columns are only non-zero where the same track appears
--      more than once in the table.
-- ------------------------------------------------------------
SELECT *
FROM (
    SELECT track,
           COALESCE(SUM(CASE WHEN most_played_on = 'Youtube' THEN stream END), 0)
               AS streamed_on_youtube,
           COALESCE(SUM(CASE WHEN most_played_on = 'Spotify' THEN stream END), 0)
               AS streamed_on_spotify
    FROM spotify
    GROUP BY track
) AS t
WHERE streamed_on_spotify > streamed_on_youtube
  AND streamed_on_youtube <> 0
ORDER BY streamed_on_spotify DESC;


-- ============================================================
-- WINDOW FUNCTIONS AND CTEs
-- ============================================================


-- ------------------------------------------------------------
-- Q11. Top 3 most-viewed tracks per artist.
--
--      DENSE_RANK rather than ROW_NUMBER: tied view counts
--      should share a position rather than being separated
--      arbitrarily.
--
--      The rank has to be computed in a CTE because window
--      functions cannot appear in a WHERE clause — WHERE runs
--      before the window is evaluated.
-- ------------------------------------------------------------
WITH ranked_tracks AS (
    SELECT artist,
           track,
           SUM(views) AS total_views,
           DENSE_RANK() OVER (
               PARTITION BY artist
               ORDER BY SUM(views) DESC
           ) AS view_rank
    FROM spotify
    GROUP BY artist, track
)
SELECT artist,
       track,
       total_views,
       view_rank
FROM ranked_tracks
WHERE view_rank <= 3
ORDER BY artist, view_rank;


-- ------------------------------------------------------------
-- Q12. Tracks with above-average liveness.
--      The scalar subquery is evaluated once, not per row.
-- ------------------------------------------------------------
SELECT artist,
       track,
       liveness
FROM spotify
WHERE liveness > (SELECT AVG(liveness) FROM spotify)
ORDER BY liveness DESC;


-- ------------------------------------------------------------
-- Q13. Energy range within each album.
-- ------------------------------------------------------------
WITH album_energy AS (
    SELECT album,
           MAX(energy) AS highest_energy,
           MIN(energy) AS lowest_energy
    FROM spotify
    GROUP BY album
)
SELECT album,
       highest_energy,
       lowest_energy,
       highest_energy - lowest_energy AS energy_range
FROM album_energy
ORDER BY energy_range DESC;


-- ------------------------------------------------------------
-- Q14. Tracks with an energy-to-liveness ratio above 1.2.
--
--      NULLIF guards the division: where liveness is 0 it
--      returns NULL instead of raising a division-by-zero
--      error, and the NULL then fails the comparison rather
--      than aborting the query.
-- ------------------------------------------------------------
SELECT artist,
       track,
       energy,
       liveness,
       ROUND((energy / NULLIF(liveness, 0))::NUMERIC, 2) AS energy_liveness_ratio
FROM spotify
WHERE energy / NULLIF(liveness, 0) > 1.2
ORDER BY energy_liveness_ratio DESC;


-- ------------------------------------------------------------
-- Q15. Cumulative likes, ordered by views.
--
--      A running total: each row carries the sum of its own
--      likes plus every row before it in view order. The frame
--      clause is stated explicitly rather than relying on the
--      default, which changes behaviour when ties are present.
-- ------------------------------------------------------------
SELECT artist,
       track,
       views,
       likes,
       SUM(likes) OVER (
           ORDER BY views DESC
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS cumulative_likes
FROM spotify
ORDER BY views DESC;
