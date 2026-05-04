-- Table 3: Data yield by domain and Jamasp table
-- N = 41 analytic sample (excludes two participants without HR data)
-- Study window: February 25 – April 30, 2025

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
