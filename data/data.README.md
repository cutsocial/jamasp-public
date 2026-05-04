# Data Dictionary

This document describes the CSV files in the `data/` directory. All data were collected via the Jamasp platform from participants recruited on Prolific. The study window is **February 25 – April 30, 2025**.

---

## `hr_hourly.csv` — Hourly step counts

Participant-level mean hourly step counts aggregated across the study window.

| Column | Type | Description |
|---|---|---|
| `id` | string | Anonymized participant identifier |
| `hour_of_day` | integer | Hour of day in 24-hour format (0 = midnight, 23 = 11 PM) |
| `mean_hourly_steps` | float | Mean number of steps recorded during that hour, averaged across all days in the study window for that participant |

**Coverage:** N = 41 participants × 24 hours = 984 rows.

---

## `steps_hourly.csv` — Hourly sleep stage durations

Participant-level mean sleep stage durations by hour of day, aggregated across the study window. Only participants with valid sleep data are included (≥ 4 hours of sleep on ≥ 70% of study days).

| Column | Type | Description |
|---|---|---|
| `id` | string | Anonymized participant identifier |
| `hour_of_day` | integer | Hour of day in 24-hour format (0 = midnight, 23 = 11 PM) |
| `level` | string | Sleep stage: `deep`, `light`, `rem`, or `wake` |
| `mean_seconds` | float | Mean number of seconds spent in that sleep stage during that hour, averaged across all days in the study window for that participant |

**Coverage:** N = 37 participants × 24 hours × 4 stages = 3,552 theoretical rows (2,034 non-zero rows; hours with no recorded sleep for a given stage are omitted).

---

## `sleep_stages_hourly.csv` — Hourly heart rate

Participant-level mean hourly heart rate aggregated across the study window.

| Column | Type | Description |
|---|---|---|
| `id` | string | Anonymized participant identifier |
| `hour_of_day` | integer | Hour of day in 24-hour format (0 = midnight, 23 = 11 PM) |
| `mean_hr` | float | Mean heart rate (bpm) recorded during that hour, averaged across all days in the study window for that participant |

**Coverage:** N = 41 participants × 24 hours = 984 rows.

---

## Notes

- Participant IDs are consistent across files and can be used to link records, but are not linked to any Prolific or Fitbit identifiers in these exports.
- All times are in the participant's **local time zone** as reported by the Fitbit API.
- Step and sleep aggregates reflect data retrieved for the full study window; individual participants may have fewer valid days depending on device wear and sync behavior (see Table 3 in the paper for per-stream coverage statistics).
