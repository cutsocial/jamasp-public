-- Cross-stream non-wear classification
-- Minutes where HR is null and steps = 0 are classified as non-wear
-- Minutes where HR is present and steps = 0 are classified as genuine inactivity
-- Reported in Results section

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
