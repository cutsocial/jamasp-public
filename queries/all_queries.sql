-- ============================================================
-- Jamasp Pilot Study — BigQuery Analysis Queries
-- Project: jamasp-gcp-project | Dataset: jamasp_fitbit
-- Study window: 2025-02-25 to 2025-04-30
-- Project ID: M7QoQIdybUBk9ARPuMmp
-- Analytic sample: N = 41 (excludes IDs below)
--   gV3gktKVjCiwlyGrv8bT — linked Fitbit Aria 2 (smart scale, not wrist-worn)
--   6fN8x1wiU2FaTLkj755g — Inspire 3, no HR data (likely deselected during authorization)
-- ============================================================


-- ============================================================
-- SECTION 1: PARTICIPANT EXCLUSIONS
-- ============================================================

-- Identify participants with step data but no heart rate data
SELECT DISTINCT id 
FROM `jamasp-gcp-project`.`jamasp_fitbit`.`intraday_steps`
WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
  AND date BETWEEN '2025-02-25' AND '2025-04-30'

EXCEPT DISTINCT

SELECT DISTINCT id 
FROM `jamasp-gcp-project`.`jamasp_fitbit`.`heart_rate`
WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
  AND date BETWEEN '2025-02-25' AND '2025-04-30';


-- Check device model for excluded participants
SELECT 
  d.id,
  d.device_version,
  d.battery,
  d.last_sync_time
FROM `jamasp-gcp-project`.`jamasp_fitbit`.`device` d
WHERE d.project_id = 'M7QoQIdybUBk9ARPuMmp'
  AND d.id IN (
    SELECT DISTINCT id 
    FROM `jamasp-gcp-project`.`jamasp_fitbit`.`intraday_steps`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
      AND date BETWEEN '2025-02-25' AND '2025-04-30'
    EXCEPT DISTINCT
    SELECT DISTINCT id 
    FROM `jamasp-gcp-project`.`jamasp_fitbit`.`heart_rate`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
      AND date BETWEEN '2025-02-25' AND '2025-04-30'
  );


-- ============================================================
-- SECTION 2: DATA YIELD (Table 3)
-- ============================================================

WITH tables AS (
  SELECT 'breathing_rate' AS tbl, id, date FROM `jamasp-gcp-project`.`jamasp_fitbit`.`breathing_rate`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp' AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  UNION ALL
  SELECT 'heart_rate', id, date FROM `jamasp-gcp-project`.`jamasp_fitbit`.`heart_rate`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp' AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  UNION ALL
  SELECT 'hrv_intraday', id, date FROM `jamasp-gcp-project`.`jamasp_fitbit`.`hrv_intraday`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp' AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  UNION ALL
  SELECT 'intraday_calories', id, date FROM `jamasp-gcp-project`.`jamasp_fitbit`.`intraday_calories`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp' AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  UNION ALL
  SELECT 'intraday_distances', id, date FROM `jamasp-gcp-project`.`jamasp_fitbit`.`intraday_distances`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp' AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  UNION ALL
  SELECT 'intraday_elevation', id, date FROM `jamasp-gcp-project`.`jamasp_fitbit`.`intraday_elevation`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp' AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  UNION ALL
  SELECT 'intraday_floors', id, date FROM `jamasp-gcp-project`.`jamasp_fitbit`.`intraday_floors`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp' AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  UNION ALL
  SELECT 'intraday_steps', id, date FROM `jamasp-gcp-project`.`jamasp_fitbit`.`intraday_steps`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp' AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  UNION ALL
  SELECT 'sleep_levels', id, date FROM `jamasp-gcp-project`.`jamasp_fitbit`.`sleep_levels`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp' AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  UNION ALL
  SELECT 'spo2_intraday', id, date FROM `jamasp-gcp-project`.`jamasp_fitbit`.`spo2_intraday`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp' AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  UNION ALL
  SELECT 'temp_skin', id, date FROM `jamasp-gcp-project`.`jamasp_fitbit`.`temp_skin`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp' AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  UNION ALL
  SELECT 'vo2_max_summary', id, date FROM `jamasp-gcp-project`.`jamasp_fitbit`.`vo2_max_summary`
    WHERE project_id = 'M7QoQIdybUBk9ARPuMmp' AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
)
SELECT
  tbl,
  COUNT(DISTINCT id) AS N,
  COUNT(DISTINCT date) AS days,
  COUNT(*) AS data_points
FROM tables
GROUP BY tbl
ORDER BY tbl;


-- ============================================================
-- SECTION 3: WEAR TIME
-- ============================================================

-- Check for double-fetched days (rows > 1440 per participant-day)
SELECT
  id,
  date,
  COUNT(*) AS row_count,
  COUNT(*) / 1440.0 AS coverage_ratio
FROM `jamasp-gcp-project`.`jamasp_fitbit`.`heart_rate`
WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
  AND date BETWEEN '2025-02-25' AND '2025-04-30'
  AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
GROUP BY id, date
HAVING COUNT(*) > 1440
ORDER BY row_count DESC
LIMIT 20;


-- Mean daily HR records (used to compute 85% wear time estimate)
-- 1,221 mean daily records / 1,440 max possible = 84.8% ≈ 85%
SELECT 
  ROUND(COUNT(*) / (COUNT(DISTINCT id) * COUNT(DISTINCT date)), 1) AS mean_daily_records
FROM `jamasp-gcp-project`.`jamasp_fitbit`.`heart_rate`
WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
  AND date BETWEEN '2025-02-25' AND '2025-04-30'
  AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g');


-- Daily wear time per participant (hours)
SELECT
  id,
  date,
  COUNT(*) AS minutes_with_hr,
  ROUND(COUNT(*) / 1440.0 * 24, 2) AS hours_worn
FROM `jamasp-gcp-project`.`jamasp_fitbit`.`heart_rate`
WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
  AND date BETWEEN '2025-02-25' AND '2025-04-30'
  AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
GROUP BY id, date
ORDER BY id, date;


-- Day-level HR coverage per participant (% of 65 study days)
SELECT
  id,
  COUNT(DISTINCT date) AS days_with_hr,
  ROUND(COUNT(DISTINCT date) / 65.0 * 100, 1) AS pct_days_covered
FROM `jamasp-gcp-project`.`jamasp_fitbit`.`heart_rate`
WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
  AND date BETWEEN '2025-02-25' AND '2025-04-30'
  AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
GROUP BY id
ORDER BY pct_days_covered DESC;


-- Day-of-week wear time analysis
SELECT
  FORMAT_DATE('%A', date) AS day_of_week,
  EXTRACT(DAYOFWEEK FROM date) AS dow_num,
  COUNT(DISTINCT id) AS n_participants,
  ROUND(AVG(daily_minutes), 1) AS mean_minutes,
  ROUND(AVG(daily_minutes) / 1440 * 100, 1) AS mean_pct_wear
FROM (
  SELECT
    id,
    date,
    COUNT(*) AS daily_minutes
  FROM `jamasp-gcp-project`.`jamasp_fitbit`.`heart_rate`
  WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
    AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  GROUP BY id, date
)
GROUP BY day_of_week, dow_num
ORDER BY dow_num;


-- ============================================================
-- SECTION 4: NON-WEAR DETECTION
-- ============================================================

-- Identify all-zero step days (indicative of non-wear)
SELECT 
  id,
  date,
  COUNT(*) AS total_intervals,
  SUM(CASE WHEN value = 0 THEN 1 ELSE 0 END) AS zero_intervals,
  ROUND(SUM(CASE WHEN value = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_zero
FROM `jamasp-gcp-project`.`jamasp_fitbit`.`intraday_steps`
WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
  AND date BETWEEN '2025-02-25' AND '2025-04-30'
  AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
GROUP BY id, date
ORDER BY pct_zero DESC
LIMIT 20;


-- Cross-stream non-wear classification (per participant-day)
-- HR null + steps = 0 → likely non-wear
-- HR present + steps = 0 → genuine inactivity
SELECT
  s.id,
  s.date,
  COUNT(*) AS total_step_intervals,
  SUM(CASE WHEN h.value IS NULL AND s.value = 0 THEN 1 ELSE 0 END) AS likely_nonwear,
  SUM(CASE WHEN h.value IS NOT NULL AND s.value = 0 THEN 1 ELSE 0 END) AS genuine_inactivity,
  SUM(CASE WHEN s.value > 0 THEN 1 ELSE 0 END) AS active_intervals
FROM `jamasp-gcp-project`.`jamasp_fitbit`.`intraday_steps` s
LEFT JOIN `jamasp-gcp-project`.`jamasp_fitbit`.`heart_rate` h
  ON s.id = h.id AND s.date = h.date AND s.date_time = h.datetime
WHERE s.project_id = 'M7QoQIdybUBk9ARPuMmp'
  AND s.date BETWEEN '2025-02-25' AND '2025-04-30'
  AND s.id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
GROUP BY s.id, s.date
ORDER BY likely_nonwear DESC
LIMIT 20;


-- Cross-stream non-wear classification (aggregate)
-- Reported in Results: 620,146 non-wear mins, 19.1% of zero-step mins
SELECT
  SUM(likely_nonwear) AS total_nonwear_mins,
  SUM(genuine_inactivity) AS total_inactivity_mins,
  SUM(active_intervals) AS total_active_mins,
  ROUND(SUM(likely_nonwear) / (SUM(likely_nonwear) + SUM(genuine_inactivity)) * 100, 1) AS pct_zeros_that_are_nonwear
FROM (
  SELECT
    s.id,
    s.date,
    COUNT(DISTINCT CASE WHEN h.value IS NULL AND s.value = 0 THEN s.date_time END) AS likely_nonwear,
    COUNT(DISTINCT CASE WHEN h.value IS NOT NULL AND s.value = 0 THEN s.date_time END) AS genuine_inactivity,
    COUNT(DISTINCT CASE WHEN s.value > 0 THEN s.date_time END) AS active_intervals
  FROM `jamasp-gcp-project`.`jamasp_fitbit`.`intraday_steps` s
  LEFT JOIN `jamasp-gcp-project`.`jamasp_fitbit`.`heart_rate` h
    ON s.id = h.id AND s.date = h.date AND s.date_time = h.datetime
  WHERE s.project_id = 'M7QoQIdybUBk9ARPuMmp'
    AND s.date BETWEEN '2025-02-25' AND '2025-04-30'
    AND s.id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  GROUP BY s.id, s.date
);


-- ============================================================
-- SECTION 5: FIGURES
-- ============================================================

-- Figure 3: Mean HR by hour of day per participant
SELECT
  id,
  EXTRACT(HOUR FROM datetime) AS hour_of_day,
  ROUND(AVG(value), 2) AS mean_hr
FROM `jamasp-gcp-project`.`jamasp_fitbit`.`heart_rate`
WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
  AND date BETWEEN '2025-02-25' AND '2025-04-30'
  AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
GROUP BY id, hour_of_day
ORDER BY id, hour_of_day;


-- Figure 4: Mean hourly step count per participant
SELECT
  id,
  hour_of_day,
  ROUND(AVG(hourly_steps), 2) AS mean_hourly_steps
FROM (
  SELECT
    id,
    date,
    EXTRACT(HOUR FROM date_time) AS hour_of_day,
    SUM(value) AS hourly_steps
  FROM `jamasp-gcp-project`.`jamasp_fitbit`.`intraday_steps`
  WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
    AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
  GROUP BY id, date, hour_of_day
)
GROUP BY id, hour_of_day
ORDER BY id, hour_of_day;


-- Figure 5: Sleep stage duration by hour of night per participant
-- Only participants with valid sleep data (>=4h sleep on >=70% of days)
WITH minute_level AS (
  SELECT
    id,
    date,
    level,
    datetime AS episode_start,
    TIMESTAMP_ADD(datetime, INTERVAL CAST(seconds AS INT64) SECOND) AS episode_end,
    seconds
  FROM `jamasp-gcp-project`.`jamasp_fitbit`.`sleep_levels`
  WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
    AND date BETWEEN '2025-02-25' AND '2025-04-30'
    AND level IN ('light', 'deep', 'rem', 'wake')
),
hourly_splits AS (
  SELECT
    m.id,
    m.date,
    m.level,
    hour_start,
    TIMESTAMP_DIFF(
      LEAST(TIMESTAMP_ADD(hour_start, INTERVAL 1 HOUR), m.episode_end),
      GREATEST(hour_start, m.episode_start),
      SECOND
    ) AS seconds_in_hour
  FROM minute_level m
  CROSS JOIN UNNEST(
    GENERATE_TIMESTAMP_ARRAY(
      TIMESTAMP_TRUNC(m.episode_start, HOUR),
      TIMESTAMP_TRUNC(TIMESTAMP_ADD(m.episode_end, INTERVAL -1 SECOND), HOUR),
      INTERVAL 1 HOUR
    )
  ) AS hour_start
  WHERE TIMESTAMP_DIFF(
    LEAST(TIMESTAMP_ADD(hour_start, INTERVAL 1 HOUR), m.episode_end),
    GREATEST(hour_start, m.episode_start),
    SECOND
  ) > 0
),
daily_hourly AS (
  SELECT
    id,
    date,
    level,
    EXTRACT(HOUR FROM hour_start) AS hour_of_night,
    SUM(seconds_in_hour) AS seconds_in_hour
  FROM hourly_splits
  GROUP BY id, date, level, hour_of_night
),
valid_participants AS (
  SELECT id
  FROM (
    SELECT
      id,
      COUNTIF(daily_sleep_hours >= 4) AS valid_days,
      COUNT(DISTINCT date) AS total_days
    FROM (
      SELECT id, date, SUM(seconds_in_hour) / 3600 AS daily_sleep_hours
      FROM daily_hourly
      WHERE level IN ('light', 'deep', 'rem')
      GROUP BY id, date
    )
    GROUP BY id
  )
  WHERE valid_days >= 0.7 * total_days
)
SELECT
  d.id,
  d.hour_of_night,
  d.level,
  AVG(d.seconds_in_hour) AS mean_seconds
FROM daily_hourly d
JOIN valid_participants v ON d.id = v.id
WHERE d.level IN ('light', 'deep', 'rem')
GROUP BY d.id, d.hour_of_night, d.level
ORDER BY d.id, d.hour_of_night, d.level;
