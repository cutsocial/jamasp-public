# Backend Architecture: cronJobFetch Process

## Overview
The cronJobFetch system is an external Cloud Run microservice that automatically fetches selected sensor data from Fitbit devices and converts it into BigQuery table instances. This document describes the high-level process flow using pseudocode.

**Note:** This service runs external to the main web application repository. It is deployed as a Cloud Run service and called by the frontend scheduler or manual triggers via HTTP endpoints.

---

## Architecture Context

### What Is In This Repo vs External Service
- **In the frontend repo (cutsocial):**
  - Project cron sensor selection and settings are managed in the web app admin UI.
  - A scheduled Firebase Function scans projects and triggers fetch endpoints.
  - Fitbit auth/token lifecycle helpers are defined for participants.
  - BigQuery dataset/table schema definitions exist.

- **In this external Cloud Run service (fitbit-oauth-service):**
  - The actual endpoint that does cron fetching and transformation.
  - Endpoint-by-endpoint Fitbit fetch and BigQuery row insertion.
  - Token refresh and validation.
  - Payload normalization and conversion to BigQuery schema.

---

## 1. Cron Job Initialization Flow

### Entry Point: `/fetchCronData` Endpoint

```
FUNCTION fetchCronData(request):

  STEP 1: Determine Download Date
    IF request.downloadDate is provided:
      SET downloadDate = parseDate(request.downloadDate)
    ELSE:
      SET downloadDate = TODAY - 1 day

    SET downloadDate.time = 00:00:00 (midnight)


  STEP 2: Fetch Project Configuration
    GET projectId FROM request.query.project_id
    RETRIEVE project document FROM Firestore "projects" collection

    IF project NOT FOUND:
      RETURN error 404


  STEP 3: Filter Enabled Sensors
    GET all sensors FROM cronJobSensors (pre-defined list)
    FOR each sensor in cronJobSensors:
      IF project.cronSettings contains sensor AND setting.enabled == TRUE:
        ADD sensor TO cronSensorsToDownload

    IF cronSensorsToDownload is empty:
      RETURN error 404


  STEP 4: Initialize Fetch Job Record
    CREATE cronJobHistory object:
      - projectId: project ID
      - status: "running"
      - type: "cron"
      - startedAt: current timestamp
      - date: downloadDate
      - downloadSettings: project.cronSettings
      - devices: [] (empty, will be populated)
      - outputFile: null (will be set after export)
      - bigQueryResults: null (will be set after insertion)

    SAVE cronJobHistory TO Firestore "fetchCronJobs" collection
    STORE cronFetchJobId FOR later reference


  STEP 5: Initialize Data Containers
    CREATE unifiedFetchResultsData object:
      - projectId: project ID
      - date: downloadDate
      - devices: [] (will accumulate all device results)

    CREATE combined_bq_data object: {} (will accumulate BigQuery rows)

  STEP 6: Process All Devices (Parallel)
    FOR each device in project.devices (in parallel using Promise.allSettled):
      CALL processDeviceData(device, project, downloadDate, ...)
```

---

## 2. Token Management & Validation

### Token Refresh Guard

```
FUNCTION ensureValidToken(fitbitToken, participantId):

  IF fitbitToken is expired OR needs refresh:
    LOG info: "Token expired or missing, refreshing..."

    STEP 1: Call Fitbit OAuth API
      newTokenResponse = FitbitOAuth.POST https://api.fitbit.com/oauth2/token {
        grant_type: "refresh_token",
        refresh_token: fitbitToken.refresh_token,
        Authorization: "Basic {base64(clientID:clientSecret)}"
      }

    STEP 2: Validate Response
      IF newTokenResponse contains error:
        LOG error: "Failed to refresh token for participant {participantId}"
        THROW TokenRefreshError
      ENDIF

    STEP 3: Persist New Token
      refreshedToken = {
        access_token: newTokenResponse.access_token,
        refresh_token: newTokenResponse.refresh_token,
        expires_in: newTokenResponse.expires_in,
        timestamp: now()
      }

      Firestore.participants.doc(participantId).update({
        fitbitData: refreshedToken
      })

      RETURN refreshedToken

  ELSE:
    LOG debug: "Token still valid"
    RETURN fitbitToken

  ENDIF

END

FUNCTION checkTokenExpiration(fitbitToken, offset = 0):
  now = currentTime()
  expiration = fitbitToken.timestamp + (fitbitToken.expires_in * 1000)
  RETURN (now > expiration + offset)
END
```

---

## 3. Device Data Processing Flow

### Process Each Device in Parallel

```
FUNCTION processDeviceData(device, project, downloadDate, cronSensorsToDownload):

  STEP 1: Initialize Device Result Container
    CREATE unifiedDeviceFetchResultsArray:
      - deviceId: device ID
      - user_id: null (will be set from participant)
      - endpoints: [] (will accumulate sensor results)

    CREATE cronJobHistoryDeviceUnified:
      - deviceId: device ID
      - endpoints: [] (will accumulate fetch metadata)
      - outputFile: null
      - projectId: project ID
      - participantUid: null (will be set)
      - prolificId: null (will be set)


  STEP 2: Retrieve Participant & Authenticate
    TRY:
      RETRIEVE participant FROM Firestore WHERE fitbitUserId == device

      UPDATE participant references:
        - unifiedDeviceFetchResultsArray.user_id = participant.uid
        - cronJobHistoryDeviceUnified.participantUid = participant.uid
        - cronJobHistoryDeviceUnified.prolificId = participant.pId

      GET fitbitData FROM participant

      CALL fitbitOAuth.checkAndRefreshToken(participant.uid, fitbitData)
      IF token was refreshed:
        UPDATE fitbitData.access_token

    CATCH error:
      LOG error for this device
      RETURN (device processing fails for this device)


  STEP 3: Fetch Data for All Enabled Sensors (Parallel per device)
    FOR each sensor in cronSensorsToDownload (in parallel):
      CALL fetchSensorData(sensor, device, participant, downloadDate, cronSettings)

---

## 4. Sensor Data Fetching & Conversion

### Fetch Individual Sensor Data

```
FUNCTION fetchSensorData(sensor, device, participant, downloadDate, cronSettings):

  STEP 1: Build API Endpoint Configuration
    GET sensor configuration:
      - sensor.id: unique sensor identifier
      - sensor.label: human-readable name (e.g., "Heart Rate Intraday")

    RETRIEVE cronSettings FOR this sensor FROM project.cronSettings

    UPDATE cronSettings:
      - arguments["user-id"] = device ID

    CREATE apiEndpoint object:
      - sensor: sensor.label
      - endpointUrl: GENERATE from sensor definition + cronSettings + downloadDate
      - axiosConfig: GENERATE with Fitbit auth headers from fitbitData.access_token
      - projectId: project ID
      - date: downloadDate
      - device_id: device ID
      - sensorId: sensor.id
      - user_id: participant.uid
      - participantUid: participant.uid


  STEP 2: Make HTTP Request to Fitbit API
    CALL fetchDataForSensor(apiEndpoint):
      TRY:
        MAKE HTTP GET request TO endpointUrl
        INCLUDE Authorization header: "Bearer {accessToken}"
        INCLUDE Content-Type: "application/json"

        RETURN response with:
          - response.status: HTTP status code
          - response.data: JSON data from Fitbit

      CATCH error:
        HANDLE rate limiting, token expiry, connection errors
        RETURN error object


  STEP 3: Validate & Store Raw Response
    STORE raw endpoint response in Firestore:
      - Collection: "fitbitEndpointsData"
      - Data includes: projectId, deviceId, userId, endpoint, date, status, data
      - SAVE reference ID FOR later tracking


  STEP 4: Convert Fitbit Data to BigQuery Schema
    RETRIEVE raw response data FROM Fitbit API

    IF data is null, undefined, or empty:
      LOG warning
      CONTINUE to next sensor (skip conversion)

    CALL convertEndpointDataToTabularJson(
      endpoint_name,
      fitbit_data,
      participant_uid,
      endpoint_url,
      firestore_ref_id,
      project_id
    )

    This function transforms Fitbit's nested JSON structure into:
      RETURN bigQueryItem = {
        "table_name_1": [ {row1}, {row2}, ... ],
        "table_name_2": [ {row1}, {row2}, ... ],
        ...
      }


  STEP 5: Aggregate BigQuery Rows
    FOR each tableName in bigQueryItem:
      GET normalizedData = bigQueryItem[tableName]

      IF normalizedData is empty:
        LOG error
        CONTINUE to next table

      IF combined_bq_data[tableName] already exists:
        APPEND normalizedData TO combined_bq_data[tableName]
      ELSE:
        CREATE combined_bq_data[tableName] = normalizedData

    STORE metadata in cronJobHistoryDeviceUnified.endpoints


  STEP 6: Track Sensor Fetch Result
    CREATE endpoint metadata:
      - endpoint: sensor name
      - sensorId: sensor ID
      - settings: sensor configuration used
      - status: HTTP response status
      - errors: any errors encountered
      - fetchJobId: cron job ID (for linking)
      - timestamp: fetch timestamp
      - date: downloadDate
      - endpointDataRef: Firestore document ID of raw data

    ADD metadata TO:
      - cronJobHistoryDeviceUnified.endpoints[]
      - unifiedDeviceFetchResultsArray.endpoints[]

  RETURN Promise result to device processor
```

---

## 5. Sensor-to-Table Mapping Logic

### After All Devices Complete

```
FUNCTION aggregateAndExportResults(unifiedFetchResultsData, cronJobHistory, combined_bq_data):

  STEP 1: Build Unified Results
    FOR each device result:
      ADD device result TO unifiedFetchResultsData.devices[]
      ADD device history TO cronJobHistory.devices[]


  STEP 2: Export to Cloud Storage
    CREATE filePath:
      FORMAT: "{projectId}/{cronFetchJobId}/all_unified_{YYYY-MM-DD}.json"

    SERIALIZE unifiedFetchResultsData TO JSON

    UPLOAD JSON TO Cloud Storage bucket "jamasp-fitbit"

    IF upload successful:
      UPDATE cronJobHistory.outputFile = filePath
      UPDATE cronJobHistory.status = "done"
      UPDATE Firestore "fetchCronJobs" document
    ELSE:
      LOG error (continue anyway, data still in combined_bq_data)
```

---

## 6. BigQuery Insertion Flow

### Batch Insert All Accumulated Data

```
FUNCTION insertBatchIntoBigQuery(datasetId, combined_bq_data):

  SET MAX_BATCH_SIZE = 5000 rows per batch
  CREATE results object TO track insertion results

  FOR each tableName in combined_bq_data:
    GET tableData = combined_bq_data[tableName]

    IF tableData is empty or invalid:
      SKIP this table
      CONTINUE

    INITIALIZE tracking FOR this table:
      - totalRows: count of rows to insert
      - batchesProcessed: counter
      - insertedRows: counter
      - errors: error log


    SPLIT tableData INTO batches of MAX_BATCH_SIZE:
      FOR each batch in batches:

        STEP 1: Normalize Data
          CALL normalizeData(batch):
            - Remove null/undefined fields
            - Validate field types match BigQuery schema
            - Convert dates to proper format
            - Handle nested objects if applicable


        STEP 2: Insert Batch into BigQuery
          TRY:
            GET table reference FROM bigquery.dataset(datasetId).table(tableName)

            CALL table.insert(normalizedBatch):
              - BigQuery client handles table creation if needed
              - Insert normalized rows into table

            RETRIEVE response:
              - insertedRows: count of successfully inserted rows
              - insertErrors: list of any validation/insert errors

            IF insertErrors exist:
              LOG each error with row number and error message
            ELSE:
              RECORD successful insertion

            UPDATE tracking:
              - batchesProcessed++
              - insertedRows += rows inserted

          CATCH error:
            LOG insertion error
            ADD error TO results[tableName].errors
            CONTINUE to next batch (non-blocking)

  RETURN results object with summary of:
    - Total batches processed
    - Total rows inserted per table
    - Any errors encountered
```

---

## 7. Final Job Completion

### Record Job History & Update Project

```
FUNCTION completeJob(cronJobHistory, projectId, bqResults):

  STEP 1: Update Job Status
    UPDATE cronJobHistory:
      - status: "done"
      - bigQueryResults: bqResults (insertion summary)

    SAVE updated cronJobHistory TO Firestore


  STEP 2: Record in Project History
    CREATE cronJobHistoryProject:
      - projectId: project ID
      - status: "done"
      - type: "cron"
      - startedAt: job start time
      - cronJobHistoryId: reference to full job history
      - outputFile: path to exported JSON

    UPDATE Firestore project document:
      - SET runCronJob = "done"
      - APPEND cronJobHistoryProject TO downloadHistory array
      - APPEND cronJobHistoryProject TO cronJobHistory array


  STEP 3: Return Results
    RETURN cronJobHistory object to API client

    Response includes:
      - Job status and timing
      - List of all devices processed
      - Details of each sensor fetch
      - BigQuery insertion results
      - Cloud Storage export path
```

---

## 8. Data Transformation: Fitbit → BigQuery Schema

### Conversion Process Detail

```
FUNCTION convertEndpointDataToTabularJson(endpointName, fitbitData, userId, endpointUrl, refId, projectId):

  STEP 1: Identify Endpoint Type & Target Table(s)
    LOOKUP endpoint mapping:
      - Different Fitbit endpoints map to different BigQuery tables
      - E.g., "Heart Rate Intraday" → "heart_rate_intraday" table
      - E.g., "Activity Steps" → "activity_steps" table

    GET tableNames FROM endpoint → table mapping


  STEP 2: Extract Relevant Data Fields
    DEPENDING on endpoint type:
      - Parse activities data (steps, calories, floors, elevation, distance)
      - Parse sleep data (duration, quality, stages)
      - Parse heart rate data (heart rate values, zones)
      - Parse breathing rate data
      - Parse device info (battery level, sync time)
      - Parse badges and achievements


  STEP 3: Normalize to Tabular Format
    FOR each record in fitbit_data:
      CREATE bigQueryRow object:
        - id: generate unique ID (typically: userId + timestamp + sensorId)
        - date: downloadDate (for partitioning/querying)
        - user_id: participant UID
        - timestamp: specific time of measurement (if available)
        - [field_1]: extracted metric value
        - [field_2]: extracted metric value
        - ...
        - metadata: source info (endpoint, external ID, etc.)

    ADD bigQueryRow TO appropriate table array


  STEP 4: Organize into Tables
    CREATE return object:
      {
        "table_name_1": [ row1, row2, row3, ... ],
        "table_name_2": [ row1, row2, ... ],
        ...
      }

    RETURN organized table data
```

---

## 9. Error Handling & Resilience

### Error Recovery Mechanisms

```
OVERALL PATTERN: Parallel Processing with Error Isolation

DEVICE LEVEL:
  IF one device fails:
    - Log error for that device
    - Continue processing other devices
    - Partial results still get exported and inserted

SENSOR LEVEL (per device):
  IF one sensor fetch fails:
    - Log error
    - Continue fetching next sensor
    - Other sensor data still gets processed

BIGQUERY INSERTION LEVEL:
  IF one batch fails:
    - Log error for that batch
    - Continue with next batch
    - Partial insertion still completes for other tables

TOKEN EXPIRATION:
  BEFORE any Fitbit API call:
    - Check if access token is expired
    - IF expired: Call fitbitOAuth.checkAndRefreshToken()
    - IF refresh fails: Log error, skip device
```

---

## 10. Data Flow Diagram

```
START: /fetchCronData endpoint triggered
  |
  ├─→ Load project config & enabled sensors
  |
  ├─→ Create job record in Firestore
  |
  ├─→ FOR EACH DEVICE (parallel):
  |    |
  |    ├─→ Authenticate Fitbit user
  |    |
  |    ├─→ FOR EACH SENSOR (parallel per device):
  |    |    |
  |    |    ├─→ Build Fitbit API endpoint URL
  |    |    |
  |    |    ├─→ Make HTTP request to Fitbit API
  |    |    |
  |    |    ├─→ Store raw response in Firestore
  |    |    |
  |    |    ├─→ Convert response to BigQuery schema
  |    |    |
  |    |    ├─→ Accumulate rows in combined_bq_data
  |    |    |
  |    |    └─→ Store metadata in job history
  |    |
  |    └─→ Accumulate device results
  |
  ├─→ All devices complete (Promise.allSettled)
  |
  ├─→ Export unified results to Cloud Storage
  |
  ├─→ Batch insert combined_bq_data into BigQuery:
  |    |
  |    ├─→ FOR EACH TABLE in combined_bq_data:
  |    |    |
  |    |    ├─→ Split rows into MAX_BATCH_SIZE chunks
  |    |    |
  |    |    ├─→ FOR EACH BATCH:
  |    |    |    |
  |    |    |    ├─→ Normalize data
  |    |    |    |
  |    |    |    ├─→ Call BigQuery insert API
  |    |    |    |
  |    |    |    └─→ Track results/errors
  |    |    |
  |    |    └─→ Continue to next batch (non-blocking on errors)
  |    |
  |    └─→ Continue to next table
  |
  ├─→ Update job status to "done"
  |
  ├─→ Record history in project document
  |
  └─→ Return job results to caller
     END
```

---

## 11. Key Data Structures

### cronJobHistory (Firestore Document)
```
{
  projectId: string,
  status: "running" | "done",
  type: "cron",
  startedAt: timestamp,
  date: date,
  downloadSettings: [ { sensorId, enabled, arguments } ],
  devices: [
    {
      deviceId: string,
      endpoints: [
        {
          endpoint: string,
          sensorId: string,
          settings: object,
          status: number,
          errors: string,
          timestamp: date,
          endpointDataRef: string
        }
      ],
      participantUid: string,
      prolificId: string
    }
  ],
  outputFile: string,
  bigQueryResults: object
}
```

### combined_bq_data (In-Memory)
```
{
  "heart_rate_intraday": [
    { id, date, user_id, timestamp, heart_rate, zone, ... },
    ...
  ],
  "activity_steps": [
    { id, date, user_id, timestamp, steps, ... },
    ...
  ],
  "sleep": [
    { id, date, user_id, duration, quality, ... },
    ...
  ],
  ...
}
```

---

## 12. Performance Considerations

- **Parallel Device Processing**: All devices are processed simultaneously using `Promise.allSettled()`
- **Parallel Sensor Processing**: Within each device, all sensors are fetched in parallel
- **Batch BigQuery Inserts**: Large datasets are split into 5000-row batches
- **Non-blocking Error Handling**: Errors in one batch/sensor/device don't block others
- **Cloud Storage Buffering**: Results are exported to Cloud Storage before BigQuery insertion (provides audit trail)

---

## 13. HTTP Request Patterns

### Entry Point Endpoints

All requests from frontend scheduler or manual triggers use **GET** with query parameters.

#### 1. Automatic Scheduled Fetch

**Triggered by:** Firebase Scheduler (daily at 0 1 * * * UTC)
**Caller:** admin/modules/scheduler.js (in frontend repo)
**Endpoint:** `/fetchCronData`
**HTTP Method:** GET

```
GET https://jamasp-fitbit-oauth-service-730427234084.us-central1.run.app/fetchCronData?project_id=project-abc123
```

**Query Parameters:**
- `project_id` (required): The project ID to fetch cron data for

**Backend Processing:**
```
1. Load project configuration from Firestore
2. Get list of enabled sensors from project.cronSettings
3. For each device in project.devices:
   a. Authenticate participant with Fitbit
   b. For each enabled sensor:
      - Build Fitbit API endpoint
      - Fetch data from Fitbit
      - Transform to BigQuery rows
4. Batch insert all rows into BigQuery
5. Export unified results to Cloud Storage
6. Update Firestore job history
```

**Response:**
```json
{
  "projectId": "project-abc123",
  "status": "done",
  "type": "cron",
  "startedAt": "2024-05-07T01:15:32.000Z",
  "date": "2024-05-06T00:00:00.000Z",
  "devices": [
    {
      "deviceId": "fitbit_user_id_123456",
      "endpoints": [
        {
          "endpoint": "Heart Rate Intraday",
          "sensorId": "HeartRate_Intraday_byDate",
          "status": 200,
          "errors": "null",
          "timestamp": "2024-05-07T01:16:45.000Z"
        }
      ]
    }
  ],
  "outputFile": "project-abc123/cron-fetch-job-xyz/all_unified_2024-05-06.json",
  "bigQueryResults": {
    "heart_rate_intraday": {
      "totalRows": 1440,
      "batchesProcessed": 1,
      "insertedRows": 1440,
      "errors": []
    }
  }
}
```

---

#### 2. Manual Single-Day Download

**Triggered by:** Admin clicking "Start Download Job"
**Caller:** ShowProject.js (in frontend repo)
**Endpoint:** `/fetchData`
**HTTP Method:** GET

```
GET https://jamasp-fitbit-oauth-service-730427234084.us-central1.run.app/fetchData?project_id=project-abc123
```

**Query Parameters:**
- `project_id` (required): The project ID

**Backend Processing:**
- Reads `project.downloadSettings` (not cronSettings)
- Otherwise similar to cron fetch flow

---

#### 3. Manual Range-Based Download

**Triggered by:** Admin clicking "Start Range Download Job"
**Caller:** ShowProject.js (in frontend repo)
**Endpoint:** `/fetchRangeData`
**HTTP Method:** GET

```
GET https://jamasp-fitbit-oauth-service-730427234084.us-central1.run.app/fetchRangeData?project_id=project-abc123
```

**Query Parameters:**
- `project_id` (required): The project ID

**Backend Processing:**
- Reads `project.rangeDownloadSettings`
- Uses `rangeDownloadSettings["start-date"]` and `rangeDownloadSettings["end-date"]`
- Iterates through date range and fetches data for each day
- Aggregates all results across the range

---

#### 4. Manual Participant Data Fetch & Email

**Triggered by:** Participant clicking "Download Data" in registration
**Caller:** RegistrationContext.js (in frontend repo)
**Endpoint:** `/downloadAndEmailData`
**HTTP Method:** GET

```
GET https://jamasp-fitbit-oauth-service-730427234084.us-central1.run.app/downloadAndEmailData?downloadDate=2024-05-07&project_id=project-abc123&participant_id=user-xyz&participant_email=user@example.com
```

**Query Parameters:**
- `downloadDate` (required): Date to fetch (format: YYYY-MM-DD)
- `project_id` (required): The project ID
- `participant_id` (required): Participant document ID
- `participant_email` (required): Email address for delivery

**Backend Processing:**
```
1. Validate all parameters are present
2. Load project and participant from Firestore
3. Fetch configured sensors for that participant on specified date
4. Transform data
5. Package into shareable format (ZIP file)
6. Email results to participant email address
7. Update participant registration status
```

---

## 14. Data Inputs from Firestore

### Project Document
```javascript
{
  id: string,
  settings: {
    enabled: boolean,
    dateRange: { from: Timestamp, to: Timestamp }
  },
  devices: string[],           // Fitbit user IDs
  cronSettings: CronSetting[],
  downloadSettings: DownloadSetting[],
  rangeDownloadSettings: RangeDownloadSetting[],
  bigQueryDataset: string      // "jamasp_fitbit"
}
```

### Participant Document
```javascript
{
  uid: string,
  pId: string,                 // Prolific ID (if applicable)
  fitbitData: {
    access_token: string,
    refresh_token: string,
    expires_in: number,
    timestamp: Timestamp
  }
}
```

### BigQuery Dataset
```
dataset_id: "jamasp_fitbit"
tables: [
  { name: "heart_rate_intraday", schema: [...] },
  { name: "heart_rate_summary", schema: [...] },
  { name: "activity_steps", schema: [...] },
  { name: "sleep", schema: [...] },
  { name: "device", schema: [...] },
  { name: "badges", schema: [...] },
  ...
]
```

---

## 15. Architecture Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                       FRONTEND REPO (cutsocial)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Admin UI (ShowProject.js)                                       │
│  ├── Configure cronSettings (sensor selection + arguments)       │
│  ├── Save to Firestore: projects.{projectId}.cronSettings        │
│  └── Manual triggers: /fetchData, /fetchRangeData, etc.         │
│                                                                   │
│  Scheduler (admin/modules/scheduler.js)                          │
│  ├── Runs daily at 0 1 * * * UTC                                │
│  ├── Query projects with cronSettings                            │
│  ├── Filter eligible projects                                    │
│  └── Call: GET /fetchCronData?project_id={projectId}            │
│                                                                   │
│  Firestore                                                        │
│  ├── projects.{projectId}.cronSettings                           │
│  ├── projects.{projectId}.devices                                │
│  ├── projects.{projectId}.settings                               │
│  ├── participants.{participantId}.fitbitData                     │
│  └── projects.{projectId}.downloadHistory                        │
│                                                                   │
└────────────────────────────┬────────────────────────────────────┘
                             │
                 HTTP GET Request (query params)
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│               BACKEND SERVICE (Cloud Run)                         │
│            fitbit-oauth-service (this repo)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Endpoints                                                        │
│  ├── /fetchCronData?project_id=X          (automated daily)      │
│  ├── /fetchData?project_id=X              (manual single-day)    │
│  ├── /fetchRangeData?project_id=X         (manual range)         │
│  └── /downloadAndEmailData?downloadDate=X (participant export)   │
│                                                                   │
│  Processing Pipeline                                             │
│  ├── 1. Load project config from Firestore                       │
│  ├── 2. Get participant & validate tokens (refresh if needed)    │
│  ├── 3. Construct Fitbit API endpoints from cronSettings         │
│  ├── 4. Call Fitbit API endpoints (parallel per device)          │
│  ├── 5. Store raw responses in Firestore (fitbitEndpointsData)   │
│  ├── 6. Transform responses to BigQuery schema (normalize)       │
│  ├── 7. Batch insert normalized rows into BigQuery               │
│  ├── 8. Export unified results to Cloud Storage                  │
│  └── 9. Update Firestore job history                             │
│                                                                   │
│  External Services Called                                        │
│  ├── Fitbit API (https://api.fitbit.com)                        │
│  ├── Firestore (get projects, participants, store results)       │
│  ├── BigQuery (insert normalized data)                           │
│  ├── Cloud Storage (export JSON results)                         │
│  └── Gmail (optional: email results)                             │
│                                                                   │
│  Firestore Collections Updated                                   │
│  ├── fetchCronJobs.{jobId}                 (job history)         │
│  ├── fitbitEndpointsData.{docId}           (raw responses)       │
│  ├── projects.{projectId}.downloadHistory  (job summary)         │
│  └── projects.{projectId}.cronJobHistory   (cron-specific)       │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```


