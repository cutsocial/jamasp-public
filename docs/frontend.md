# Frontend Architecture: Cron Job Configuration & Manual Triggers

## Overview
This document describes the frontend (web application) side of the cronJobFetch system. It covers:
- How administrators configure automatic cron-based Fitbit data collection
- How users manually trigger data downloads
- How data flows from UI configuration to backend Cloud Run service

**Note:** The frontend repo is separate from this backend service. This file documents how the frontend initiates backend operations.

---

## 1. Frontend Repository Context

### What Is In The Frontend Repo (cutsocial)
- **Admin UI Components:**
  - Project settings page with "Auto Fetch" configuration panel
  - Cron sensor selection and argument configuration
  - Manual data download triggers

- **Scheduler Function:**
  - Scheduled Firebase Function that runs daily (0 1 * * * UTC)
  - Scans eligible projects and triggers external fetch endpoints

- **Token Management:**
  - Fitbit auth/token lifecycle helpers in `fitbit-funct/index.js`
  - Token refresh logic for participant authentication

- **Schema Definitions:**
  - BigQuery dataset/table schema definitions in `admin/bigQueryUtils.js`
  - Sensor configuration schemas in `src/admin/data/sensorsCronJobSchema.js`

### What Is In This Backend Service (fitbit-oauth-service)
- Actual endpoint that performs cron fetching: `/fetchCronData`
- Endpoint-by-endpoint Fitbit API fetch
- BigQuery row insertion and data transformation
- Token refresh and API error handling

---

## 2. Frontend: Admin Setup for Cron Job Sensors

### UI Workflow

**Navigation Path:**
1. Admin logs into web app
2. Navigate to **Projects** list
3. Click on specific **Project**
4. Open **"Auto Fetch"** or **"Cron Settings"** tab
5. Configure sensor selection and parameters

**UI Components Involved:**
- Component: `ShowProject.js` (project settings page)
- Component: `CronJobPanel.js` (cron configuration panel)
- Component: Sensor selector dropdown/autocomplete

### Sensor Selection & Configuration

**Admin UI Actions:**

```
STEP 1: Open Cron Settings Panel
  Navigate to: Project > "Auto Fetch" tab

  Display:
    - List of available sensors (dropdown/autocomplete)
    - Currently selected sensors with enabled/disabled toggles
    - Configuration fields per sensor

STEP 2: Select Sensors
  Admin selects from available sensors:
    - HeartRate_Intraday_byDate
    - Activity_Steps_Intraday_byDate
    - Sleep_Log_byDate
    - Activity_Calories_Intraday_byDate
    - Device
    - Badges
    - ... (others as configured in sensorsCronJobSchema)

STEP 3: Configure Arguments Per Sensor
  For each selected sensor, admin specifies:

    user-id:
      - Auto-filled with device ID (format: "-" initially)
      - Will be replaced with actual device ID at runtime

    date:
      - Defaults to "today"
      - Can override if sensor allows different date logic

    detail-level (for intraday sensors):
      - Dropdown: "1min", "5min", "15min"
      - Only applicable to heart rate, activity intraday endpoints

    timezone (if applicable):
      - Dropdown: List of timezones
      - Defaults to project's configured timezone

    Other endpoint-specific arguments:
      - start-time, end-time (for custom time ranges)
      - limit, sort order, etc.

STEP 4: Configure Parameters
  Set query parameters for Fitbit API calls:
    - timezone: User's timezone for data interpretation
    - sort: Sort order (asc/desc)
    - limit: Maximum rows per request

STEP 5: Save Configuration
  Click "Save" button

  Action:
    - Validate all required fields are present
    - Build cronSettings array
    - Persist to Firestore project document
    - Show success/error toast notification
```

---

## 3. Firestore Storage Structure

### Project Document After Cron Configuration

```javascript
// Firestore: projects/{projectId}
{
  id: "project-abc123",
  name: "Health Study Q1 2024",

  // Enable/disable cron jobs globally
  settings: {
    enabled: true,
    dateRange: {
      from: Timestamp("2024-01-01"),
      to: Timestamp("2024-12-31")
    },
    // ... other project settings
  },

  // Cron job configuration (array of sensor configs)
  cronSettings: [
    {
      sensorId: "HeartRate_Intraday_byDate",
      enabled: true,

      // Arguments used to construct Fitbit API request
      arguments: {
        "user-id": "-",           // Replaced with device ID at runtime
        "date": "today",          // Replaced with actual date
        "detail-level": "1min"    // 1min, 5min, or 15min
      },

      // Query parameters for Fitbit API
      parameters: {
        "timezone": "America/New_York"
      }
    },

    {
      sensorId: "Sleep_Log_byDate",
      enabled: true,

      arguments: {
        "user-id": "-",
        "date": "today"
      },

      parameters: {}
    },

    {
      sensorId: "Activity_Steps_Intraday_byDate",
      enabled: false,            // Disabled, won't be fetched

      arguments: {
        "user-id": "-",
        "date": "today",
        "detail-level": "5min"
      },

      parameters: {
        "timezone": "UTC"
      }
    },

    // ... other sensors
  ],

  // List of participant Fitbit device IDs to fetch data for
  devices: [
    "fitbit_user_id_123456",
    "fitbit_user_id_789012",
    "fitbit_user_id_345678"
  ],

  // BigQuery dataset and table configuration
  bigQueryDataset: "jamasp_fitbit",

  // Download settings (separate from cron, for manual downloads)
  downloadSettings: [ /* ... */ ],
  rangeDownloadSettings: [ /* ... */ ],

  // History of all fetch jobs
  downloadHistory: [
    {
      projectId: "project-abc123",
      status: "done",
      type: "cron",
      startedAt: Timestamp("2024-05-07T01:15:32Z"),
      cronJobHistoryId: "fetch-job-xyz789",
      outputFile: "project-abc123/fetch-job-xyz789/all_unified_2024-05-07.json"
    }
  ],

  cronJobHistory: [ /* Similar to downloadHistory */ ],

  // ... other project fields
}
```

### Update Code Pattern

```javascript
// src/admin/pages/ShowProject.js - handleSaveCronSettings()

async function saveCronSettings(projectId, updatedCronSettings) {

  try {
    // Build updated project object
    const updatedProject = {
      ...project,
      cronSettings: updatedCronSettings.map(setting => ({
        sensorId: setting.sensorId,
        enabled: setting.enabled,
        arguments: {
          "user-id": "-",
          "date": setting.date || "today",
          "detail-level": setting.detailLevel || "1min",
          ...setting.customArguments
        },
        parameters: {
          "timezone": setting.timezone || "UTC",
          ...setting.customParameters
        }
      })),
      settings: {
        ...project.settings,
        enabled: true
      }
    };

    // Persist to Firestore
    await updateDoc(
      db.collection("projects").doc(projectId),
      updatedProject
    );

    // Show success message
    showNotification("Cron settings saved successfully");

  } catch (error) {
    console.error("Error saving cron settings:", error);
    showNotification("Failed to save cron settings", "error");
  }
}
```

---

## 4. Automatic Cron Trigger

### Scheduled Firebase Function

**File:** `admin/modules/scheduler.js` (in frontend repo)

**Trigger:** Daily at 0 1 * * * UTC (1:00 AM UTC)

```
START ScheduledCronRunner()

  LOG info: "Starting scheduled cron job runner"

  STEP 1: Query Projects with Cron Settings
    projects = Firestore.collection("projects")
      .where("cronSettings", "!=", null)
      .get()

  STEP 2: Filter Eligible Projects
    FOR EACH project IN projects:

      // Check if cron is enabled for this project
      IF project.settings.enabled != true:
        LOG debug: "Project {projectId} has cron disabled"
        CONTINUE
      ENDIF

      // Check if we're in the project's date range
      now = currentDateTime()
      IF now < project.settings.dateRange.from OR now > project.settings.dateRange.to:
        LOG debug: "Project {projectId} outside active date range"
        CONTINUE
      ENDIF

      // Check if there are enabled sensors
      enabledSensors = project.cronSettings.filter(s => s.enabled == true)
      IF enabledSensors.length == 0:
        LOG debug: "Project {projectId} has no enabled sensors"
        CONTINUE
      ENDIF

      // Eligible project - trigger fetch
      LOG info: "Triggering fetch for project {projectId}"
      CALL triggerCloudRunFetch(project.id)

    ENDFOR

END

FUNCTION triggerCloudRunFetch(projectId):

  cloudRunEndpoint = getCloudRunEndpoint()

  TRY:
    response = HTTP.GET(
      url: cloudRunEndpoint + "/fetchCronData",
      query: { project_id: projectId }
    )

    IF response.status == 200:
      LOG info: "Successfully triggered fetch for {projectId}"
      RETURN response.data
    ELSE:
      LOG error: "Fetch trigger failed with status {response.status}"
      RETURN error

  CATCH error:
    LOG error: "Error triggering Cloud Run fetch: {error}"
    THROW error

END
```

---

## 5. Manual Data Download Triggers

### HTTP Request Patterns

All requests use **GET** with **query parameters**. The endpoint base is configurable via Firebase Remote Config.

**Configuration Source:**

```javascript
// Firebase Remote Config
cloudRunEndpoint = remoteConfig.getValue('web/cloudRunEndpoint').asString()

// Fallback to default
// https://jamasp-fitbit-oauth-service-730427234084.us-central1.run.app/
```

### 5.1 Manual Single-Day Download (Admin)

**Triggered by:** Admin clicking "Start Download Job" button in ShowProject.js

**Endpoint:** `/fetchData`

**Query Parameters:**
- `project_id` - The project ID to fetch data for

```javascript
// src/admin/pages/ShowProject.js - handlePrepareDownload()

async function handlePrepareDownload(projectId) {

  try {
    const cloudRunEndpoint = await getCloudRunEndpoint();

    const downloadUrl = new URL(cloudRunEndpoint + '/fetchData');
    downloadUrl.searchParams.set('project_id', projectId);

    LOG info: "Initiating single-day download for project {projectId}";

    const response = await fetch(downloadUrl.toString(), {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    });

    if (response.ok) {
      const jobData = await response.json();
      LOG info: "Download job started: {jobData.id}";
      showNotification("Download started. Check status in fetch history.");
    } else {
      LOG error: "Download initiation failed";
      showNotification("Failed to start download", "error");
    }

  } catch (error) {
    console.error("Error triggering download:", error);
    showNotification("Error initiating download", "error");
  }
}
```

**Backend Behavior:**
- Reads `project.downloadSettings` (not cronSettings)
- Fetches selected download sensors for that project
- Uses current date or default date if not specified
- Similar process to cron, but uses different sensor configuration

---

### 5.2 Manual Range-Based Download (Admin)

**Triggered by:** Admin clicking "Start Range Download Job" button in ShowProject.js

**Endpoint:** `/fetchRangeData`

**Query Parameters:**
- `project_id` - The project ID to fetch data for

```javascript
// src/admin/pages/ShowProject.js - handlePrepareRangeDownload()

async function handlePrepareRangeDownload(projectId) {

  try {
    const cloudRunEndpoint = await getCloudRunEndpoint();

    const rangeUrl = new URL(cloudRunEndpoint + '/fetchRangeData');
    rangeUrl.searchParams.set('project_id', projectId);

    LOG info: "Initiating range download for project {projectId}";

    const response = await fetch(rangeUrl.toString(), {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    });

    if (response.ok) {
      const jobData = await response.json();
      LOG info: "Range download job started: {jobData.id}";
      showNotification("Range download started. This may take a while.");
    } else {
      LOG error: "Range download initiation failed";
      showNotification("Failed to start range download", "error");
    }

  } catch (error) {
    console.error("Error triggering range download:", error);
    showNotification("Error initiating range download", "error");
  }
}
```

**Backend Behavior:**
- Reads `project.rangeDownloadSettings`
- Includes date range: `rangeDownloadSettings["start-date"]` and `rangeDownloadSettings["end-date"]`
- Fetches Fitbit data across the entire date range
- May process multiple days in sequence

---

### 5.3 Manual Direct Participant Fetch (Registration Flow)

**Triggered by:** Participant clicking "Download Data" button in registration flow

**Endpoint:** `/downloadAndEmailData`

**Query Parameters:**
- `downloadDate` - Date to fetch data for (format: YYYY-MM-DD)
- `project_id` - Project ID
- `participant_id` - Participant document ID
- `participant_email` - Email address for delivery

```javascript
// src/context/RegistrationContext.js - runCronJobOnDate()

async function runCronJobOnDate(date, projectId, participantId, email) {

  try {
    // Format date as YYYY-MM-DD
    const formattedDate = formatDate(date);  // "2024-05-07"

    // Get Cloud Run endpoint
    const base = await getCloudRunEndpoint();

    // Build request URL with query parameters
    const url = new URL('downloadAndEmailData', base);
    url.searchParams.set('downloadDate', formattedDate);
    url.searchParams.set('project_id', projectId);
    url.searchParams.set('participant_id', participantId);
    url.searchParams.set('participant_email', email);

    LOG info: "Requesting data download and email for participant {participantId}";

    const response = await fetch(url.toString(), {
      method: 'GET',
      mode: 'cors',
      headers: {
        'Content-Type': 'application/json'
      }
    });

    if (response.ok) {
      const result = await response.json();
      LOG info: "Data download and email request successful";

      // Advance registration step
      advanceRegistrationStep();
      showNotification("Data download requested. Check your email shortly.");
    } else {
      LOG error: "Data download request failed with status {response.status}";
      showNotification("Failed to request data download", "error");
    }

  } catch (error) {
    console.error("Error requesting data download:", error);
    showNotification("Error requesting data download", "error");
  }
}
```

**Backend Behavior:**
- Fetches data for specific participant on specific date
- Processes data and converts to shareable format (typically ZIP file)
- Emails results directly to participant email address
- Updates participant registration status to reflect completion

---

## 6. Cloud Run Endpoint Configuration

### Firebase Remote Config Fallback

```javascript
// Helper function to get Cloud Run endpoint
async function getCloudRunEndpoint() {

  try {
    // Try to load from Firebase Remote Config first
    const remoteConfig = await getRemoteConfig();
    remoteConfig.fetchAndActivate();

    const endpoint = remoteConfig
      .getValue('web/cloudRunEndpoint')
      .asString();

    if (endpoint && endpoint.length > 0) {
      return endpoint;
    }

  } catch (error) {
    LOG warn: "Failed to fetch endpoint from Remote Config: {error}";
  }

  // Fallback to hardcoded default
  return 'https://jamasp-fitbit-oauth-service-730427234084.us-central1.run.app/';
}
```

**Remote Config Key:** `web/cloudRunEndpoint`

**Default Value:** `https://jamasp-fitbit-oauth-service-730427234084.us-central1.run.app/`

This allows the endpoint to be changed without code deployment.

---

## 7. Frontend Data Flow Summary

### Configuration Phase

```
STEP 1: Admin navigates to Project > "Auto Fetch" tab
STEP 2: Selects cron sensors via dropdown/autocomplete
STEP 3: Configures sensor arguments:
  - detail-level (1min, 5min, 15min)
  - timezone
  - other endpoint-specific parameters
STEP 4: Clicks "Save"
STEP 5: Frontend validates and saves cronSettings to Firestore
STEP 6: Show success notification
```

### Automatic Execution Phase (Daily)

```
TIME: 0 1 * * * UTC (1:00 AM UTC)

STEP 1: Firebase Scheduler function triggers
STEP 2: Scheduler queries projects with cronSettings
STEP 3: Filters eligible projects:
  - Has enabled sensors
  - Project is enabled
  - Current date within project date range
STEP 4: For each eligible project:
  CALL Cloud Run GET /fetchCronData?project_id={projectId}
STEP 5: Backend processes request and returns results
STEP 6: Results stored in Firestore fetch history
```

### Manual Execution Phase (On Demand)

```
USER ACTION 1: Admin clicks "Start Download Job"
  → Calls /fetchData?project_id={projectId}

USER ACTION 2: Admin clicks "Start Range Download Job"
  → Calls /fetchRangeData?project_id={projectId}

USER ACTION 3: Participant clicks "Download Data" (in registration)
  → Calls /downloadAndEmailData?downloadDate=YYYY-MM-DD&project_id=...
```

---

## 8. Related Frontend Components

### Files and Locations

**Configuration UI:**
- `src/admin/pages/ShowProject.js` - Project settings page with cron configuration
- `src/admin/components/CronJobPanel.js` - Cron settings configuration component
- `src/admin/data/sensorsCronJobSchema.js` - Sensor definitions and available options

**Scheduler:**
- `admin/modules/scheduler.js` - Firebase Scheduler function (daily trigger)
- `admin/modules/schedulerConfig.js` - Scheduler configuration

**Auth & Tokens:**
- `fitbit-funct/index.js` - Fitbit token refresh helpers
- `src/context/RegistrationContext.js` - Participant registration flow with data download

**Schema Definitions:**
- `admin/bigQueryUtils.js` - BigQuery dataset/table schema definitions
- `admin/bigQuerySchema.json` - BigQuery schema mappings

---

## 9. Key Concepts

### What Gets Stored in cronSettings

Each sensor configuration in `cronSettings` array contains:

- **sensorId:** Unique identifier for the sensor (e.g., "HeartRate_Intraday_byDate")
- **enabled:** Boolean to turn fetch on/off without removing configuration
- **arguments:** Object with values that replace placeholders in Fitbit API URL patterns
  - `user-id`: Device ID (format: "-" at save time, replaced with actual ID at fetch time)
  - `date`: Date logic (e.g., "today", "specific-date")
  - Endpoint-specific args: `detail-level`, `start-time`, `end-time`, etc.
- **parameters:** Object with query parameters for Fitbit API calls
  - `timezone`: User's timezone
  - `sort`: Sort order
  - `limit`: Maximum rows

### What Triggers Fetches

1. **Automatic (Daily):**
   - Scheduled Firebase Function at 0 1 * * * UTC
   - Reads all projects with cronSettings
   - Calls `/fetchCronData` for eligible projects

2. **Manual (On Demand):**
   - Admin: Click "Start Download Job" → `/fetchData`
   - Admin: Click "Start Range Download Job" → `/fetchRangeData`
   - Participant: Click "Download Data" → `/downloadAndEmailData`

### Device List

The `devices` array in project document contains Fitbit user IDs:

```javascript
devices: [
  "fitbit_user_id_123456",
  "fitbit_user_id_789012"
]
```

For each device, the backend:
1. Finds the associated participant in Firestore
2. Gets their Fitbit tokens
3. Refreshes tokens if expired
4. Fetches configured sensors for that device
5. Transforms data and inserts into BigQuery

---

## 10. Notes

- All HTTP requests from frontend to backend are **GET** requests with query parameters (no POST body)
- Frontend stores configuration; backend stores raw fetch responses and transformed data
- Token refresh happens in backend, not frontend
- BigQuery insertion happens in backend after data transformation
- Fetch job history is tracked in Firestore `downloadHistory` and `cronJobHistory` arrays on project document
