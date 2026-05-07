# Data Conversion: Pseudocode & Schema Mapping

This document describes how raw Fitbit API responses are normalized, converted to BigQuery schema, and inserted into tables.

---

## 1. Conversion Flow Overview

```
Raw Fitbit API Response (JSON)
  ↓
Identify Endpoint Type & Target Table(s)
  ↓
Extract Relevant Fields
  ↓
Normalize to Tabular Format
  ↓
Add Metadata (project, participant, device, timestamp)
  ↓
Apply Type Conversions
  ↓
Create BigQuery Row Objects
  ↓
Batch Aggregate by Table
  ↓
Insert into BigQuery
```

---

## 2. Endpoint to BigQuery Table Mapping

### Mapping Registry

```
Fitbit API Endpoint → BigQuery Table(s)

Heart Rate Endpoints:
  - HeartRate_Intraday_byDate → "heart_rate_intraday"
  - Heart_Rate_Summary → "heart_rate_summary"

Activity Endpoints:
  - Activity_Steps_Intraday_byDate → "activity_steps_intraday"
  - Activity_Calories_Intraday_byDate → "activity_calories_intraday"
  - Activity_Distance_Intraday_byDate → "activity_distance_intraday"
  - Activity_Elevation_Intraday_byDate → "activity_elevation_intraday"
  - Activity_Floors_Intraday_byDate → "activity_floors_intraday"
  - Activity_Summary → "activity_summary"
  - Activity_Goals → "activity_goals"
  - Activity_Logs → "activity_logs"

Sleep Endpoints:
  - Sleep_Log_byDate → "sleep"
  - Sleep_Log_List → "sleep"

Breathing Endpoints:
  - Breathing_Intraday_byDate → "breathing_rate"

Other Endpoints:
  - Device → "device"
  - Badges → "badges"
  - VO2_Max_Summary_byDate → "cardio_fitness"
  - HRV_Intraday_byDate → "heart_rate_variability"
  - SpO2_Intraday_byDate → "oxygen_saturation"
  - Temperature_Core_Summary_byDate → "temperature_core"
  - Temperature_Skin_Summary_byDate → "temperature_skin"
  - ECG_Log_List → "ecg"
```

### Table Schema Reference

Each BigQuery table has predefined schema with columns and data types:

```
heart_rate_intraday:
  - id: STRING (primary key)
  - date: DATE
  - user_id: STRING
  - timestamp: TIMESTAMP
  - heart_rate: INTEGER
  - confidence: INTEGER (optional)

activity_steps_intraday:
  - id: STRING
  - date: DATE
  - user_id: STRING
  - timestamp: TIMESTAMP
  - steps: INTEGER

sleep:
  - id: STRING
  - date: DATE
  - user_id: STRING
  - duration: INTEGER (milliseconds)
  - start_time: TIMESTAMP
  - end_time: TIMESTAMP
  - quality: INTEGER
  - efficiency: FLOAT
  - sleep_stage_deep: INTEGER
  - sleep_stage_light: INTEGER
  - sleep_stage_rem: INTEGER
  - sleep_stage_wake: INTEGER

device:
  - id: STRING
  - date: DATE
  - battery: STRING
  - battery_level: INTEGER
  - device_version: STRING
  - last_sync_time: TIMESTAMP

badges:
  - id: STRING
  - date: DATE
  - name: STRING
  - category: STRING
  - date_time: STRING
  - value: INTEGER
  - unit: STRING
  - description: STRING
```

---

## 3. Data Type Conversion

### Field Type Mapping

```
Fitbit API Type → BigQuery Type Conversion Rules

STRING Fields:
  Input: "2024-05-07"
  Output: DATE type (if format matches YYYY-MM-DD)

  Input: "2024-05-07T14:30:45"
  Output: TIMESTAMP type (if ISO 8601 format)

  Input: "Light Sleep", "Deep Sleep"
  Output: STRING type (as-is, no conversion)

NUMBER Fields (Integer):
  Input: 123, 456
  Output: INTEGER type (store as-is)

  Input: 0, -1
  Output: INTEGER type (handle negative values)

  Input: null, undefined
  Output: NULL (handle missing values)

NUMBER Fields (Float):
  Input: 123.45, 456.78
  Output: FLOAT type (preserve decimal precision)

  Input: 0.0, -1.5
  Output: FLOAT type (handle negative values)

BOOLEAN Fields:
  Input: true, false
  Output: BOOLEAN type (cast as-is)

TIMESTAMP Fields (ISO 8601):
  Input: "2024-05-07T14:30:45Z"
  Output: TIMESTAMP (convert to standard format)

  Input: "2024-05-07T14:30:45.123Z"
  Output: TIMESTAMP (preserve milliseconds)

NESTED Objects:
  Input: { "key": value }
  Output: Flatten into separate columns OR
          Store as JSON STRING if BigQuery table allows

ARRAYS:
  Input: [ { item1 }, { item2 } ]
  Output: Multiple rows (one per array element)
          with same parent fields replicated
```

---

## 4. Fitbit Response to Tabular Normalization

### Heart Rate Intraday Example

```
INPUT (Fitbit API Response):
{
  "activities-heart-intraday": {
    "dataset": [
      { "time": "00:00:00", "value": 72 },
      { "time": "00:01:00", "value": 74 },
      { "time": "00:02:00", "value": 71 },
      ...
    ],
    "datasetInterval": 1,
    "datasetType": "minute"
  },
  "activities-heart": [
    {
      "dateTime": "2024-05-07",
      "value": {
        "resting_heart_rate": 62,
        ...
      }
    }
  ]
}

CONVERSION PROCESS:

STEP 1: Identify Data Structure Type
  - This is an intraday timeseries endpoint
  - Contains minute-level data points
  - Each data point is independent record

STEP 2: Extract Base Fields (from Fitbit response):
  - dateTime: "2024-05-07"
  - datasetInterval: 1 (minute)

STEP 3: Flatten Array into Rows
  FOR EACH datapoint IN "activities-heart-intraday".dataset:

    CREATE bigQueryRow:
      - id: hash(user_id + date + time) // unique row identifier
      - date: DATE("2024-05-07")
      - user_id: "fitbit_user_id_123456"
      - timestamp: TIMESTAMP("2024-05-07T" + time + "Z")
      - heart_rate: datapoint.value (INTEGER: 72)
      - confidence: datapoint.confidence OR NULL

      // Metadata added later
      - project_id: "project-abc"
      - participant_id: "user-xyz"
      - device_id: "fitbit_user_id_123456"
      - fetch_timestamp: now()
      - endpoint: "HeartRate_Intraday_byDate"

    ADD bigQueryRow TO output array

  ENDFOR

OUTPUT (BigQuery Rows):
[
  {
    id: "uuid-xxx-1",
    date: 2024-05-07,
    user_id: "fitbit_user_id_123456",
    timestamp: 2024-05-07T00:00:00Z,
    heart_rate: 72,
    confidence: null,
    project_id: "project-abc",
    participant_id: "user-xyz",
    device_id: "fitbit_user_id_123456",
    fetch_timestamp: 2024-05-07T01:30:45Z,
    endpoint: "HeartRate_Intraday_byDate"
  },
  {
    id: "uuid-xxx-2",
    date: 2024-05-07,
    user_id: "fitbit_user_id_123456",
    timestamp: 2024-05-07T00:01:00Z,
    heart_rate: 74,
    confidence: null,
    ...
  },
  ...
]
```

---

## 5. Activity Summary Normalization

### Activity Summary Example

```
INPUT (Fitbit API Response):
{
  "activities": [
    {
      "name": "Walk",
      "activityId": 90001,
      "calories": 250,
      "distance": 2.5,
      "duration": 3600000,
      "startTime": "2024-05-07T08:00:00.000",
      "steps": 5000
    }
  ],
  "summary": {
    "steps": 12345,
    "distance": 8.5,
    "floors": 15,
    "elevation": 75,
    "caloriesOut": 2000,
    "caloriesBMR": 1500,
    "marginalCalories": 500,
    "activityCalories": 1500,
    "fairlyActiveMinutes": 45,
    "lightlyActiveMinutes": 120,
    "sedentaryMinutes": 800,
    "restingHeartRate": 65
  }
}

CONVERSION PROCESS:

STEP 1: Activities Array
  This is 1:N relationship
  Each activity is separate record in BigQuery

  FOR EACH activity IN "activities":

    CREATE activityRow:
      - id: hash(user_id + date + activity.activityId)
      - date: DATE("2024-05-07")
      - user_id: "fitbit_user_id_123456"
      - activity_id: activity.activityId
      - activity_name: activity.name
      - calories: INTEGER(activity.calories)
      - distance: FLOAT(activity.distance)
      - duration: INTEGER(activity.duration) // milliseconds
      - start_datetime: TIMESTAMP(activity.startTime)
      - steps: INTEGER(activity.steps)
      - project_id: "project-abc"
      - participant_id: "user-xyz"
      - device_id: "fitbit_user_id_123456"
      - fetch_timestamp: now()

    ADD activityRow TO activity_logs array

  ENDFOR

STEP 2: Summary Data
  This is 1:1 relationship per date
  Single record per day summarizing all activity

  CREATE summaryRow:
    - id: hash(user_id + date + "summary")
    - date: DATE("2024-05-07")
    - user_id: "fitbit_user_id_123456"
    - steps: INTEGER(12345)
    - distance: FLOAT(8.5)
    - floors: INTEGER(15)
    - elevation: INTEGER(75)
    - calories_out: INTEGER(2000)
    - calories_bmr: INTEGER(1500)
    - marginal_calories: INTEGER(500)
    - activity_calories: INTEGER(1500)
    - fairly_active_minutes: INTEGER(45)
    - lightly_active_minutes: INTEGER(120)
    - sedentary_minutes: INTEGER(800)
    - resting_heart_rate: INTEGER(65)
    - project_id: "project-abc"
    - participant_id: "user-xyz"
    - device_id: "fitbit_user_id_123456"
    - fetch_timestamp: now()

  ADD summaryRow TO activity_summary array

OUTPUT (BigQuery Rows):
activity_logs: [ { row1 }, { row2 }, ... ]
activity_summary: [ { summaryRow } ]
```

---

## 6. Sleep Data Normalization

### Sleep Log Example

```
INPUT (Fitbit API Response):
{
  "sleep": [
    {
      "logId": 1234567890,
      "dateOfSleep": "2024-05-07",
      "startTime": "2024-05-06T23:00:00.000",
      "endTime": "2024-05-07T07:00:00.000",
      "duration": 28800000,
      "efficiency": 85,
      "stages": {
        "deep": 3600000,
        "light": 18000000,
        "rem": 5400000,
        "wake": 1800000
      },
      "totalMinutesAsleep": 480,
      "totalSleepRecords": 1
    }
  ]
}

CONVERSION PROCESS:

FOR EACH sleepRecord IN "sleep":

  CREATE sleepRow:
    - id: hash(user_id + dateOfSleep + logId)
    - date: DATE(sleepRecord.dateOfSleep)
    - user_id: "fitbit_user_id_123456"
    - start_time: TIMESTAMP(sleepRecord.startTime)
    - end_time: TIMESTAMP(sleepRecord.endTime)
    - duration: INTEGER(sleepRecord.duration) // milliseconds
    - efficiency: FLOAT(sleepRecord.efficiency) // percentage
    - total_minutes_asleep: INTEGER(sleepRecord.totalMinutesAsleep)
    - sleep_stage_deep: INTEGER(sleepRecord.stages.deep / 60000) // convert to minutes
    - sleep_stage_light: INTEGER(sleepRecord.stages.light / 60000)
    - sleep_stage_rem: INTEGER(sleepRecord.stages.rem / 60000)
    - sleep_stage_wake: INTEGER(sleepRecord.stages.wake / 60000)
    - project_id: "project-abc"
    - participant_id: "user-xyz"
    - device_id: "fitbit_user_id_123456"
    - fetch_timestamp: now()

  ADD sleepRow TO sleep array

ENDFOR

OUTPUT (BigQuery Rows):
[ { sleepRow1 }, { sleepRow2 }, ... ]
```

---

## 7. Device Data Normalization

### Device Information Example

```
INPUT (Fitbit API Response from /devices endpoint):
[
  {
    "battery": "High",
    "batteryLevel": 85,
    "device": "Sense",
    "deviceVersion": "Fitbit Sense",
    "id": "fitbit_user_id_123456",
    "lastSyncTime": "2024-05-07T10:30:45.000",
    "mac": "AA:BB:CC:DD:EE:FF",
    "type": "TRACKER"
  }
]

CONVERSION PROCESS:

FOR EACH device IN response:

  CREATE deviceRow:
    - id: hash(user_id + date + device.id)
    - date: TODAY()
    - user_id: "fitbit_user_id_123456"
    - battery: STRING(device.battery)
    - battery_level: INTEGER(device.batteryLevel)
    - device_version: STRING(device.deviceVersion)
    - last_sync_time: TIMESTAMP(device.lastSyncTime)
    - device_type: STRING(device.type)
    - project_id: "project-abc"
    - participant_id: "user-xyz"
    - device_id: "fitbit_user_id_123456"
    - fetch_timestamp: now()

  ADD deviceRow TO device array

ENDFOR

OUTPUT (BigQuery Rows):
[ { deviceRow } ]
```

---

## 8. Complex Nested Structure Handling

### Badge/Achievement Data

```
INPUT (Fitbit API Response):
{
  "badges": [
    {
      "badgeId": 12345,
      "badgeGradientEndColor": "#FF0000",
      "badgeGradientStartColor": "#FFFFFF",
      "badgeType": "DAILY_STEPS",
      "category": "Steps",
      "dateTime": "2024-05-07T00:00:00.000",
      "description": "You've earned the 10,000 steps badge!",
      "image100px": "https://example.com/badge-100.png",
      "name": "10,000 Steps",
      "shortName": "10k Steps",
      "timesAchieved": 2,
      "unit": "steps",
      "value": 10000
    }
  ]
}

CONVERSION PROCESS:

FOR EACH badge IN "badges":

  CREATE badgeRow:
    - id: hash(user_id + dateTime + badgeId)
    - date: DATE(badge.dateTime)
    - user_id: "fitbit_user_id_123456"
    - badge_id: INTEGER(badge.badgeId)
    - name: STRING(badge.name)
    - short_name: STRING(badge.shortName)
    - category: STRING(badge.category)
    - description: STRING(badge.description)
    - badge_type: STRING(badge.badgeType)
    - value: INTEGER(badge.value)
    - unit: STRING(badge.unit)
    - times_achieved: INTEGER(badge.timesAchieved)
    - date_time: TIMESTAMP(badge.dateTime)
    - image_url: STRING(badge.image100px)
    - project_id: "project-abc"
    - participant_id: "user-xyz"
    - device_id: "fitbit_user_id_123456"
    - fetch_timestamp: now()

  ADD badgeRow TO badges array

ENDFOR

OUTPUT (BigQuery Rows):
[ { badgeRow1 }, { badgeRow2 }, ... ]
```

---

## 9. Main Conversion Function

### Convert Endpoint Response to BigQuery Rows

```
FUNCTION convertEndpointDataToRows(
  sensorId,
  fitbitResponse,
  metadata
):

  STEP 1: Validate Input
    IF fitbitResponse is null OR undefined:
      LOG warning: "No data to convert for {sensorId}"
      RETURN []

    IF fitbitResponse.status != 200:
      LOG error: "API returned error status {status}"
      RETURN []


  STEP 2: Route Based on Sensor Type
    tableNames = getTargetTableNames(sensorId)

    SWITCH sensorId:

      CASE "HeartRate_Intraday_byDate":
        rows = convertHeartRateIntraday(fitbitResponse, metadata)

      CASE "Activity_Steps_Intraday_byDate":
        rows = convertActivityStepsIntraday(fitbitResponse, metadata)

      CASE "Sleep_Log_byDate":
        rows = convertSleepLog(fitbitResponse, metadata)

      CASE "Device":
        rows = convertDeviceData(fitbitResponse, metadata)

      CASE "Badges":
        rows = convertBadges(fitbitResponse, metadata)

      ... // other cases

      DEFAULT:
        LOG error: "Unknown sensor type: {sensorId}"
        RETURN []


  STEP 3: Add Metadata to All Rows
    FOR EACH row IN rows:

      ADD to row:
        - project_id: metadata.projectId
        - participant_id: metadata.participantId
        - device_id: metadata.deviceId
        - user_id: metadata.userId
        - fetch_timestamp: now()
        - endpoint: sensorId
        - source_ref: metadata.firestoreRef

      NORMALIZE field names:
        - Convert to snake_case
        - Ensure consistency with schema

    ENDFOR


  STEP 4: Validate Each Row
    FOR EACH row IN rows:

      CALL validateRowAgainstSchema(row, tableName)

      IF validation fails:
        LOG error: "Row validation failed: {error}"
        SKIP this row (non-fatal)

    ENDFOR


  STEP 5: Return Organized Output
    CREATE output:
      {
        "table_name_1": [ validated_rows ],
        "table_name_2": [ validated_rows ],
        ...
      }

    RETURN output

END
```

---

## 10. Batch Aggregation

### Combine Rows from All Sensors

```
FUNCTION aggregateRowsByTable(
  allSensorResults
):

  STEP 1: Initialize Table Containers
    CREATE combined_bq_data:
      {
        "heart_rate_intraday": [],
        "activity_steps": [],
        "sleep": [],
        "device": [],
        "badges": [],
        ...
      }


  STEP 2: Iterate Sensor Results
    FOR EACH sensorResult IN allSensorResults:

      FOR EACH tableName IN sensorResult.tableNames:

        GET rows = sensorResult.data[tableName]

        IF rows is not empty:
          APPEND rows TO combined_bq_data[tableName]

      ENDFOR

    ENDFOR


  STEP 3: Count Rows per Table
    CREATE rowCounts:
      {
        "heart_rate_intraday": 1440,
        "activity_steps": 1440,
        "sleep": 1,
        ...
      }


  STEP 4: Log Aggregation Results
    FOR EACH tableName IN combined_bq_data:
      count = combined_bq_data[tableName].length
      LOG info: "Table {tableName}: {count} rows ready for insertion"


  STEP 5: Return Aggregated Data
    RETURN {
      data: combined_bq_data,
      stats: {
        totalRows: sum(rowCounts),
        rowsByTable: rowCounts
      }
    }

END
```

---

## 11. BigQuery Batch Insertion

### Insert All Accumulated Data

```
FUNCTION insertAggregatedDataIntoBigQuery(
  datasetId,
  combined_bq_data
):

  CONST MAX_BATCH_SIZE = 5000
  CREATE insertionResults = {}


  STEP 1: For Each Table
    FOR EACH tableName IN combined_bq_data:

      GET tableData = combined_bq_data[tableName]

      IF tableData is empty:
        LOG debug: "Skipping empty table: {tableName}"
        CONTINUE


      STEP 1A: Get Table Reference
        TRY:
          table = BigQuery.dataset(datasetId).table(tableName)
        CATCH error:
          LOG error: "Cannot access table {tableName}"
          insertionResults[tableName] = { error: error }
          CONTINUE


      STEP 1B: Initialize Table Tracking
        insertionResults[tableName] = {
          totalRows: tableData.length,
          batchesProcessed: 0,
          insertedRows: 0,
          failedRows: 0,
          errors: []
        }


      STEP 1C: Split into Batches
        batches = splitIntoBatches(tableData, MAX_BATCH_SIZE)

        FOR EACH batch IN batches:

          STEP 1C-I: Normalize Batch Data
            TRY:
              normalizedBatch = batch.map(row =>
                normalizeForBigQuery(row, tableName)
              )
            CATCH error:
              LOG error: "Normalization failed for batch"
              insertionResults[tableName].errors.push(error)
              CONTINUE


          STEP 1C-II: Insert Batch
            TRY:
              response = table.insert(normalizedBatch, {
                skipInvalidRows: false,
                ignoreUnknownValues: false
              })

              // Check for partial failures
              IF response.errors exists:
                FOR EACH rowError IN response.errors:
                  LOG error: "Row insert failed: {rowError}"
                  insertionResults[tableName].errors.push(rowError)
                  insertionResults[tableName].failedRows++

              ELSE:
                insertionResults[tableName].insertedRows += batch.length

              insertionResults[tableName].batchesProcessed++

            CATCH error:
              LOG error: "Batch insertion failed: {error}"
              insertionResults[tableName].errors.push(error)
              // Continue to next batch (non-blocking)

        ENDFOR

    ENDFOR


  STEP 2: Return Results Summary
    RETURN {
      insertionResults: insertionResults,
      summary: {
        totalTables: Object.keys(combined_bq_data).length,
        tablesProcessed: Object.keys(insertionResults).length,
        totalRowsInserted: sum(insertionResults[*].insertedRows),
        totalRowsFailed: sum(insertionResults[*].failedRows),
        errors: flattenErrors(insertionResults)
      }
    }

END
```

---

## 12. Validation & Error Handling

### Row Validation Against Schema

```
FUNCTION normalizeForBigQuery(row, tableName):

  STEP 1: Get Table Schema
    schema = getTableSchema(tableName)

    IF schema NOT FOUND:
      THROW error "Schema not found for {tableName}"


  STEP 2: Normalize Each Field
    normalizedRow = {}

    FOR EACH field IN schema.fields:

      columnName = field.name
      columnType = field.type
      expectedValue = row[columnName]


      STEP 2A: Handle Missing Values
        IF expectedValue is null OR undefined:
          IF field.mode == "REQUIRED":
            THROW error "Missing required field: {columnName}"
          ELSE:
            normalizedRow[columnName] = null
            CONTINUE


      STEP 2B: Type Conversion
        SWITCH columnType:

          CASE "STRING":
            normalizedRow[columnName] = String(expectedValue)

          CASE "INTEGER":
            IF isNaN(expectedValue):
              THROW error "Invalid integer for {columnName}"
            normalizedRow[columnName] = parseInt(expectedValue)

          CASE "FLOAT":
            IF isNaN(expectedValue):
              THROW error "Invalid float for {columnName}"
            normalizedRow[columnName] = parseFloat(expectedValue)

          CASE "BOOLEAN":
            normalizedRow[columnName] = Boolean(expectedValue)

          CASE "DATE":
            IF not valid ISO date:
              THROW error "Invalid date for {columnName}"
            normalizedRow[columnName] = parseDate(expectedValue)

          CASE "TIMESTAMP":
            IF not valid ISO timestamp:
              THROW error "Invalid timestamp for {columnName}"
            normalizedRow[columnName] = parseTimestamp(expectedValue)


      STEP 2C: Field-Specific Validation
        IF columnName == "id":
          IF not unique across batch:
            THROW error "Duplicate id: {expectedValue}"

        IF columnName == "date":
          IF date is future:
            LOG warning: "Future date in row"

    ENDFOR


  STEP 3: Return Normalized Row
    RETURN normalizedRow

END
```

---

## 13. Data Transformation Summary

```
Fitbit API Response
  │
  ├─ Identify endpoint type & target table(s)
  │
  ├─ IF nested array structure:
  │   ├─ Extract array from response
  │   ├─ FOR EACH element:
  │   │   ├─ Create row with element fields
  │   │   ├─ Add parent fields (date, user_id)
  │   │   └─ Add metadata (project, participant, device)
  │   └─ Output: Array of rows
  │
  ├─ ELSE IF summary structure:
  │   ├─ Extract fields from response object
  │   ├─ Create single row or few rows
  │   ├─ Add metadata
  │   └─ Output: Array with 1 row
  │
  ├─ Type conversions (strings → dates, timestamps, numbers)
  │
  ├─ Normalize field names (camelCase → snake_case)
  │
  ├─ Add metadata columns:
  │   ├─ project_id
  │   ├─ participant_id
  │   ├─ device_id
  │   ├─ fetch_timestamp
  │   └─ endpoint
  │
  ├─ Validate against BigQuery schema
  │
  ├─ Batch by table name
  │
  └─ Insert into BigQuery
```

---

## 14. Conversion Edge Cases

### Handling Empty or Missing Data

```
SCENARIOS:

1. Empty Array
   INPUT: { "activities": [] }
   OUTPUT: [] (skip this table, no rows to insert)

2. Missing Optional Fields
   INPUT: { "heart_rate": 72 }  (confidence field missing)
   OUTPUT: { heart_rate: 72, confidence: null }

3. Null Values
   INPUT: { "heart_rate": null }
   OUTPUT: IF required: THROW error
           IF optional: { heart_rate: null }

4. Wrong Data Type
   INPUT: { "heart_rate": "seventy-two" }
   OUTPUT: THROW error "Invalid integer value"

5. String Date in Timestamp Field
   INPUT: { "startTime": "2024-05-07" }  (missing time)
   OUTPUT: { startTime: "2024-05-07T00:00:00Z" }
           (assume midnight if time missing)

6. Multiple Records Same Date
   INPUT: "activities" array with 5 items, all date "2024-05-07"
   OUTPUT: 5 separate rows (not aggregated)
           Each row has unique id (based on timestamp or name)

7. Nested Objects
   INPUT: { "stages": { "deep": 3600, "light": 7200 } }
   OUTPUT: Flatten to separate columns:
           { stages_deep: 3600, stages_light: 7200 }
```

---

## 15. Performance Considerations

### Optimization Strategies

```
1. PARALLEL CONVERSION
   - Convert multiple sensors simultaneously
   - Use Promise.allSettled() for concurrent processing
   - Non-blocking: one sensor error doesn't block others

2. BATCH SPLITTING
   - Split large datasets (>10,000 rows) into 5000-row batches
   - Process batches sequentially to manage memory
   - Reduces timeout risk for large API responses

3. STREAMING INSERTS
   - Stream rows to BigQuery as they're converted
   - Don't accumulate all rows in memory
   - Insert per-table as conversion completes

4. FIELD INDEXING
   - Pre-compute unique row ids for deduplication
   - Use hash functions for id generation
   - Prevents duplicate inserts on retries

5. SCHEMA CACHING
   - Cache table schemas in memory
   - Reduce Firestore lookups for schema definitions
   - Invalidate cache after schema updates
```

---

## 16. Output Data Types

### BigQuery Ready Format

```
Final Row Format (per table):
{
  "id": "uuid-or-hash",
  "date": DATE,
  "user_id": STRING,
  "timestamp": TIMESTAMP (or null),

  // Table-specific fields
  [field_name_1]: TYPE,
  [field_name_2]: TYPE,
  ...

  // Metadata
  "project_id": STRING,
  "participant_id": STRING,
  "device_id": STRING,
  "fetch_timestamp": TIMESTAMP,
  "endpoint": STRING,
  "source_ref": STRING (Firestore doc id)
}

Table Output Example:
{
  "heart_rate_intraday": [
    { id, date, user_id, timestamp, heart_rate, confidence, ... },
    { id, date, user_id, timestamp, heart_rate, confidence, ... },
    ...
  ],
  "activity_steps": [
    { id, date, user_id, timestamp, steps, ... },
    ...
  ],
  "sleep": [
    { id, date, user_id, start_time, end_time, duration, ... },
  ],
  ...
}
```
