# Chapter 10 – Testing and Validation

## Overview

Testing was performed continuously throughout the development of Grafana-DR rather than being deferred until the end of the project.

Each library, service, and workflow was validated independently before being integrated into the complete application.

This incremental approach simplified debugging, reduced integration issues, and ensured that every component behaved correctly before becoming part of the larger system.

Testing ultimately progressed through four stages:

1. Unit Testing
2. Integration Testing
3. End-to-End Testing
4. Cross-Instance Disaster Recovery Testing

---

# 10.1 Testing Strategy

Rather than testing only the finished application, every module was verified individually.

The development workflow followed the sequence below.

```text
Implement Feature
        │
        ▼
Create Test Script
        │
        ▼
Validate Functionality
        │
        ▼
Fix Issues
        │
        ▼
Integrate Into Service
        │
        ▼
Repeat
```

This approach allowed problems to be isolated to a single component before affecting the rest of the application.

---

# 10.2 Unit Testing

Each library was tested independently using dedicated scripts located in the `scripts/` directory.

Typical test scripts included:

```text
scripts/
├── test-dashboard.sh
├── test-backup.sh
├── test-restore.sh
└── test-git.sh
```

Each script exercised a specific subsystem without requiring the complete backup workflow.

---

# 10.3 Dashboard Library Testing

The Dashboard Library was validated by testing each public function individually.

The following operations were verified:

* Listing dashboards
* Exporting dashboards
* Importing dashboards

Successful tests confirmed:

* Correct API endpoints
* Valid authentication
* Expected JSON responses
* Successful dashboard imports

---

# 10.4 File Utility Testing

The File Utility Library was tested to ensure filesystem operations behaved safely.

The following scenarios were verified:

* Temporary file creation
* JSON validation
* Filename generation
* File comparison
* SHA-256 generation
* Atomic replacement

Special attention was given to `file_safe_write()` to ensure existing backups were never overwritten by invalid data.

---

# 10.5 Manifest Testing

Manifest generation was validated after every backup.

Verification included:

* Valid JSON syntax
* Correct dashboard count
* Correct metadata
* SHA-256 values
* File sizes

Additional testing ensured that unchanged backups did not unnecessarily regenerate the manifest.

---

# 10.6 Backup Service Testing

The Backup Service was tested using live Grafana dashboards.

Validation included:

* Dashboard discovery
* Dashboard export
* File generation
* Manifest creation
* Summary statistics

Example execution:

```text
====================================
Grafana-DR Summary
====================================
Dashboards Processed : 1
Successful           : 1
Failed               : 0
```

---

# 10.7 Restore Service Testing

The Restore Service was validated using previously generated backups.

The following sequence was tested:

* Manifest validation
* Dashboard discovery
* Payload transformation
* Dashboard restoration

Successful imports confirmed that exported dashboards could be reconstructed correctly.

---

# 10.8 Git Integration Testing

Git synchronization was tested under two scenarios.

### No Dashboard Changes

Expected behaviour:

```text
No Git changes detected.
```

No commit should be created.

---

### Dashboard Modified

Expected behaviour:

```text
Dashboard Updated
        │
        ▼
Manifest Updated
        │
        ▼
Git Commit
        │
        ▼
Git Push
```

Only meaningful changes should appear in repository history.

---

# 10.9 Manifest Optimization Validation

During development, an issue was identified where `manifest.json` always changed because of the `generated_at` timestamp.

This caused Git to create unnecessary commits even when dashboard content had not changed.

The implementation was modified so that the manifest is rewritten only when dashboard backups actually change.

Testing confirmed:

```text
Run Backup
      │
      ▼
No Dashboard Changes
      │
      ▼
Manifest Unchanged
      │
      ▼
No Git Commit
```

This significantly improved repository cleanliness.

---

# 10.10 Cross-Instance Testing

The most significant validation performed during development was restoration into a completely separate Grafana instance.

Test environment:

| Source         | Destination    |
| -------------- | -------------- |
| Debian 12      | macOS          |
| Grafana 13.1.1 | Grafana 13.1.1 |

Workflow:

```text
Primary Grafana
        │
        ▼
Backup
        │
        ▼
Git Push
        │
        ▼
Git Pull
        │
        ▼
Restore
        │
        ▼
Standby Grafana
```

This verified that backups were portable between independent systems.

---

# 10.11 Issues Identified During Testing

Several important implementation issues were discovered through testing.

## Read-only Bash Variable

Using the variable name `UID` caused failures because Bash reserves this variable.

Resolution:

* Renamed the variable to `DASHBOARD_UID`.

---

## Grafana Dashboard ID

Dashboard imports initially failed with:

```text
cannot change the ID of a dashboard
```

Resolution:

```text
dashboard.id = null
```

before import.

---

## Dashboard Version

Imports also required resetting:

```text
dashboard.version = 0
```

allowing Grafana to initialise version history on the destination instance.

---

## Datasource UID

Restoration initially failed because datasource UIDs differed between Grafana instances.

Resolution:

A matching datasource was created on the standby Grafana instance using the same UID as the primary environment.

This ensured dashboard references resolved correctly after import.

---

## Manifest Regeneration

Automatic timestamp updates caused unnecessary Git commits.

Resolution:

Only regenerate the manifest when dashboard files change.

---

# 10.12 Recovery Validation

To validate disaster recovery, the following scenario was executed.

```text
Delete Dashboard
       │
       ▼
Run Restore
       │
       ▼
Dashboard Recreated
```

The restored dashboard matched the backed-up version and functioned correctly after import.

---

# 10.13 Operational Validation Checklist

Before considering Grafana-DR production-ready, the following checks were completed:

* Dashboard export successful
* Dashboard restore successful
* JSON validation successful
* Manifest generated correctly
* Git synchronization successful
* Cross-instance restore successful
* No unnecessary Git commits
* Backup integrity verified using SHA-256

Completion of these checks provided confidence in both backup and recovery workflows.

---

# Lessons from Testing

Several important lessons emerged during development.

* Validate every layer independently before integration.
* Treat exported data as immutable.
* Verify disaster recovery using a different environment rather than restoring to the same system.
* Repository history should reflect configuration changes rather than execution timestamps.
* Cross-instance testing is essential because API behaviour may differ from single-instance testing.

---

# Summary

Testing played a central role in the development of Grafana-DR.

By validating each subsystem independently and performing full cross-instance disaster recovery testing, the project demonstrated that it can reliably export, synchronize, and restore Grafana dashboards across independent environments.

The testing process also uncovered several important implementation details—including dashboard identifier handling, datasource UID consistency, and manifest optimization—that significantly improved the reliability and portability of the final solution.

---

# Next Chapter

The next chapter documents common operational problems, diagnostic procedures, and recommended solutions in a comprehensive **Troubleshooting Guide**.