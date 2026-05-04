-- Mean hourly step count per participant (Figure 4)
-- Used to generate Figure 4 in the paper

SELECT
  id,
  EXTRACT(HOUR FROM PARSE_TIMESTAMP('%H:%M', time)) AS hour_of_day,
  AVG(value) AS mean_hourly_steps
FROM `jamasp-gcp-project`.`jamasp_fitbit`.`intraday_steps`
WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
  AND date BETWEEN '2025-02-25' AND '2025-04-30'
  AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g')
GROUP BY id, hour_of_day
ORDER BY id, hour_of_day;


-- Day-of-week wear time analysis
-- Used to identify Sunday wear-time dip reported in Results

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


-- Zero-step day check (non-wear verification)
-- Days with 100% zero step values across all intraday intervals

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
