# Chapter 4 – Library Reference

The `lib/` directory contains the reusable building blocks used throughout Grafana-DR.

Unlike services, libraries do not implement complete workflows. Instead, they expose reusable functions that perform a single responsibility and can be called from multiple locations within the project.

The modular library architecture was intentionally chosen to avoid code duplication and simplify long-term maintenance.

Current libraries:

```text
lib/
├── api.sh
├── bootstrap.sh
├── common.sh
├── config.sh
├── dashboard.sh
├── file_utils.sh
├── git.sh
└── manifest.sh
```

Each library is documented individually in the following sections.

---

# 4.1 bootstrap.sh

## Purpose

The Bootstrap Library is responsible for preparing the application before any workflow begins.

Rather than forcing every executable script to source multiple libraries individually, `bootstrap.sh` acts as the application's loader.

This provides a single entry point for initialization.

---

## Responsibilities

The bootstrap library performs four primary tasks:

* Determines the project root directory.
* Loads configuration.
* Loads all reusable libraries.
* Provides the global initialization routine.

Because every executable loads the same bootstrap library, all entry points begin execution in a consistent environment.

---

## Initialization Flow

```text
Application Starts
        │
        ▼
Load bootstrap.sh
        │
        ▼
Determine PROJECT_ROOT
        │
        ▼
Load config.sh
        │
        ▼
Load remaining libraries
        │
        ▼
Expose initialize()
        │
        ▼
Ready for execution
```

---

## PROJECT_ROOT

One of the first tasks performed by the bootstrap library is determining the project root directory.

This allows every other component to reference project files using absolute paths rather than relying on the current working directory.

Without this approach, running scripts from different directories could cause configuration files or backup locations to be resolved incorrectly.

Using a common `PROJECT_ROOT` variable guarantees consistent path resolution throughout the application.

---

## Library Loading

The bootstrap library loads every reusable component required by the project.

Typical loading order:

```text
config.sh
common.sh
api.sh
dashboard.sh
file_utils.sh
manifest.sh
git.sh
```

Configuration is always loaded before the remaining libraries because many components depend on configuration variables.

---

## initialize()

The `initialize()` function represents the application's startup sequence.

Its purpose is to prepare the runtime environment before executing any backup or restore workflow.

Typical responsibilities include:

* Display application banner.
* Verify required software.
* Create required directories.
* Load Grafana API token.
* Verify Grafana connectivity.
* Log successful initialization.

Every production entry point executes this function before performing any operation.

---

# 4.2 config.sh

## Purpose

The Configuration Library centralizes every configurable value used throughout the application.

Rather than scattering constants across multiple files, all configuration is maintained in a single location.

This greatly simplifies deployment and maintenance.

---

## Responsibilities

The configuration library defines values such as:

* Grafana URL
* API retry count
* API timeout
* Dashboard directory
* Log directory
* Manifest location
* Token location
* Project version
* Return codes

Keeping these values centralized improves readability and reduces duplication.

---

## Configuration Categories

The configuration values are grouped logically.

### Application

Contains application-wide settings.

Examples:

* Version
* Project directories

---

### Grafana

Contains Grafana-specific settings.

Examples:

* Base URL
* Authentication token path

---

### API

Contains HTTP communication settings.

Examples:

* Connection timeout
* Retry count

---

### File Locations

Contains filesystem paths used by the application.

Examples:

* Dashboard backup directory
* Manifest file
* Log file

---

### Return Codes

Several reusable return codes are defined.

Examples include:

* Success
* No Change
* Invalid JSON
* Temporary File Missing

Using symbolic constants instead of hardcoded numeric values improves readability throughout the codebase.

---

## Why Separate Configuration?

Separating configuration from implementation provides several advantages.

* Easier deployment.
* Environment-specific customization.
* Reduced maintenance effort.
* Cleaner implementation code.

A developer should rarely need to modify implementation files when changing deployment-specific settings.

---

# 4.3 common.sh

## Purpose

The Common Library provides generic helper functions shared by nearly every component of the application.

It acts as the project's utility library.

Unlike the API or Dashboard libraries, the Common Library contains functionality that is independent of Grafana itself.

---

## Responsibilities

Major responsibilities include:

* Logging
* Dependency validation
* Directory creation
* Token loading
* Banner display
* Initialization helpers

These functions support the entire application.

---

## Logging System

The logging subsystem provides standardized log messages.

Every log entry includes:

* Timestamp
* Severity
* Message

Example:

```text
[2026-08-07 01:10:18] [INFO] Initialization completed.
```

Standardized logging simplifies debugging and provides consistent output throughout the project.

---

## Banner Display

The banner function provides a consistent application header.

Example:

```text
==========================================
        Grafana-DR Toolkit
        Version 1.1.0
==========================================
```

Although primarily cosmetic, the banner immediately communicates the application version during execution.

---

## Dependency Validation

Before any workflow begins, required software is verified.

Examples include:

* curl
* jq
* Git

Detecting missing dependencies before execution prevents unexpected runtime failures later in the workflow.

---

## Directory Initialization

Required directories are automatically created if they do not already exist.

Examples:

* dashboards/
* logs/

This ensures the application can run on a newly cloned repository without requiring manual directory creation.

---

## Token Loading

Authentication is performed using a Grafana Service Account Token.

The Common Library loads the token from the configured location and stores it in memory for later API requests.

Keeping token loading centralized prevents duplicate authentication logic.

---

## Grafana Connectivity Check

Before attempting backups or restores, the application verifies that Grafana is reachable.

This prevents unnecessary processing when the target server is unavailable.

Connectivity is verified using the Grafana Health API.

---

## Summary Generation

At the end of a workflow, the Common Library prints a standardized execution summary.

Example:

```text
====================================
Grafana-DR Summary
====================================
Dashboards Processed : 5
Successful           : 5
Failed               : 0
```

Providing a consistent summary allows operators to quickly determine the outcome of each execution.

---

# Design Considerations

Several design principles influenced these foundational libraries.

### Single Source of Truth

Configuration values exist in only one location.

This prevents conflicting definitions across the project.

---

### Reusability

Generic functionality is centralized rather than duplicated.

For example, logging and dependency validation are implemented once and reused everywhere.

---

### Consistency

Every executable follows the same initialization process.

This guarantees identical runtime behavior regardless of which entry point is executed.

---

### Separation of Concerns

Bootstrap loads components.

Configuration stores constants.

Common provides utilities.

Each library performs exactly one logical role.

---

# Chapter Summary

The Bootstrap, Configuration, and Common libraries provide the foundation upon which the remainder of Grafana-DR is built.

They establish the runtime environment, centralize configuration, and expose the reusable helper functions that support every workflow in the application.

The next section documents the remaining libraries responsible for HTTP communication, dashboard management, filesystem operations, manifest generation, and Git integration.

# Chapter 4.4 – API Library (`api.sh`)

## Overview

The API Library provides a generic abstraction layer over HTTP communication.

Rather than allowing every component of the application to invoke `curl` directly, all HTTP requests are centralized within this library.

This creates a single, reusable interface for network communication while isolating the rest of the project from the underlying HTTP implementation.

The API library contains **no Grafana-specific business logic**.

It only knows how to send authenticated HTTP requests.

This separation allows dashboard-related libraries to focus solely on Grafana operations without concerning themselves with connection management, authentication headers, retry logic, or timeout handling.

---

# Responsibilities

The API library is responsible for:

* Constructing HTTP requests
* Adding authentication headers
* Handling retries
* Managing timeouts
* Supporting multiple HTTP methods
* Returning API responses to higher-level libraries

It intentionally does **not** interpret the returned JSON.

Parsing responses is delegated to higher-level libraries such as `dashboard.sh`.

---

# Architecture

```text
Dashboard Library
        │
        ▼
   api_get()
   api_post()
   api_put()
   api_delete()
        │
        ▼
  api_request()
        │
        ▼
      curl
        │
        ▼
 Grafana HTTP API
```

Every HTTP request performed by the project eventually passes through `api_request()`.

---

# Public Functions

The library currently exposes the following public functions:

```
api_request()

api_get()

api_post()

api_put()

api_delete()

grafana_health()

grafana_version()
```

Each function is documented below.

---

# api_request()

## Purpose

`api_request()` is the core function of the API library.

Every other API helper ultimately delegates its work to this function.

Rather than duplicating identical curl options across multiple functions, common request behaviour is implemented once.

---

## Arguments

| Parameter | Description                          |
| --------- | ------------------------------------ |
| METHOD    | HTTP method (GET, POST, PUT, DELETE) |
| ENDPOINT  | Grafana API endpoint                 |
| DATA_FILE | Optional JSON payload                |

---

## Returns

Returns the HTTP response body.

If curl encounters an error, the function returns a non-zero exit status.

---

## Internal Workflow

```
Receive Method
      │
      ▼
Build curl arguments
      │
      ▼
Add Authorization header
      │
      ▼
Add timeout
      │
      ▼
Add retry policy
      │
      ▼
Add Content-Type (if required)
      │
      ▼
Send HTTP Request
      │
      ▼
Return Response
```

---

## Why This Function Exists

Without this abstraction every Grafana operation would require manually constructing a curl command.

That would duplicate:

* timeout handling
* retry logic
* authentication headers
* URL generation
* content type

Centralizing these behaviours reduces maintenance significantly.

---

# api_get()

## Purpose

Performs HTTP GET requests.

---

## Usage

Used whenever data is retrieved from Grafana.

Examples include:

* Dashboard listing
* Dashboard export
* Health check

---

## Internal Flow

```
api_get()
      │
      ▼
api_request(GET)
      │
      ▼
curl
```

---

# api_post()

## Purpose

Performs HTTP POST requests.

---

## Usage

Currently used for:

* Dashboard imports

Future versions may also use it for:

* Datasource creation
* Folder creation
* Alert rules

---

## Internal Flow

```
api_post()
      │
      ▼
api_request(POST)
      │
      ▼
curl
```

---

# api_put()

## Purpose

Performs HTTP PUT requests.

Currently unused by the project.

It exists because the HTTP abstraction was designed to be complete rather than implementing only currently required methods.

Future Grafana resources may require PUT operations.

---

# api_delete()

## Purpose

Performs HTTP DELETE requests.

Currently unused.

Future enhancements such as automated cleanup or dashboard deletion can reuse this function immediately.

---

# grafana_health()

## Purpose

Verifies that Grafana is reachable.

---

## Endpoint

```
GET /api/health
```

---

## Return Values

| Value    | Meaning             |
| -------- | ------------------- |
| 0        | Grafana reachable   |
| non-zero | Grafana unreachable |

---

## Usage

Called during application initialization.

If this check fails, execution stops immediately.

---

## Why Health Checks Matter

Failing early prevents:

* Partial backups
* Misleading error messages
* Unnecessary processing

---

# grafana_version()

## Purpose

Retrieves the running Grafana version.

---

## Endpoint

```
GET /api/health
```

---

## Response Example

```json
{
  "database":"ok",
  "version":"13.1.1"
}
```

Only the version field is returned.

---

## Usage

The returned version is written into `manifest.json`.

Recording the Grafana version provides useful diagnostic information during disaster recovery.

---

# Retry Strategy

Every request uses curl retry support.

Advantages:

* Temporary network interruptions are tolerated.
* Short Grafana restarts do not immediately fail backups.
* Minor connectivity problems become transparent to users.

Retry behaviour is configurable through `config.sh`.

---

# Timeout Strategy

Each request defines:

* Connection timeout
* Maximum execution time

These values prevent hung HTTP requests from blocking the application indefinitely.

---

# Authentication

Every request automatically includes:

```
Authorization: Bearer <TOKEN>
```

The token is loaded during initialization by the Common Library.

Authentication is therefore completely transparent to higher-level components.

---

# Error Handling

The API library intentionally performs minimal error handling.

Its responsibility is only to communicate with Grafana.

Higher-level libraries decide:

* whether a request succeeded,
* whether returned JSON is valid,
* and how failures should be reported.

This separation keeps the API layer generic and reusable.

---

# Design Decisions

Several architectural choices influenced the implementation.

## Generic by Design

The API layer contains no dashboard-specific logic.

This allows future libraries to reuse the same HTTP interface.

---

## Single Responsibility

Only one function (`api_request`) knows how to communicate over HTTP.

Everything else delegates to it.

---

## Extensibility

Adding support for new Grafana resources requires only new wrapper functions.

The underlying HTTP implementation remains unchanged.

---

## Maintainability

If timeout behaviour, authentication, or retry logic changes in the future, modifications are made in only one location.

No other library requires updates.

---

# Summary

The API Library provides a clean abstraction over HTTP communication.

By centralizing authentication, retries, timeout management, and request construction, it allows higher-level libraries to remain focused on business logic rather than networking.

It serves as the communication backbone of the Grafana-DR application and enables every interaction with the Grafana REST API.

# Chapter 4.5 – Dashboard Library (`dashboard.sh`)

## Overview

The Dashboard Library implements all Grafana dashboard-specific operations.

While the API Library provides generic HTTP communication, the Dashboard Library understands Grafana's dashboard model, API endpoints, and import/export formats.

This separation allows the HTTP layer to remain completely generic while concentrating all dashboard-related business logic within a single module.

The Dashboard Library acts as the application's domain layer.

---

# Responsibilities

The Dashboard Library is responsible for:

* Listing dashboards
* Exporting dashboards
* Importing dashboards
* Converting exported dashboards into valid import payloads
* Interacting with Grafana Dashboard APIs

Unlike `api.sh`, this library understands Grafana's API semantics.

---

# Architecture

```text
                Backup Service
                      │
                      ▼
             Dashboard Library
      ┌───────────────┼────────────────┐
      │               │                │
      ▼               ▼                ▼
 List Dashboards  Export Dashboard  Import Dashboard
      │               │                │
      └───────────────┼────────────────┘
                      ▼
                 API Library
                      ▼
                Grafana REST API
```

The Dashboard Library is the only module responsible for translating Grafana concepts into API calls.

---

# Grafana Dashboard APIs Used

The library interacts with three primary endpoints.

| Endpoint                    | Purpose          |
| --------------------------- | ---------------- |
| `/api/search`               | List dashboards  |
| `/api/dashboards/uid/{uid}` | Export dashboard |
| `/api/dashboards/db`        | Import dashboard |

Every dashboard operation performed by Grafana-DR is built on these endpoints.

---

# grafana_list_dashboards()

## Purpose

Retrieves every dashboard available within the configured Grafana organization.

This function acts as the starting point for every backup operation.

Without it, the application would have no knowledge of which dashboards exist.

---

## Endpoint

```text
GET /api/search?type=dash-db
```

---

## Returns

Returns an array of dashboard objects.

Example:

```json
[
  {
    "uid": "adpj4mw",
    "title": "Host Temperature"
  }
]
```

Each object contains sufficient metadata to perform a dashboard export.

---

## Internal Workflow

```text
Request Dashboard List
        │
        ▼
Receive JSON Array
        │
        ▼
Return Array
```

No processing is performed here.

Filtering and iteration are handled by the Backup Service.

---

# grafana_export_dashboard()

## Purpose

Exports a single dashboard using its UID.

The exported JSON becomes the authoritative backup copy stored within the repository.

---

## Endpoint

```text
GET /api/dashboards/uid/{uid}
```

---

## Arguments

| Parameter     | Description                 |
| ------------- | --------------------------- |
| Dashboard UID | Unique dashboard identifier |

---

## Returns

The exported dashboard JSON exactly as provided by Grafana.

Example structure:

```json
{
    "meta": { ... },
    "dashboard": { ... }
}
```

This export format is preserved during backup.

---

## Internal Workflow

```text
Receive UID
      │
      ▼
Call Export API
      │
      ▼
Receive Dashboard JSON
      │
      ▼
Return JSON
```

No modifications are performed during backup.

The exported dashboard remains identical to Grafana's output.

---

# grafana_import_dashboard()

## Purpose

Restores a dashboard into Grafana.

Unlike dashboard export, dashboard import requires transformation before the JSON can be submitted.

This function performs that transformation automatically.

---

## Why Import Is Different

Grafana's Export API and Import API use different JSON formats.

Export:

```json
{
    "meta": { ... },
    "dashboard": { ... }
}
```

Import:

```json
{
    "dashboard": { ... },
    "folderUid": "",
    "overwrite": true
}
```

Submitting the exported JSON directly results in API errors.

Therefore, Grafana-DR converts the backup into the required import format before restoration.

---

# Cross-Instance Restore

One of the most significant design decisions in Grafana-DR is support for restoring dashboards into a different Grafana installation.

During development, it was discovered that Grafana rejects dashboards containing the original internal dashboard ID.

For successful cross-instance restoration, the Dashboard Library performs the following transformations:

* Dashboard `id` is set to `null`
* Dashboard `version` is reset to `0`
* Folder information is preserved
* `overwrite` is enabled

These changes ensure compatibility with fresh Grafana installations while preserving dashboard content.

---

## Import Transformation Workflow

```text
Backup JSON
      │
      ▼
Read Export File
      │
      ▼
Extract dashboard object
      │
      ▼
Set dashboard.id = null
      │
      ▼
Set dashboard.version = 0
      │
      ▼
Preserve folderUid
      │
      ▼
Enable overwrite
      │
      ▼
Create Import Payload
      │
      ▼
POST /api/dashboards/db
```

The original backup file is never modified.

A temporary import payload is generated for the API request.

---

# Temporary Import Payload

Import payloads are intentionally created in temporary files.

Reasons include:

* Original backup remains unchanged.
* Easier debugging.
* Safer error handling.
* Atomic processing.

Temporary files are removed automatically after import.

---

# Why Reset Dashboard ID?

Grafana assigns an internal database identifier to every dashboard.

That identifier is unique to a specific Grafana instance.

Attempting to reuse it on another instance results in import failures.

Resetting the identifier allows Grafana to allocate a new internal ID automatically.

---

# Why Reset Dashboard Version?

Dashboard version numbers track revisions within a single Grafana database.

A new Grafana installation has no knowledge of the previous version history.

Resetting the version prevents version conflicts during import.

---

# Error Handling

The Dashboard Library reports errors to the calling service rather than terminating execution.

Typical failures include:

* Dashboard not found
* Invalid JSON
* API communication failure
* Import rejection

The Backup and Restore Services determine how these failures affect the overall workflow.

---

# Design Decisions

Several architectural decisions shaped the Dashboard Library.

## Separation from HTTP

Dashboard logic is intentionally separated from HTTP communication.

The Dashboard Library understands Grafana.

The API Library understands HTTP.

This separation significantly improves maintainability.

---

## Preserve Backup Fidelity

Dashboard exports are stored exactly as Grafana returns them.

No modifications are performed during backup.

This guarantees that the repository always contains an authentic representation of the exported dashboard.

---

## Transform Only During Restore

Instead of modifying backup files permanently, conversion occurs only during restoration.

Advantages include:

* Immutable backups.
* Easier troubleshooting.
* Future compatibility.
* Lossless exports.

---

## Stateless Design

The Dashboard Library maintains no internal state.

Every function performs a single request and returns the result.

This simplifies testing and allows functions to be reused independently.

---

# Summary

The Dashboard Library forms the core business logic of Grafana-DR.

It bridges the gap between generic HTTP communication and Grafana-specific dashboard management.

By preserving exported dashboards exactly as received while dynamically transforming them during restoration, the library provides reliable cross-instance disaster recovery without compromising backup integrity.

# Chapter 4.6 – File Utility Library (`file_utils.sh`)

## Overview

The File Utility Library provides reusable filesystem operations used throughout Grafana-DR.

Rather than embedding file handling logic inside backup and restore services, all filesystem-related operations are centralized within this library.

This design keeps the service layer focused on workflows while delegating low-level filesystem operations to reusable helper functions.

The library contains **no Grafana-specific logic**.

Its purpose is to provide reliable, reusable, and safe file manipulation primitives.

---

# Responsibilities

The File Utility Library is responsible for:

* Creating temporary files
* Removing temporary files
* Validating JSON files
* Comparing files
* Generating SHA-256 hashes
* Generating dashboard filenames
* Performing atomic file replacement

These operations form the foundation of the backup subsystem.

---

# Architecture

```text
               Backup Service
                     │
                     ▼
            File Utility Library
      ┌────────┬─────────┬─────────┐
      │        │         │         │
      ▼        ▼         ▼         ▼
 Temporary  Validate  Compare  Safe Write
   Files      JSON      Files
                     │
                     ▼
                  Filesystem
```

The Backup Service never manipulates files directly.

Instead, it delegates all filesystem operations to this library.

---

# Public Functions

```text
file_create_temp()

file_remove_temp()

file_validate_json()

file_compare()

file_sha256()

file_generate_name()

file_safe_write()
```

---

# file_create_temp()

## Purpose

Creates a secure temporary file for intermediate processing.

Rather than writing directly into the destination directory, exported dashboards are first written into a temporary file.

---

## Why Temporary Files?

Writing directly into the destination file introduces several risks.

For example:

* Interrupted writes
* Partial exports
* Invalid JSON
* Corrupted backups

Using temporary files isolates these failures from existing backups.

---

## Workflow

```text
Create Temporary File
        │
        ▼
Write Exported JSON
        │
        ▼
Validate JSON
        │
        ▼
Move Into Final Location
```

If validation fails, the existing backup remains untouched.

---

# file_remove_temp()

## Purpose

Removes temporary files after processing completes.

---

## Why Explicit Cleanup?

Temporary files accumulate over time if not removed.

Automatic cleanup:

* Conserves disk space.
* Prevents stale temporary files.
* Keeps the working directory clean.

---

# file_validate_json()

## Purpose

Validates that a file contains syntactically correct JSON.

---

## Validation Tool

Validation is performed using:

```text
jq empty
```

If parsing succeeds, the file is considered valid JSON.

---

## Why Validate?

Grafana API failures or interrupted exports could produce malformed JSON.

Without validation:

```text
Invalid Export
      │
      ▼
Backup Saved
      │
      ▼
Restore Failure
```

Validation prevents corrupted backups from entering the repository.

---

## Workflow

```text
JSON File
     │
     ▼
jq empty
     │
 ┌───┴────┐
 │        │
Valid   Invalid
 │        │
 ▼        ▼
Return0 Return1
```

---

# file_compare()

## Purpose

Determines whether two files are identical.

---

## Implementation

Comparison is performed using:

```text
cmp -s
```

---

## Why Compare?

Rewriting identical files causes unnecessary:

* Filesystem writes
* Manifest updates
* Git commits

Detecting unchanged files eliminates unnecessary work.

---

## Workflow

```text
Temporary File
        │
        ▼
Destination File
        │
        ▼
Compare Contents
        │
 ┌──────┴──────┐
 │             │
Same      Different
 │             │
 ▼             ▼
Skip      Replace
```

---

# file_sha256()

## Purpose

Calculates the SHA-256 checksum of a file.

---

## Why SHA-256?

Checksums provide integrity verification.

During restoration, the application can confirm that a dashboard file has not been modified unexpectedly.

---

## Uses

Checksums are stored in:

```text
manifest.json
```

and verified before restoration.

---

## Integrity Verification

```text
Dashboard File
        │
        ▼
Generate SHA-256
        │
        ▼
Store in Manifest
        │
        ▼
Later Verification
```

This ensures backups remain trustworthy.

---

# file_generate_name()

## Purpose

Generates standardized dashboard filenames.

---

## Input

Example:

```text
Title:
Host Temperature

UID:
adpj4mw
```

---

## Output

```text
host-temperature__adpj4mw.json
```

---

## Why Include the UID?

Dashboard titles are not guaranteed to be unique.

For example:

```text
Production

Production
```

would otherwise overwrite one another.

Appending the UID guarantees uniqueness.

---

## Filename Generation Steps

```text
Dashboard Title
        │
        ▼
Convert to lowercase
        │
        ▼
Replace spaces
        │
        ▼
Remove invalid characters
        │
        ▼
Append UID
        │
        ▼
.json
```

This produces filenames that are both readable and unique.

---

# file_safe_write()

## Purpose

Safely replaces an existing dashboard backup.

This function is the most important function within the File Utility Library.

It guarantees that backups are never corrupted during replacement.

---

## Why Safe Write?

A naive implementation would simply execute:

```text
mv temp.json dashboard.json
```

However, doing so without validation could replace a valid backup with an invalid file.

Instead, Grafana-DR performs several safety checks before replacing the destination.

---

## Workflow

```text
Temporary File
        │
        ▼
File Exists?
        │
 ┌──────┴──────┐
 │             │
No            Yes
 │             │
 ▼             ▼
Return Error Validate JSON
                     │
                     ▼
             Compare Existing File
                     │
          ┌──────────┴──────────┐
          │                     │
      No Changes          File Changed
          │                     │
          ▼                     ▼
Remove Temp File       Atomic Replace
          │                     │
          ▼                     ▼
 Return NO_CHANGE      Return SUCCESS
```

---

## Return Codes

Rather than returning only success or failure, the function returns symbolic result codes.

| Return Code       | Meaning                           |
| ----------------- | --------------------------------- |
| FILE_SUCCESS      | File written successfully         |
| FILE_NO_CHANGE    | Existing backup already identical |
| FILE_INVALID_JSON | Export failed validation          |
| FILE_TEMP_MISSING | Temporary file not found          |

These return values allow higher-level services to make intelligent decisions.

---

## Atomic Replacement

One of the key design decisions is the use of atomic replacement.

The destination file is replaced only after:

* JSON validation
* File comparison
* Successful export

This prevents partial or corrupted backups from replacing valid backups.

---

# Error Handling

The File Utility Library performs validation before modification.

Failures include:

* Missing temporary files
* Invalid JSON
* Filesystem errors

Rather than terminating the application, functions return meaningful status codes to the calling service.

---

# Design Decisions

## Immutable Backups

Existing backups are never modified unless a validated replacement exists.

---

## Reusability

Every function is generic.

None of these functions know anything about Grafana.

They can be reused by future backup modules, such as datasource or alert backups.

---

## Reliability First

Additional validation steps increase code complexity slightly but greatly improve backup reliability.

Protecting backup integrity is considered more important than minimizing the number of filesystem operations.

---

## Minimal Side Effects

Functions avoid changing application state.

Most operations work only with the files explicitly provided as arguments.

This makes the library deterministic and easy to test.

---

# Summary

The File Utility Library provides the safe filesystem primitives that underpin Grafana-DR.

Through temporary files, JSON validation, checksum generation, file comparison, and atomic replacement, it ensures that every backup written to disk is complete, valid, and recoverable.

Without this library, the backup process would be significantly more susceptible to corruption, unnecessary rewrites, and inconsistent filesystem state.

# Chapter 4.7 – Manifest Library (`manifest.sh`)

## Overview

The Manifest Library manages the creation, validation, and reading of the backup manifest.

Unlike dashboard JSON files, which contain only dashboard definitions, the manifest acts as the central index of every backup operation.

Rather than scanning the filesystem during restoration, Grafana-DR relies on the manifest as the authoritative inventory of backed-up dashboards.

This provides faster recovery, integrity verification, and a consistent view of the backup repository.

---

# Responsibilities

The Manifest Library is responsible for:

* Initializing a new manifest
* Registering successfully backed-up dashboards
* Generating `manifest.json`
* Validating the generated manifest
* Reading manifest data during restoration

The manifest itself is never edited manually. It is always generated automatically by the Backup Service.

---

# Why a Manifest?

Without a manifest, restoration would require scanning the `dashboards/` directory and making assumptions about every JSON file.

For example:

```text
dashboards/
├── dashboard-a.json
├── dashboard-b.json
├── old-dashboard.json
├── temp.json
└── notes.txt
```

The restore process would have no reliable way to determine:

* Which files are valid backups.
* Which dashboards belong to the current backup.
* Whether files have been modified.
* Which Grafana version produced the backups.

A manifest solves these problems by providing a structured inventory.

---

# Manifest Structure

A generated manifest resembles the following:

```json
{
  "generated_at": "2026-08-07T00:30:41Z",
  "grafana_version": "13.1.1",
  "dashboard_count": 2,
  "dashboards": [
    {
      "uid": "adpj4mw",
      "title": "Host Temperature",
      "file": "host-temperature__adpj4mw.json",
      "sha256": "...",
      "size": 18342
    }
  ]
}
```

The manifest contains both backup metadata and per-dashboard metadata.

---

# Architecture

```text
Backup Service
      │
      ▼
manifest_begin()
      │
      ▼
Backup Dashboard
      │
      ▼
manifest_add()
      │
      ▼
Backup Dashboard
      │
      ▼
manifest_add()
      │
      ▼
...
      │
      ▼
manifest_finish()
      │
      ▼
manifest.json
```

The Backup Service does not write JSON directly.

Instead, it delegates manifest generation entirely to this library.

---

# Public Functions

```text
manifest_begin()

manifest_add()

manifest_finish()

manifest_validate()

manifest_read()
```

Each function has a single, well-defined responsibility.

---

# manifest_begin()

## Purpose

Initializes a new manifest.

Internally, this clears the in-memory collection that stores dashboard metadata during the backup process.

Every backup operation begins with a clean manifest state.

---

## Workflow

```text
Start Backup
      │
      ▼
Clear Previous Manifest Items
      │
      ▼
Ready to Collect Dashboards
```

---

# manifest_add()

## Purpose

Registers a successfully backed-up dashboard.

Rather than writing directly to disk after every dashboard, metadata is accumulated in memory.

This approach avoids repeated file writes and allows the manifest to be generated only once after all dashboards have been processed.

---

## Arguments

| Parameter       | Description                 |
| --------------- | --------------------------- |
| Dashboard UID   | Unique dashboard identifier |
| Dashboard Title | Dashboard name              |
| Backup Filename | JSON backup filename        |
| SHA-256         | File checksum               |
| File Size       | Backup size in bytes        |

---

## Internal Workflow

```text
Dashboard Backed Up
        │
        ▼
Calculate SHA-256
        │
        ▼
Determine File Size
        │
        ▼
Create Metadata Object
        │
        ▼
Append to Manifest Collection
```

No disk I/O occurs during this step.

---

# manifest_finish()

## Purpose

Generates the final `manifest.json`.

Once every dashboard has been processed, the in-memory metadata collection is converted into a structured JSON document.

Additional backup metadata is added, including:

* Generation timestamp
* Grafana version
* Dashboard count

The resulting document is written to disk in a single operation.

---

## Workflow

```text
Collected Dashboard Metadata
            │
            ▼
Add Backup Metadata
            │
            ▼
Generate JSON
            │
            ▼
Write manifest.json
```

Generating the manifest once minimizes unnecessary writes and ensures consistency.

---

# Manifest Metadata

The manifest currently records:

## generated_at

UTC timestamp indicating when the backup completed.

Example:

```text
2026-08-07T00:30:41Z
```

---

## grafana_version

Version of Grafana that generated the backup.

This assists troubleshooting when restoring across different Grafana releases.

---

## dashboard_count

Total number of dashboards successfully backed up.

This provides a quick consistency check during restoration.

---

## dashboards

Array containing metadata for every backed-up dashboard.

Each object includes:

* UID
* Title
* Filename
* SHA-256 checksum
* File size

---

# manifest_validate()

## Purpose

Validates the generated manifest before it is used.

Validation is performed using the same JSON validation mechanism employed throughout the project.

Only syntactic validation is performed.

Semantic validation is handled during restoration.

---

## Workflow

```text
manifest.json
      │
      ▼
JSON Validation
      │
 ┌────┴────┐
 │         │
Valid   Invalid
 │         │
 ▼         ▼
Continue  Abort
```

---

# manifest_read()

## Purpose

Provides access to the manifest during restoration.

The Restore Service relies on the manifest rather than scanning the backup directory directly.

This guarantees that restoration uses the same inventory created during backup.

---

# Why Build the Manifest in Memory?

One design decision made during development was to construct the manifest in memory before writing it to disk.

Advantages include:

* Only one filesystem write.
* Simpler implementation.
* Reduced disk activity.
* Guaranteed consistency.

If the backup process fails midway, no partially generated manifest is left behind.

---

# Integrity Verification

The manifest stores a SHA-256 checksum for every dashboard backup.

During restoration, the checksum can be recalculated and compared against the recorded value.

This verifies that:

* Backup files were not corrupted.
* Files were not modified accidentally.
* Git synchronization preserved file integrity.

Integrity verification significantly increases confidence in disaster recovery operations.

---

# Manifest and Git

During development, an important optimisation was introduced.

Originally, the manifest always updated its generation timestamp.

This caused Git to detect changes even when no dashboards had changed, resulting in unnecessary commits.

The implementation was improved so that the manifest is regenerated only when dashboard backups actually change.

This aligns Git history with meaningful configuration changes rather than execution timestamps.

---

# Error Handling

Possible failures include:

* JSON generation failure
* Filesystem write failure
* Invalid manifest syntax

The Manifest Library reports these failures to the Backup Service, allowing the workflow to terminate cleanly with informative log messages.

---

# Design Decisions

## Manifest as the Source of Truth

The manifest is considered the authoritative inventory of the backup repository.

Rather than relying on directory listings, every restore operation begins by reading the manifest.

---

## Immutable Dashboard Files

Dashboard JSON files remain unchanged after backup.

Only the manifest contains metadata about those files.

This separation keeps dashboard exports identical to Grafana's output while storing operational metadata independently.

---

## Single Write Strategy

The manifest is generated only once, after every dashboard has been processed.

This improves performance and eliminates partially written manifests.

---

## Future Extensibility

The manifest format was designed to accommodate additional resources in future versions.

Potential future entries include:

* Datasources
* Alert rules
* Library panels
* Folders
* Plugin metadata

These can be incorporated without changing the overall manifest structure.

---

# Summary

The Manifest Library provides the metadata layer that transforms a collection of dashboard JSON files into a structured, verifiable backup repository.

By maintaining dashboard inventories, integrity information, backup metadata, and recovery context, it enables Grafana-DR to perform reliable and predictable disaster recovery while supporting future expansion of the project.

# Chapter 4.8 – Git Library (`git.sh`)

## Overview

The Git Library encapsulates all Git-related operations performed by Grafana-DR.

Rather than invoking Git commands throughout the Backup Service, every Git interaction is centralized within this library.

This approach keeps backup workflows focused on dashboard management while treating Git as a separate subsystem responsible for version control and synchronization.

The Git Library contains **no Grafana-specific logic**.

Its only responsibility is managing the backup repository.

---

# Responsibilities

The Git Library is responsible for:

* Verifying repository status
* Detecting changes
* Staging backup artifacts
* Creating commits
* Synchronizing with remote repositories
* Preventing unnecessary commits

It transforms Grafana dashboard backups into a GitOps workflow.

---

# Architecture

```text
                Backup Service
                      │
                      ▼
                 Git Library
      ┌──────────┬──────────┬──────────┐
      │          │          │          │
      ▼          ▼          ▼          ▼
 Git Status   Git Add   Git Commit  Git Push
      │
      ▼
 Git Repository
      │
      ▼
 GitHub
```

The Backup Service never executes Git commands directly.

Instead, it delegates repository management entirely to this library.

---

# Why Use Git?

Traditional backup solutions often store multiple copies of files over time.

Grafana-DR instead treats Git as the authoritative history of dashboard configurations.

Using Git provides:

* Complete version history
* Change tracking
* Rollback capability
* Remote replication
* Collaboration
* Disaster recovery

without introducing additional databases or proprietary backup formats.

---

# Public Functions

Typical public functions include:

```text
git_is_repository()

git_has_changes()

git_stage_changes()

git_commit()

git_push()

git_sync()
```

The exact implementation may evolve, but each function represents one logical Git operation.

---

# git_is_repository()

## Purpose

Verifies that the current project directory is a valid Git repository.

---

## Why Validate?

Running Git commands outside a repository results in failures.

Detecting this condition before backup begins allows the application to terminate cleanly with an informative error message.

---

## Workflow

```text
Project Directory
        │
        ▼
git rev-parse
        │
 ┌──────┴──────┐
 │             │
Valid       Invalid
 │             │
 ▼             ▼
Continue     Abort
```

---

# git_has_changes()

## Purpose

Determines whether the backup operation produced meaningful filesystem changes.

---

## Why This Function Exists

Creating commits when nothing has changed results in:

* Repository noise
* Unnecessary commit history
* Unnecessary pushes

Instead, Grafana-DR checks whether tracked files have actually changed before continuing.

---

## Workflow

```text
Backup Completed
       │
       ▼
git status
       │
 ┌─────┴─────┐
 │           │
Clean     Modified
 │           │
 ▼           ▼
Exit     Continue
```

---

## Design Improvement

During development an important optimisation was introduced.

Initially, `manifest.json` always updated its timestamp, causing Git to report changes even when dashboard content remained identical.

The manifest generation process was later modified so that timestamps no longer trigger unnecessary commits.

As a result:

* Dashboard unchanged
* Manifest unchanged
* Git repository unchanged

This significantly improved the quality of repository history.

---

# git_stage_changes()

## Purpose

Stages modified backup artifacts.

Typical files include:

* Dashboard JSON files
* `manifest.json`

Operational files such as logs are intentionally excluded.

---

## Why Stage Explicitly?

Separating staging from committing provides flexibility.

Future enhancements could selectively stage only specific resource types without altering the commit process.

---

# git_commit()

## Purpose

Creates a commit representing a backup snapshot.

---

## Commit Strategy

Every commit represents a meaningful configuration change.

Example commit messages:

```text
Grafana dashboard backup

Nightly dashboard backup

Update Grafana dashboards
```

The project intentionally avoids creating empty commits.

---

# Why Meaningful Commits Matter

A clean commit history provides:

* Easier auditing
* Simpler rollback
* Improved troubleshooting
* Better repository readability

Each commit should correspond to an actual dashboard modification.

---

# git_push()

## Purpose

Synchronizes the local repository with the remote repository.

---

## Workflow

```text
Local Commit
      │
      ▼
git push
      │
      ▼
GitHub
```

Once pushed, the backup becomes immediately available to standby systems.

---

# git_sync()

## Purpose

Coordinates the complete Git workflow.

Rather than requiring the Backup Service to call multiple Git functions individually, `git_sync()` performs the complete synchronization sequence.

---

## Internal Workflow

```text
Check Repository
        │
        ▼
Detect Changes
        │
 ┌──────┴──────┐
 │             │
No Changes  Changes Found
 │             │
 ▼             ▼
Return     Stage Files
                  │
                  ▼
             Create Commit
                  │
                  ▼
               Push Changes
```

This provides a simple interface for the Backup Service while hiding Git implementation details.

---

# Why Logs Are Ignored

Runtime logs are operational artifacts rather than configuration.

Including them in Git would create unnecessary commits after every execution.

For this reason, the `logs/` directory is excluded using `.gitignore`.

This ensures that Git history reflects only meaningful configuration changes.

---

# GitOps Workflow

Grafana-DR follows a GitOps-inspired model.

Instead of treating Git as a passive backup destination, Git becomes the central source of truth for dashboard configurations.

The workflow is:

```text
Grafana Dashboard
        │
        ▼
Backup JSON
        │
        ▼
Git Repository
        │
        ▼
GitHub
        │
        ▼
Standby Server
        │
        ▼
Restore
```

Any environment with access to the repository can reconstruct the dashboard configuration.

---

# Error Handling

Possible failures include:

* Repository not initialized
* Merge conflicts
* Authentication failures
* Network interruptions
* Remote repository unavailable

These errors are reported back to the Backup Service, allowing execution to terminate with informative log messages.

---

# Design Decisions

## Git as the Disaster Recovery Database

Rather than storing backups in a proprietary format or custom database, Grafana-DR leverages Git as the authoritative storage system.

This provides mature, well-tested version control with minimal additional complexity.

---

## No Empty Commits

Commits are created only when dashboard backups change.

This keeps repository history concise and meaningful.

---

## Repository Independence

The Git Library performs only repository management.

It has no knowledge of:

* Grafana
* Dashboard JSON
* Manifest structure
* Backup workflows

This separation improves modularity and allows the Git subsystem to evolve independently.

---

## Future Extensibility

The current implementation focuses on dashboard backups.

Future versions could extend Git synchronization to include:

* Datasources
* Alert rules
* Folders
* Plugins
* Configuration files

without requiring significant architectural changes.

---

# Summary

The Git Library transforms Grafana-DR from a simple backup utility into a GitOps-oriented disaster recovery solution.

By integrating change detection, version control, and remote synchronization into the backup workflow, it provides reliable historical tracking while ensuring that only meaningful configuration changes are recorded.

The result is a clean, auditable repository that serves as the authoritative source for dashboard recovery across Grafana environments.

---

# End of Chapter 4

At this point, every reusable library within Grafana-DR has been documented in detail.

The next chapter moves beyond reusable components and examines the service layer, beginning with `backup_service.sh`, where the complete backup workflow is orchestrated using the libraries described in this chapter.