# Jamasp — Public Research Materials

This repository contains analysis code, SQL queries, and anonymized data supporting the following paper:

> Salari Rad, M., & Radmanesh, A. (in preparation). Wearable device data collection from existing device owners via crowdsourcing platforms: A feasibility study using Jamasp.

**Platform website:** [jamasp.app](https://jamasp.app)  
**Interactive data explorer:** [jamasp.app/explore](https://jamasp.app/explore)

---

## Repository Structure

```
jamasp-public/
├── queries/          # BigQuery SQL queries used in the paper
├── data/             # Anonymized aggregate data (CSV)
├── schema/           # BigQuery table schema descriptions
└── README.md
```

---
## Read paper
[Read the Paper](https://docs.google.com/document/d/1Z13xEMe-RGqervhmDNtwkO6dxHBnf07L7Zi_4ncNEWQ/edit?usp=sharing)
---

## Queries

All queries are written for Google BigQuery and assume the Jamasp data schema described in `schema/`.

| File | Description |
|------|-------------|
| `queries/table3_data_yield.sql` | Data yield by stream (Table 3 in paper) |
| `queries/wear_time_daily.sql` | Daily wear time per participant from minute-level HR |
| `queries/day_coverage.sql` | % of study days with HR data per participant |
| `queries/nonwear_classification.sql` | Cross-stream non-wear detection (HR null + steps = 0) |
| `queries/zero_check.sql` | Identifying all-zero step days (non-wear verification) |
| `queries/hr_hourly.sql` | Mean hourly heart rate per participant |
| `queries/steps_hourly.sql` | Mean hourly step count per participant |

---

## Data

Anonymized aggregate data from the pilot study (N = 41 participants, February 25 – April 30, 2025). Participant IDs are pseudonymized (P01–P41). Raw participant-level data cannot be shared due to privacy considerations.

| File | Description |
|------|-------------|
| `data/steps_hourly.csv` | Mean hourly step count per participant (hours 0–23) |
| `data/coverage.csv` | Day-level HR coverage per participant |
| `data/wear_time_daily.csv` | Daily wear time (hours) per participant |

---

## Schema

The `schema/` folder contains descriptions of the BigQuery tables retrieved via the Jamasp pipeline, including field names, types, and descriptions for each Fitbit data stream.

---

## Citation

If you use these materials, please cite:

```
Salari Rad, M., & Radmanesh, A. (in preparation). Wearable device data 
collection from existing device owners via crowdsourcing platforms: 
A feasibility study using Jamasp.
```
