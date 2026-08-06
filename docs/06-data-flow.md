# Chapter 6 – Data Flow

## Overview

The previous chapters described the individual components that make up Grafana-DR.

This chapter focuses on how information flows between those components during normal operation.

Understanding these data flows is essential for:

* Troubleshooting
* Extending the project
* Performance analysis
* Disaster recovery validation

Grafana-DR primarily implements two workflows:

* Backup Workflow
* Restore Workflow

Both workflows are built upon the same reusable libraries while processing data in opposite directions.

---

# 6.1 Complete Backup Data Flow

The backup process begins when the user executes:

```bash
./backup-grafana.sh
```

The complete workflow is illustrated below.

```text
User
 │
 ▼
backup-grafana.sh
 │
 ▼
bootstrap.sh
 │
 ▼
initialize()
 │
 ▼
backup_service.sh
 │
 ▼
grafana_list_dashboards()
 │
 ▼
For Each Dashboard
 │
 ▼
grafana_export_dashboard()
 │
 ▼
Grafana HTTP API
 │
 ▼
Dashboard JSON
 │
 ▼
file_create_temp()
 │
 ▼
Temporary File
 │
 ▼
file_validate_json()
 │
 ▼
file_safe_write()
 │
 ▼
Dashboard Backup
 │
 ▼
manifest_add()
 │
 ▼
Next Dashboard
 │
 ▼
manifest_finish()
 │
 ▼
manifest.json
 │
 ▼
git_sync()
 │
 ▼
GitHub
```

Every dashboard follows exactly the same pipeline.

No dashboard bypasses validation.

---

# 6.2 Dashboard Discovery

The first stage of the backup process is dashboard discovery.

The Backup Service requests the dashboard inventory.

```text
Backup Service
        │
        ▼
GET /api/search
        │
        ▼
Dashboard Inventory
```

The returned inventory contains metadata including:

* Dashboard UID
* Dashboard Title
* Dashboard URL

Only the UID is required for export.

---

# 6.3 Dashboard Export

Each dashboard is exported independently.

```text
Dashboard UID
      │
      ▼
GET /api/dashboards/uid/{uid}
      │
      ▼
Export JSON
```

The export is stored exactly as returned by Grafana.

No modifications are performed.

This preserves backup fidelity.

---

# 6.4 Temporary Processing

Rather than writing exports directly into the backup directory, the Backup Service uses a temporary file.

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

This protects existing backups against corruption.

---

# 6.5 Validation Pipeline

Before any backup replaces an existing file, several validation stages occur.

```text
Export JSON
      │
      ▼
File Exists?
      │
      ▼
Valid JSON?
      │
      ▼
Compare Existing Backup
      │
      ▼
Changed?
```

Possible outcomes:

```text
Changed
     │
     ▼
Write New Backup

Unchanged
     │
     ▼
Skip Replacement

Invalid
     │
     ▼
Abort Backup
```

Only validated exports reach permanent storage.

---

# 6.6 Manifest Generation

Once all dashboards have been processed, metadata collected during backup is written into `manifest.json`.

```text
Dashboard 1 Metadata
        │
Dashboard 2 Metadata
        │
Dashboard 3 Metadata
        │
        ▼
Manifest Collection
        │
        ▼
manifest.json
```

The manifest becomes the authoritative index of the backup.

---

# 6.7 Git Synchronization

After successful backup completion:

```text
Dashboard Files
       │
       ▼
Manifest
       │
       ▼
git status
       │
 ┌─────┴─────┐
 │           │
No Changes  Changes
 │           │
 ▼           ▼
Exit      Commit
               │
               ▼
            Git Push
```

Only meaningful changes are committed.

---

# 6.8 Complete Restore Data Flow

The restore workflow begins with:

```bash
./restore-grafana.sh
```

Overall flow:

```text
User
 │
 ▼
restore-grafana.sh
 │
 ▼
bootstrap.sh
 │
 ▼
initialize()
 │
 ▼
restore_service.sh
 │
 ▼
manifest_validate()
 │
 ▼
manifest_read()
 │
 ▼
For Each Dashboard
 │
 ▼
Checksum Verification
 │
 ▼
Transform Payload
 │
 ▼
grafana_import_dashboard()
 │
 ▼
Grafana Import API
 │
 ▼
Dashboard Restored
```

The workflow mirrors the backup process in reverse.

---

# 6.9 Payload Transformation

One of the most important stages during restoration is payload transformation.

```text
Export Backup
       │
       ▼
Extract dashboard
       │
       ▼
id = null
       │
       ▼
version = 0
       │
       ▼
folderUid preserved
       │
       ▼
overwrite = true
       │
       ▼
Import Payload
```

This transformation is temporary.

The backup itself is never modified.

---

# 6.10 Cross-Instance Recovery Flow

During testing, backups were restored into an independent Grafana installation.

```text
Primary Grafana
      │
      ▼
Dashboard Export
      │
      ▼
Git Repository
      │
      ▼
Mac mini
      │
      ▼
Restore Service
      │
      ▼
Grafana Import
      │
      ▼
Recovered Dashboard
```

Because dashboard IDs are reset during restoration, Grafana automatically assigns new internal identifiers.

This enables restoration across different Grafana databases.

---

# 6.11 Data Ownership

Every component owns a specific type of data.

| Component            | Owns                   |
| -------------------- | ---------------------- |
| Grafana              | Dashboard definitions  |
| Dashboard Library    | Dashboard operations   |
| File Utility Library | Filesystem operations  |
| Manifest Library     | Backup metadata        |
| Git Library          | Repository state       |
| Backup Service       | Backup orchestration   |
| Restore Service      | Recovery orchestration |

No component modifies data owned by another component.

This separation greatly simplifies maintenance.

---

# 6.12 Data Integrity

Grafana-DR implements multiple layers of protection.

```text
Grafana Export
      │
      ▼
JSON Validation
      │
      ▼
Safe File Write
      │
      ▼
SHA-256
      │
      ▼
Manifest
      │
      ▼
Git Repository
      │
      ▼
Checksum Verification
      │
      ▼
Restore
```

Every stage contributes to protecting backup integrity.

---

# 6.13 Error Propagation

Errors move upward through the architecture.

```text
Filesystem Error
       │
       ▼
File Library
       │
       ▼
Backup Service
       │
       ▼
Summary
       │
       ▼
Exit Code
```

This allows low-level libraries to remain reusable while services determine how failures affect the workflow.

---

# Chapter Summary

The Data Flow chapter demonstrates how Grafana-DR transforms independent libraries into a complete disaster recovery system.

The backup workflow acquires dashboard definitions, validates them, stores them safely, records metadata, and synchronizes them through Git.

The restore workflow reverses this process, validating backup integrity before reconstructing dashboards on another Grafana instance.

Understanding these flows provides the foundation for extending Grafana-DR with additional resource types such as datasources, alert rules, folders, or plugins while preserving the existing architecture.