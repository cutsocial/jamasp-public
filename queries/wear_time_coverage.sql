-- Daily wear time per participant
-- Estimated from minute-level heart rate coverage
-- Used to compute mean daily wear time reported in Results

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


-- Day-level HR coverage per participant
-- % of 65 study days with any heart rate data

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


-- Mean daily HR records (used to compute 85% wear time estimate)
-- 1,221 mean daily records / 1,440 max possible = 84.8% ≈ 85%

SELECT
  ROUND(COUNT(*) / (COUNT(DISTINCT id) * COUNT(DISTINCT date)), 1) AS mean_daily_records
FROM `jamasp-gcp-project`.`jamasp_fitbit`.`heart_rate`
WHERE project_id = 'M7QoQIdybUBk9ARPuMmp'
  AND date BETWEEN '2025-02-25' AND '2025-04-30'
  AND id NOT IN ('gV3gktKVjCiwlyGrv8bT', '6fN8x1wiU2FaTLkj755g');
