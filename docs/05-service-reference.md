# Chapter 5 – Service Reference

Unlike the reusable libraries described in the previous chapter, the Service Layer implements complete application workflows.

Services coordinate multiple libraries to accomplish a business operation.

Grafana-DR currently contains two services:

```text
services/
├── backup_service.sh
└── restore_service.sh
```

Each service represents one complete business process.

The Backup Service performs dashboard backup operations.

The Restore Service performs dashboard recovery operations.

Neither service implements low-level functionality such as HTTP communication, JSON validation, or Git operations.

Instead, services orchestrate reusable library functions to implement complete workflows.

---

# 5.1 Backup Service (`backup_service.sh`)

## Overview

The Backup Service is the heart of the backup subsystem.

Its primary responsibility is exporting every dashboard from Grafana, validating the exported data, storing backups safely, generating the backup manifest, and preparing the repository for Git synchronization.

The Backup Service never communicates directly with Grafana or manipulates files itself.

Instead, it delegates these operations to specialized libraries.

---

# Responsibilities

The Backup Service is responsible for:

* Retrieving the dashboard inventory
* Exporting dashboards
* Writing validated backups
* Updating the manifest
* Producing execution statistics
* Coordinating the complete backup workflow

---

# High-Level Workflow

```text
                 Start
                   │
                   ▼
            Initialization
                   │
                   ▼
      Retrieve Dashboard List
                   │
                   ▼
        Process Each Dashboard
                   │
                   ▼
          Update Manifest
                   │
                   ▼
        Validate Manifest
                   │
                   ▼
         Display Summary
                   │
                   ▼
              Return
```

---

# backup_dashboards()

## Purpose

This function serves as the primary entry point for the backup subsystem.

It coordinates every step required to produce a complete dashboard backup.

---

## Responsibilities

The function performs the following operations:

1. Retrieve dashboard inventory.
2. Determine dashboard count.
3. Initialise backup statistics.
4. Initialise manifest generation.
5. Process every dashboard.
6. Generate the manifest.
7. Validate the manifest.
8. Print execution summary.

---

# Workflow

```text
backup_dashboards()
        │
        ▼
grafana_list_dashboards()
        │
        ▼
manifest_begin()
        │
        ▼
For each dashboard
        │
        ▼
_backup_dashboard()
        │
        ▼
manifest_finish()
        │
        ▼
manifest_validate()
        │
        ▼
print_summary()
```

This function performs orchestration only.

All implementation details remain inside reusable libraries.

---

# Dashboard Processing Loop

The backup service processes dashboards sequentially.

Each dashboard is handled independently.

This provides several advantages:

* Simpler implementation.
* Easier debugging.
* Isolated failure handling.
* Predictable execution.

If one dashboard fails, remaining dashboards can still be processed.

---

# Statistics Collection

During execution the Backup Service maintains runtime statistics.

Typical values include:

```text
TOTAL

SUCCESS

FAILED
```

These values are displayed at the end of execution.

Example:

```text
====================================
Grafana-DR Summary
====================================
Dashboards Processed : 12
Successful           : 12
Failed               : 0
```

---

# _backup_dashboard()

## Purpose

Processes one individual dashboard.

This function performs every operation required to transform a Grafana dashboard into a validated backup file.

---

## Internal Workflow

```text
Receive Dashboard
        │
        ▼
Extract UID
        │
        ▼
Extract Title
        │
        ▼
Export Dashboard
        │
        ▼
Create Temporary File
        │
        ▼
Write JSON
        │
        ▼
Generate Filename
        │
        ▼
Safe File Write
        │
        ▼
Generate SHA-256
        │
        ▼
Calculate File Size
        │
        ▼
Register in Manifest
```

Every dashboard follows exactly the same processing pipeline.

---

# Dashboard Export

The Backup Service requests dashboard data using:

```text
grafana_export_dashboard()
```

The Dashboard Library communicates with Grafana and returns the exported JSON.

The Backup Service does not parse or modify this data.

---

# Temporary File Usage

Exported dashboards are never written directly into the backup directory.

Instead:

```text
Grafana Export
       │
       ▼
Temporary File
       │
       ▼
Validation
       │
       ▼
Comparison
       │
       ▼
Destination File
```

This design protects existing backups against corruption.

---

# Safe File Replacement

Once the temporary file has been written, the Backup Service delegates replacement to:

```text
file_safe_write()
```

This function performs:

* JSON validation
* File comparison
* Atomic replacement

The Backup Service simply interprets the returned status code.

---

# Return Code Handling

Rather than checking only success or failure, the Backup Service reacts differently depending on the result.

Possible outcomes include:

```text
FILE_SUCCESS

FILE_NO_CHANGE

FILE_INVALID_JSON

FILE_TEMP_MISSING
```

Each outcome generates an appropriate log message.

---

# Manifest Integration

After a successful backup, dashboard metadata is registered using:

```text
manifest_add()
```

The Backup Service does not generate JSON itself.

Instead, metadata is accumulated until the backup completes.

---

# Summary Generation

Once every dashboard has been processed, the Backup Service:

1. Finalises the manifest.
2. Validates the manifest.
3. Displays execution statistics.

At this stage the backup repository is complete and ready for Git synchronization.

---

# Error Handling

The Backup Service is designed to tolerate failures affecting individual dashboards.

Possible failures include:

* Export failure
* Invalid JSON
* Temporary file errors
* Filesystem failures

Each failed dashboard increments the failure counter while allowing remaining dashboards to continue processing whenever possible.

---

# Design Decisions

## Orchestration Only

The Backup Service intentionally contains very little implementation logic.

Instead, it coordinates reusable libraries.

This keeps the workflow readable and prevents duplication.

---

## Sequential Processing

Dashboards are processed one at a time.

Although parallel processing could improve performance, sequential execution provides:

* Simpler debugging.
* Deterministic logging.
* Lower memory usage.
* Easier error isolation.

For typical Grafana deployments, the performance difference is negligible.

---

## Immutable Workflow

The Backup Service never modifies exported dashboard JSON.

Transformation occurs only during restoration.

This preserves the original backup exactly as Grafana exported it.

---

## Clear Separation of Responsibilities

The Backup Service never:

* Builds HTTP requests.
* Parses API endpoints.
* Calculates checksums.
* Validates JSON.
* Executes Git commands.

Each responsibility belongs to a dedicated library.

This modular architecture greatly simplifies maintenance.

---

# Summary

The Backup Service represents the orchestration layer of Grafana-DR.

By coordinating reusable libraries rather than implementing low-level functionality directly, it provides a clean, maintainable, and highly reliable backup workflow.

It transforms the collection of independent libraries documented in the previous chapter into a complete end-to-end backup engine capable of producing validated, version-controlled dashboard backups suitable for disaster recovery.

---

# Next Section

The following section documents the Restore Service, which performs the reverse workflow by reconstructing Grafana dashboards from the backup repository and restoring them into a target Grafana instance.


# 5.2 Restore Service (`restore_service.sh`)

## Overview

The Restore Service is responsible for reconstructing a Grafana environment from the dashboard backups created by the Backup Service.

Unlike the Backup Service, which exports dashboards exactly as Grafana provides them, the Restore Service must adapt the exported data into the format expected by Grafana's Import API.

During development, it was discovered that Grafana's export and import APIs are not directly compatible. The Restore Service bridges this difference by transforming the exported dashboard into a valid import payload before submitting it to Grafana.

This transformation enables reliable cross-instance disaster recovery.

---

# Responsibilities

The Restore Service is responsible for:

* Validating the backup manifest
* Reading dashboard metadata
* Locating backup files
* Verifying backup integrity
* Preparing import payloads
* Restoring dashboards
* Tracking restore statistics
* Reporting execution results

---

# High-Level Workflow

```text
                Start
                  │
                  ▼
            Initialization
                  │
                  ▼
        Validate manifest.json
                  │
                  ▼
      Read Dashboard Inventory
                  │
                  ▼
     Process Each Dashboard File
                  │
                  ▼
     Verify Dashboard Integrity
                  │
                  ▼
   Transform Import Payload
                  │
                  ▼
      Import into Grafana
                  │
                  ▼
        Display Summary
```

---

# restore_dashboards()

## Purpose

`restore_dashboards()` is the entry point of the restore subsystem.

Its responsibility is to coordinate the complete recovery workflow.

It does not communicate with Grafana directly.

Instead, it orchestrates reusable libraries responsible for:

* Manifest management
* File operations
* Dashboard import
* Logging

---

# Workflow

```text
restore_dashboards()
        │
        ▼
manifest_validate()
        │
        ▼
manifest_read()
        │
        ▼
For each dashboard
        │
        ▼
_restore_dashboard()
        │
        ▼
print_summary()
```

---

# Manifest Validation

The first operation performed by the Restore Service is validating the backup manifest.

```text
manifest.json
       │
       ▼
JSON Validation
       │
 ┌─────┴─────┐
 │           │
Valid     Invalid
 │           │
 ▼           ▼
Continue    Abort
```

Attempting restoration without a valid manifest could result in incomplete or inconsistent recovery.

Therefore, the restore process terminates immediately if manifest validation fails.

---

# Reading the Manifest

Rather than scanning the backup directory directly, the Restore Service relies on the manifest.

This provides several advantages:

* Known dashboard inventory
* Predictable processing order
* Integrity metadata
* Backup metadata
* Future extensibility

The manifest is considered the authoritative source for restoration.

---

# _restore_dashboard()

## Purpose

Processes one dashboard backup.

Each dashboard is restored independently.

This allows failures affecting one dashboard to be isolated without affecting the remainder of the restore process.

---

# Internal Workflow

```text
Receive Dashboard Metadata
         │
         ▼
Locate JSON Backup
         │
         ▼
Verify File Exists
         │
         ▼
Verify SHA-256
         │
         ▼
Generate Import Payload
         │
         ▼
Import Dashboard
         │
         ▼
Update Statistics
```

---

# Dashboard Integrity Verification

Before importing a dashboard, the Restore Service verifies that the backup file is intact.

Verification includes:

* File exists
* Valid JSON
* SHA-256 checksum matches the manifest

This ensures corrupted or modified backups are never restored accidentally.

---

# Import Payload Generation

One of the most important responsibilities of the Restore Service is preparing the dashboard for import.

The backup file is **never** modified.

Instead, a temporary import payload is generated.

---

# Export vs Import Format

Grafana exports dashboards in the following format:

```json
{
    "meta": {...},
    "dashboard": {...}
}
```

However, Grafana's Import API expects:

```json
{
    "dashboard": {...},
    "folderUid": "",
    "overwrite": true
}
```

Submitting the exported JSON directly results in an HTTP 400 response.

Therefore, transformation is mandatory.

---

# Cross-Instance Compatibility

During development, testing against a second Grafana instance revealed another important behaviour.

Grafana rejected imported dashboards containing the original internal dashboard identifier.

To solve this, the Restore Service performs several transformations.

Before importing:

* `dashboard.id` is set to `null`
* `dashboard.version` is reset to `0`
* `folderUid` is preserved
* `overwrite` is enabled

These modifications allow Grafana to assign a new internal identifier while preserving the dashboard definition.

---

# Import Transformation

```text
Exported Dashboard
        │
        ▼
Extract dashboard object
        │
        ▼
dashboard.id = null
        │
        ▼
dashboard.version = 0
        │
        ▼
Preserve folderUid
        │
        ▼
overwrite = true
        │
        ▼
Generate Import Payload
```

The original backup remains unchanged.

Only the temporary payload is modified.

---

# Temporary Payload Strategy

The Restore Service generates import payloads using temporary files.

Advantages include:

* Backup files remain immutable.
* Easier debugging.
* Cleaner error handling.
* Safe retry behaviour.

Once the dashboard has been imported successfully, the temporary payload is deleted.

---

# Dashboard Import

The Restore Service delegates the actual API request to:

```text
grafana_import_dashboard()
```

The Dashboard Library performs the HTTP communication while the Restore Service interprets the result.

This maintains a clear separation between orchestration and implementation.

---

# Statistics

Like the Backup Service, the Restore Service maintains execution statistics.

Typical values include:

```text
TOTAL

SUCCESS

FAILED
```

At completion, a summary similar to the following is displayed:

```text
====================================
Grafana-DR Summary
====================================
Dashboards Processed : 8
Successful           : 8
Failed               : 0
```

---

# Error Handling

Possible failures include:

* Missing dashboard file
* Invalid manifest
* Invalid JSON
* Checksum mismatch
* Import API failure
* Authentication failure

Each dashboard is handled independently.

A failure affecting one dashboard does not necessarily prevent remaining dashboards from being restored.

---

# Design Decisions

## Manifest-Driven Recovery

Restoration always begins with the manifest.

This guarantees that the same inventory produced during backup is used during recovery.

---

## Immutable Backups

Backup files are never modified.

All import-specific changes occur within temporary payloads.

This preserves the integrity of the original backups.

---

## Cross-Instance Restoration

Supporting restoration into a different Grafana installation was a major design objective.

The import payload transformation ensures compatibility across independent Grafana instances while maintaining backup fidelity.

---

## Separation of Responsibilities

The Restore Service coordinates the recovery workflow but does not:

* Communicate directly with HTTP endpoints
* Parse API responses
* Manipulate files directly
* Calculate checksums

Each responsibility is delegated to the appropriate library.

---

# Disaster Recovery Workflow

The complete recovery process is illustrated below.

```text
Git Repository
       │
       ▼
manifest.json
       │
       ▼
Dashboard Backup
       │
       ▼
Integrity Verification
       │
       ▼
Payload Transformation
       │
       ▼
Grafana Import API
       │
       ▼
Recovered Dashboard
```

This workflow enables rapid recovery of dashboard configurations on a standby Grafana instance.

---

# Summary

The Restore Service is the recovery engine of Grafana-DR.

By combining manifest-driven restoration, integrity verification, payload transformation, and cross-instance compatibility, it enables reliable disaster recovery while preserving the original backup artifacts.

Together with the Backup Service, it completes the application's end-to-end backup and recovery lifecycle.

---

# End of Chapter 5

At this stage, both primary workflows of Grafana-DR have been documented in detail.

The next chapter explores how data moves through the application—from Grafana to Git during backup and from Git back to Grafana during recovery—providing a complete view of the system's internal data flow.