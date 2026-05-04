# Jamasp BigQuery Schema

Database: `jamasp-gcp-project.jamasp_fitbit`

All tables share the following common fields:
- `id` (STRING) — pseudonymous participant identifier
- `date` (DATE) — calendar date of the record
- `project_id` (STRING) — Jamasp study identifier
- `endpoint_source` (STRING) — Fitbit API endpoint used for retrieval

---

## Activity & Exercise

### `intraday_steps`
Minute-level step count data. Returns 0.0 for minutes with no detected movement, including when the device is not worn.
| Field | Type | Description |
|-------|------|-------------|
| value | FLOAT | Step count for the interval |
| date_time | TIMESTAMP | Timestamp of the interval |

### `intraday_calories`
| Field | Type | Description |
|-------|------|-------------|
| value | FLOAT | Calories burned |
| level | STRING | Activity level |
| mets | FLOAT | Metabolic equivalent |
| date_time | TIMESTAMP | Timestamp |

### `intraday_distances`
| Field | Type | Description |
|-------|------|-------------|
| value | FLOAT | Distance in km |
| date_time | TIMESTAMP | Timestamp |

### `intraday_floors`
| Field | Type | Description |
|-------|------|-------------|
| value | FLOAT | Floors climbed |
| date_time | TIMESTAMP | Timestamp |

### `intraday_elevation`
| Field | Type | Description |
|-------|------|-------------|
| value | FLOAT | Elevation change in meters |
| date_time | TIMESTAMP | Timestamp |

---

## Heart Rate & HRV

### `heart_rate`
Minute-level heart rate. Returns NULL when device is off the wrist (use for non-wear detection).
| Field | Type | Description |
|-------|------|-------------|
| value | FLOAT | Heart rate in bpm |
| datetime | TIMESTAMP | Timestamp |

### `hrv_intraday`
HRV indices derived from interbeat intervals during sleep only.
| Field | Type | Description |
|-------|------|-------------|
| rmssd | FLOAT | Root mean square of successive differences |
| coverage | FLOAT | Data coverage for the interval |
| hf | FLOAT | High frequency power |
| lf | FLOAT | Low frequency power |
| dateTime | TIMESTAMP | Timestamp |

### `breathing_rate`
Estimated respiration rate during sleep, one record per night.
| Field | Type | Description |
|-------|------|-------------|
| deepSleepSummary | FLOAT | Breathing rate during deep sleep |
| lightSleepSummary | FLOAT | Breathing rate during light sleep |
| remSleepSummary | FLOAT | Breathing rate during REM sleep |
| fullSleepSummary | FLOAT | Overall nightly breathing rate |

---

## Sleep

### `sleep_levels`
Episode-level sleep stage data.
| Field | Type | Description |
|-------|------|-------------|
| level | STRING | Sleep stage: deep, light, rem, wake |
| seconds | INTEGER | Duration of the episode in seconds |
| datetime | TIMESTAMP | Start time of episode |
| log_id | INTEGER | Sleep log identifier |

---

## Oxygen Saturation

### `spo2_intraday`
Blood oxygen saturation during sleep.
| Field | Type | Description |
|-------|------|-------------|
| value | FLOAT | SpO2 percentage |
| minute | INTEGER | Minute offset within the night |

---

## Temperature

### `temp_skin`
Nightly skin temperature deviation from baseline.
| Field | Type | Description |
|-------|------|-------------|
| nightly_relative | FLOAT | Temperature deviation in °C |
| log_type | STRING | Type of temperature log |
| dateTime | TIMESTAMP | Timestamp |

---

## Cardio Fitness

### `vo2_max_summary`
Daily VO2 max estimate based on resting heart rate, age, sex, and weight.
| Field | Type | Description |
|-------|------|-------------|
| vo2_max | FLOAT | Estimated VO2 max (ml/kg/min) |

---

## Device

### `device`
Device information per participant.
| Field | Type | Description |
|-------|------|-------------|
| device_version | STRING | Device model (e.g., "Inspire 3", "Aria 2") |
| battery | STRING | Battery level category |
| battery_level | INTEGER | Battery percentage |
| last_sync_time | TIMESTAMP | Last device sync timestamp |
