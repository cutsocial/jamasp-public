# Data Retrieval: Pseudocode & Flow

This document describes how data flows from the frontend through Firestore to the Fitbit API and back to Cloud Storage.

---

## 1. Frontend Configuration Retrieval

### Load Project & Cron Settings

```
FUNCTION loadProjectCronSettings(projectId):

  STEP 1: Query Firestore for Project Document
    TRY:
      project = Firestore.collection("projects")
        .doc(projectId)
        .get()

      IF project NOT FOUND:
        THROW error "Project not found"

    CATCH error:
      LOG error: "Failed to load project {projectId}"
      THROW error


  STEP 2: Extract Configuration
    cronSettings = project.data().cronSettings
    devices = project.data().devices
    settings = project.data().settings

    VALIDATE:
      - cronSettings is array
      - devices is array and not empty
      - settings.enabled == true
      - current date in settings.dateRange


  STEP 3: Filter Enabled Sensors
    enabledSensors = cronSettings.filter(s => s.enabled == true)

    IF enabledSensors.length == 0:
      THROW error "No enabled sensors in cron settings"


  STEP 4: Return Configuration
    RETURN {
      projectId: projectId,
      devices: devices,
      cronSettings: cronSettings,
      enabledSensors: enabledSensors,
      projectSettings: settings
    }

END
```

---

## 2. Participant & Authentication Retrieval

### Get Participant and Fitbit Tokens

```
FUNCTION getParticipantAndTokens(deviceId):

  STEP 1: Query for Participant by Fitbit User ID
    TRY:
      participant = Firestore.collection("participants")
        .where("fitbitData.user_id", "==", deviceId)
        .limit(1)
        .get()

      IF participant.empty:
        LOG warning: "No participant found for device {deviceId}"
        RETURN null

    CATCH error:
      LOG error: "Failed to query participant"
      THROW error


  STEP 2: Extract Fitbit Authentication Data
    participantData = participant.docs[0].data()

    EXTRACT:
      - participantId = participant.docs[0].id
      - fitbitData = participantData.fitbitData
      - access_token = fitbitData.access_token
      - refresh_token = fitbitData.refresh_token
      - expires_in = fitbitData.expires_in
      - timestamp = fitbitData.timestamp


  STEP 3: Validate Required Fields
    IF access_token is missing OR null:
      THROW error "No access token for participant {participantId}"


  STEP 4: Return Participant Info
    RETURN {
      participantId: participantId,
      deviceId: deviceId,
      fitbitData: fitbitData,
      access_token: access_token,
      refresh_token: refresh_token
    }

END
```

---

## 3. Token Validation & Refresh

### Check and Refresh Token if Needed

```
FUNCTION checkAndRefreshToken(participantId, fitbitData):

  STEP 1: Check Token Expiration
    now = currentTime()
    tokenExpiration = fitbitData.timestamp.toMillis() + (fitbitData.expires_in * 1000)

    IF now <= tokenExpiration:
      LOG debug: "Token still valid for participant {participantId}"
      RETURN fitbitData (no refresh needed)


  STEP 2: Prepare OAuth Refresh Request
    LOG info: "Token expired, initiating refresh for {participantId}"

    CREATE refreshRequest:
      - grant_type: "refresh_token"
      - refresh_token: fitbitData.refresh_token
      - client_id: env.FITBIT_CLIENT_ID
      - client_secret: env.FITBIT_CLIENT_SECRET

    CREATE authHeader:
      - base64Encoded = base64(clientId + ":" + clientSecret)
      - Authorization: "Basic " + base64Encoded


  STEP 3: Call Fitbit OAuth API
    TRY:
      response = HTTP.POST {
        url: "https://api.fitbit.com/oauth2/token",
        headers: {
          "Authorization": authHeader,
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: queryString(refreshRequest)
      }

      IF response.status != 200:
        LOG error: "Token refresh failed with status {response.status}"
        THROW error

    CATCH error:
      LOG error: "Error calling Fitbit OAuth: {error}"
      THROW TokenRefreshError


  STEP 4: Extract New Token from Response
    newTokenData = response.data

    EXTRACT:
      - newAccessToken = newTokenData.access_token
      - newRefreshToken = newTokenData.refresh_token
      - newExpiresIn = newTokenData.expires_in
      - currentTime = now()


  STEP 5: Persist New Token to Firestore
    TRY:
      Firestore.collection("participants")
        .doc(participantId)
        .update({
          "fitbitData": {
            access_token: newAccessToken,
            refresh_token: newRefreshToken,
            expires_in: newExpiresIn,
            timestamp: currentTime
          }
        })

      LOG info: "Token refreshed and saved for {participantId}"

    CATCH error:
      LOG error: "Failed to save refreshed token"
      THROW error


  STEP 6: Return Updated Token Data
    RETURN {
      access_token: newAccessToken,
      refresh_token: newRefreshToken,
      expires_in: newExpiresIn,
      timestamp: currentTime
    }

END
```

---

## 4. Fitbit API Endpoint Construction

### Build Request URL from Sensor Configuration

```
FUNCTION buildFitbitEndpointUrl(sensor, cronSettings, deviceId, downloadDate):

  STEP 1: Get Sensor Template
    sensorTemplate = cronSettings.sensorId == sensor.id

    IF sensorTemplate NOT FOUND:
      THROW error "Sensor configuration not found"

    EXTRACT:
      - baseEndpointPattern = sensor.link
        (e.g., "/1/user/[user-id]/activities/heart/date/[date]/1d/[detail-level].json")
      - arguments = sensorTemplate.arguments
      - parameters = sensorTemplate.parameters


  STEP 2: Replace Argument Placeholders
    url = baseEndpointPattern

    FOR EACH placeholder IN arguments:

      IF placeholder == "[user-id]":
        REPLACE with deviceId

      ELSE IF placeholder == "[date]":
        REPLACE with downloadDate (format: YYYY-MM-DD)

      ELSE IF placeholder == "[detail-level]":
        REPLACE with arguments["detail-level"]

      ELSE IF placeholder == "[start-time]":
        REPLACE with arguments["start-time"]

      ELSE IF placeholder == "[end-time]":
        REPLACE with arguments["end-time"]

      ELSE:
        REPLACE with arguments[placeholder] IF exists

    FINALIZE url = "https://api.fitbit.com" + url


  STEP 3: Append Query Parameters
    queryParams = parameters (timezone, sort, limit, offset, etc.)

    FOR EACH param IN queryParams:
      url.appendQueryParam(param.key, param.value)


  STEP 4: Return Constructed URL
    RETURN {
      url: finalUrl,
      method: "GET",
      headers: {
        "Authorization": "Bearer {accessToken}",
        "Content-Type": "application/json"
      }
    }

END
```

---

## 5. Fitbit API Call & Response Retrieval

### Fetch Data from Fitbit Endpoint

```
FUNCTION fetchFromFitbitAPI(endpointConfig, accessToken):

  STEP 1: Prepare HTTP Request
    requestConfig = endpointConfig

    SET headers:
      - "Authorization": "Bearer " + accessToken
      - "Content-Type": "application/json"
      - "User-Agent": "jamasp-fitbit-oauth-service/v1"


  STEP 2: Execute HTTP GET Request
    TRY:
      response = HTTP.GET(
        url: endpointConfig.url,
        headers: headers,
        timeout: 30000 // 30 seconds
      )

      LOG debug: "API call to {endpointConfig.url}"

    CATCH error:
      LOG error: "Network error calling Fitbit API: {error}"
      THROW ApiCallError


  STEP 3: Handle Rate Limiting
    IF response.status == 429 (Too Many Requests):
      retryAfter = response.headers["Retry-After"]
      LOG warning: "Rate limited, retry after {retryAfter} seconds"
      WAIT retryAfter seconds
      RETRY fetchFromFitbitAPI() // recursive retry


  STEP 4: Handle Token Expiration
    IF response.status == 401 (Unauthorized):
      LOG warning: "Access token appears invalid or expired"
      TRIGGER token refresh
      RETRY with new token


  STEP 5: Validate Response Status
    IF response.status == 404:
      LOG warning: "Endpoint not found or no data available"
      RETURN null

    IF response.status < 200 OR response.status >= 300:
      LOG error: "API error: {response.status} {response.statusText}"
      THROW error "HTTP {response.status}"


  STEP 6: Parse JSON Response
    TRY:
      responseData = JSON.parse(response.body)

    CATCH error:
      LOG error: "Failed to parse JSON response"
      THROW error


  STEP 7: Extract Rate Limit Headers
    rateLimitInfo = {
      remaining: response.headers["fitbit-rate-limit-remaining"],
      limit: response.headers["fitbit-rate-limit-limit"],
      reset: response.headers["fitbit-rate-limit-reset"]
    }

    LOG info: "Rate limit: {remaining}/{limit}, resets at {reset}"


  STEP 8: Return Response
    RETURN {
      status: response.status,
      data: responseData,
      headers: response.headers,
      rateLimit: rateLimitInfo,
      timestamp: now()
    }

END
```

---

## 6. Raw Data Storage in Firestore

### Persist Fitbit API Responses

```
FUNCTION storeRawFitbitResponse(sensorId, responseData, metadata):

  STEP 1: Prepare Storage Document
    CREATE fitbitEndpointDataDoc:
      - projectId: metadata.projectId
      - deviceId: metadata.deviceId
      - participantId: metadata.participantId
      - sensorId: sensorId
      - endpoint: metadata.endpoint
      - date: metadata.downloadDate
      - timestamp: now()
      - status: responseData.status
      - data: responseData.data
      - headers: {
          fitbit-rate-limit-remaining: responseData.headers["fitbit-rate-limit-remaining"],
          fitbit-rate-limit-limit: responseData.headers["fitbit-rate-limit-limit"],
          fitbit-rate-limit-reset: responseData.headers["fitbit-rate-limit-reset"]
        }
      - fetchDuration: metadata.fetchDuration (milliseconds)


  STEP 2: Save to Firestore
    TRY:
      docRef = Firestore.collection("fitbitEndpointsData")
        .add(fitbitEndpointDataDoc)

      docId = docRef.id

      LOG info: "Stored raw response in Firestore: {docId}"

    CATCH error:
      LOG error: "Failed to store raw response in Firestore"
      // Non-fatal error - continue processing
      docId = null


  STEP 3: Return Document Reference
    RETURN {
      documentId: docId,
      collectionPath: "fitbitEndpointsData/" + docId,
      canRetrieve: (docId != null)
    }

END
```

---

## 7. Parallel Device Retrieval Coordination

### Fetch Data for All Devices in Parallel

```
FUNCTION fetchDataForAllDevices(projectConfig):

  STEP 1: Prepare Device Processing Queue
    devices = projectConfig.devices
    cronSettings = projectConfig.enabledSensors
    downloadDate = calculateDownloadDate()

    CREATE devicePromises = []


  STEP 2: Iterate Each Device (Parallel)
    FOR EACH device IN devices:

      CREATE promise = processDevice(
        device,
        cronSettings,
        downloadDate,
        projectConfig
      )

      ADD promise TO devicePromises

    ENDFOR


  STEP 3: Wait for All Promises
    TRY:
      allResults = Promise.allSettled(devicePromises)

      FOR EACH result IN allResults:

        IF result.status == "fulfilled":
          successfulResults.push(result.value)

        ELSE IF result.status == "rejected":
          LOG error: "Device processing failed: {result.reason}"
          failedDevices.push(result.device)

    CATCH error:
      LOG error: "Error in parallel processing: {error}"
      THROW error


  STEP 4: Return Aggregated Results
    RETURN {
      successful: successfulResults,
      failed: failedDevices,
      count: {
        total: devices.length,
        succeeded: successfulResults.length,
        failed: failedDevices.length
      }
    }

END
```

---

## 8. Per-Device Sensor Retrieval

### Fetch All Sensors for Single Device

```
FUNCTION fetchSensorsForDevice(device, enabledSensors, downloadDate, accessToken):

  STEP 1: Initialize Device Data Container
    CREATE deviceData:
      - deviceId: device
      - sensors: []
      - errors: []
      - fetchedAt: now()


  STEP 2: Iterate Each Sensor (Parallel)
    CREATE sensorPromises = []

    FOR EACH sensor IN enabledSensors:

      CREATE promise = (

        STEP A: Build Endpoint URL
          endpointConfig = buildFitbitEndpointUrl(
            sensor,
            cronSettings,
            device,
            downloadDate
          )

        STEP B: Fetch Data
          response = fetchFromFitbitAPI(
            endpointConfig,
            accessToken
          )

        STEP C: Store Raw Response
          storageRef = storeRawFitbitResponse(
            sensor.sensorId,
            response,
            { deviceId: device, ... }
          )

        STEP D: Return Result
          RETURN {
            sensorId: sensor.sensorId,
            response: response,
            storageRef: storageRef
          }
      )

      ADD promise TO sensorPromises

    ENDFOR


  STEP 3: Wait for All Sensor Requests
    sensorResults = Promise.allSettled(sensorPromises)


  STEP 4: Process Results
    FOR EACH result IN sensorResults:

      IF result.status == "fulfilled":
        ADD result.value TO deviceData.sensors

      ELSE:
        LOG error: "Sensor fetch failed: {result.reason}"
        ADD error TO deviceData.errors

    ENDFOR


  STEP 5: Return Device Results
    RETURN deviceData

END
```

---

## 9. Batch Data Collection

### Aggregate Results from All Devices

```
FUNCTION aggregateAllRetrievedData(allDeviceResults):

  STEP 1: Initialize Aggregation Container
    CREATE aggregatedData:
      - devices: []
      - sensors: []
      - totalFetched: 0
      - totalErrors: 0
      - rawDataReferences: []


  STEP 2: Iterate Device Results
    FOR EACH deviceResult IN allDeviceResults.successful:

      ADD deviceResult TO aggregatedData.devices

      FOR EACH sensorData IN deviceResult.sensors:
        ADD sensorData TO aggregatedData.sensors
        ADD sensorData.storageRef TO aggregatedData.rawDataReferences
        aggregatedData.totalFetched++

      aggregatedData.totalErrors += deviceResult.errors.length

    ENDFOR


  STEP 3: Return Aggregated Data
    RETURN {
      aggregatedData: aggregatedData,
      stats: {
        devicesProcessed: allDeviceResults.count.succeeded,
        devicesFailed: allDeviceResults.count.failed,
        sensorsRetrieved: aggregatedData.totalFetched,
        errorsEncountered: aggregatedData.totalErrors
      }
    }

END
```

---

## 10. Data Flow Summary: Retrieval Path

```
┌──────────────────────┐
│  Frontend Trigger    │
│  (Scheduler or       │
│   Manual Button)     │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Load Project Config  │
│ from Firestore       │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ FOR EACH Device:     │
│                      │
│ Get Participant ID   │
│ from Firestore       │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Validate Fitbit      │
│ Access Token         │
│ (Refresh if expired) │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ FOR EACH Sensor:     │
│                      │
│ Build API Endpoint   │
│ URL from config      │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Call Fitbit API      │
│ GET endpoint         │
│ with Bearer token    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Store Raw Response   │
│ in Firestore         │
│ fitbitEndpointsData  │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Return to Caller     │
│ Raw data ready for   │
│ conversion/transform │
└──────────────────────┘
```

---

## 11. Key Retrieval Patterns

### All GET Requests to Fitbit API

```
GET https://api.fitbit.com/1/user/{user-id}/activities/heart/date/{date}/1d/{detail-level}.json
Headers:
  Authorization: Bearer {access_token}
  Content-Type: application/json

Response:
  200 OK
  {
    "activities-heart": [ ... ],
    "activities-heart-intraday": { ... }
  }
```

### Firestore Queries

```
// Load project
Firestore.collection("projects").doc(projectId).get()

// Load participant by device
Firestore.collection("participants")
  .where("fitbitData.user_id", "==", deviceId)
  .limit(1)
  .get()

// Store raw response
Firestore.collection("fitbitEndpointsData").add({...})
```

---

## 12. Error Handling in Retrieval

```
SCENARIOS:
1. Token Expired
   → Call refresh endpoint
   → Retry request with new token
   → Save new token to Firestore

2. Rate Limited (429)
   → Read Retry-After header
   → Wait specified time
   → Retry request

3. Endpoint Not Found (404)
   → Log warning
   → Continue to next sensor
   → Record as empty result

4. Unauthorized (401)
   → Assume token invalid
   → Trigger refresh
   → Retry with new token

5. Network Error
   → Log error
   → Retry up to 3 times with backoff
   → Skip this sensor if all retries fail

6. Participant Not Found
   → Log warning
   → Skip this device
   → Continue to next device
```

---

## 13. Data Types at Each Stage

### After Firestore Query (Project)
```
{
  id: "project-abc",
  cronSettings: [ { sensorId, enabled, arguments, parameters } ],
  devices: [ "fitbit_id_123", "fitbit_id_456" ],
  settings: { enabled: true, dateRange: {...} }
}
```

### After Participant Retrieval
```
{
  participantId: "user-xyz",
  deviceId: "fitbit_id_123",
  fitbitData: {
    access_token: "token...",
    refresh_token: "refresh...",
    expires_in: 3600,
    timestamp: Timestamp
  }
}
```

### After Fitbit API Call
```
{
  status: 200,
  data: {
    "activities-heart": [...],
    "activities-heart-intraday": {...}
  },
  headers: {
    "fitbit-rate-limit-remaining": "150",
    "fitbit-rate-limit-limit": "150",
    "fitbit-rate-limit-reset": "1620000000"
  },
  rateLimit: {...},
  timestamp: now()
}
```

### After Storage in Firestore
```
{
  id: "doc-abc123",
  projectId: "project-abc",
  deviceId: "fitbit_id_123",
  participantId: "user-xyz",
  sensorId: "HeartRate_Intraday_byDate",
  data: {...},
  timestamp: now(),
  collectionPath: "fitbitEndpointsData/doc-abc123"
}
```
