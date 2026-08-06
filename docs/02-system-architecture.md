# Chapter 2 – System Architecture

## 2.1 Architecture Overview

Grafana-DR follows a layered architecture where each layer has a single responsibility.

The application is intentionally divided into entry-point scripts, services, reusable libraries, and persistent backup artifacts. This separation improves maintainability, simplifies testing, and allows new features to be added without affecting existing components.

The overall architecture is shown below.

```text
                           ┌──────────────────────────────┐
                           │      Primary Grafana         │
                           │      (Production Server)     │
                           └──────────────┬───────────────┘
                                          │
                                  Grafana HTTP API
                                          │
                                          ▼
                           ┌──────────────────────────────┐
                           │      Backup Service          │
                           └──────────────┬───────────────┘
                                          │
                      ┌───────────────────┴───────────────────┐
                      │                                       │
                      ▼                                       ▼
             Dashboard JSON Files                    manifest.json
                      │                                       │
                      └───────────────────┬───────────────────┘
                                          │
                                          ▼
                               Git Repository (Local)
                                          │
                                          ▼
                                        GitHub
                                          │
                                          ▼
                           ┌──────────────────────────────┐
                           │      Standby Grafana         │
                           │        (Mac mini)            │
                           └──────────────┬───────────────┘
                                          │
                                   Restore Service
                                          │
                                          ▼
                                Grafana Import API
```

The project never communicates directly with the Grafana database.

All operations are performed through officially supported Grafana REST APIs.

---

# 2.2 Layered Architecture

Internally the application is divided into four logical layers.

```text
+----------------------------------------------------+
| Entry Point Scripts                                |
| backup-grafana.sh                                 |
| restore-grafana.sh                                |
+----------------------------------------------------+

+----------------------------------------------------+
| Services                                            |
| backup_service.sh                                  |
| restore_service.sh                                 |
+----------------------------------------------------+

+----------------------------------------------------+
| Libraries                                           |
| bootstrap.sh                                       |
| api.sh                                             |
| dashboard.sh                                       |
| file_utils.sh                                      |
| manifest.sh                                        |
| git.sh                                             |
| common.sh                                          |
| config.sh                                          |
+----------------------------------------------------+

+----------------------------------------------------+
| Backup Artifacts                                    |
| Dashboard JSON                                     |
| manifest.json                                      |
| Git Repository                                     |
+----------------------------------------------------+
```

Each layer communicates only with the layer immediately below it.

This minimizes coupling between modules and makes the project easier to maintain.

---

# 2.3 Entry Point Layer

The entry-point scripts represent the public interface of the application.

Examples:

```
backup-grafana.sh
restore-grafana.sh
```

These scripts intentionally contain almost no implementation logic.

Their responsibilities are limited to:

* Loading the application.
* Initializing the environment.
* Calling the appropriate service.
* Exiting with an appropriate status.

Keeping entry points small improves readability and prevents business logic from becoming scattered throughout executable scripts.

---

# 2.4 Service Layer

Services implement complete workflows.

Unlike libraries, services coordinate multiple operations to accomplish a larger task.

Current services include:

```
backup_service.sh
restore_service.sh
```

For example, the backup service performs:

```
Initialize
      │
      ▼
List Dashboards
      │
      ▼
Export Dashboard
      │
      ▼
Validate JSON
      │
      ▼
Write File
      │
      ▼
Update Manifest
      │
      ▼
Print Summary
```

The restore service performs the reverse workflow.

Services are responsible for orchestration rather than low-level implementation.

---

# 2.5 Library Layer

Libraries contain reusable functionality shared across the project.

Each library focuses on a single responsibility.

| Library       | Responsibility                      |
| ------------- | ----------------------------------- |
| bootstrap.sh  | Application initialization          |
| config.sh     | Configuration values                |
| common.sh     | Logging, initialization, validation |
| api.sh        | Generic HTTP communication          |
| dashboard.sh  | Dashboard-specific API operations   |
| file_utils.sh | Generic filesystem utilities        |
| manifest.sh   | Backup metadata management          |
| git.sh        | Git operations                      |

This modular design minimizes duplicate code and allows each component to evolve independently.

---

# 2.6 Backup Workflow

The backup workflow consists of several stages.

```
Start
   │
   ▼
Initialize Environment
   │
   ▼
Verify Dependencies
   │
   ▼
Verify Grafana Connectivity
   │
   ▼
Retrieve Dashboard List
   │
   ▼
For Each Dashboard
   │
   ├───────────────► Export Dashboard
   │
   ├───────────────► Validate JSON
   │
   ├───────────────► Compare Existing Backup
   │
   ├───────────────► Write Updated Backup
   │
   └───────────────► Update Manifest
   │
   ▼
Any Dashboard Changed?
   │
 ┌─┴──────────────┐
 │                │
No               Yes
 │                │
 ▼                ▼
Exit         Git Synchronization
                  │
                  ▼
              Backup Complete
```

Only changed dashboards produce updated files.

This minimizes unnecessary filesystem writes and Git commits.

---

# 2.7 Restore Workflow

The restore workflow reconstructs dashboards from the backup repository.

```
Start
   │
   ▼
Initialize Environment
   │
   ▼
Validate Manifest
   │
   ▼
Read Dashboard Files
   │
   ▼
Verify Checksums
   │
   ▼
Prepare Import Payload
   │
   ▼
Reset Dashboard ID
   │
   ▼
Reset Dashboard Version
   │
   ▼
Import Dashboard
   │
   ▼
Repeat Until Complete
   │
   ▼
Print Summary
```

During restoration the exported dashboard format is automatically transformed into the JSON structure required by the Grafana Import API.

This enables restoration into completely different Grafana installations.

---

# 2.8 Git Integration Workflow

Git is treated as the authoritative storage for dashboard history.

```
Dashboard Modified
        │
        ▼
Backup Created
        │
        ▼
Manifest Updated
        │
        ▼
Git Status
        │
 ┌──────┴──────────┐
 │                 │
No Changes     Changes Found
 │                 │
 ▼                 ▼
Exit         Commit Changes
                    │
                    ▼
               Push to GitHub
```

A commit is created only when backup artifacts have changed.

This avoids unnecessary commits caused by timestamps or log files.

---

# 2.9 Disaster Recovery Architecture

The project was designed around a primary/standby deployment model.

```
                Production Site

        Debian Linux Server
      +------------------------+
      |      Grafana           |
      |     Prometheus         |
      |  Backup Scheduler      |
      +-----------+------------+
                  |
                  |
             Git Push
                  |
                  ▼
             GitHub Repository
                  ▲
                  |
              Git Pull
                  |
      +-----------+------------+
      |      Mac mini          |
      |  Grafana (Stopped)     |
      | Restore Toolkit        |
      +------------------------+
```

The standby Grafana instance remains powered on but the Grafana service remains stopped until disaster recovery is required.

This minimizes CPU and memory consumption while still allowing rapid recovery.

---

# 2.10 Design Decisions

Several architectural decisions were made during development.

### REST API Instead of Database Access

The Grafana HTTP API is officially supported and remains stable across releases.

Using the API avoids coupling the project to Grafana's internal database schema.

---

### Modular Libraries

Every module has a single responsibility.

This significantly reduces maintenance complexity and allows components to be tested independently.

---

### Manifest-Based Backups

A manifest provides metadata that cannot easily be derived from filenames alone.

The manifest stores:

* Dashboard UID
* Dashboard title
* Backup filename
* SHA-256 checksum
* File size
* Grafana version

This enables backup validation before restoration.

---

### Atomic File Writes

Backup files are never written directly.

Instead:

1. Export to a temporary file.
2. Validate JSON.
3. Compare with existing backup.
4. Atomically replace the destination.

This prevents incomplete or corrupted backups in the event of interruption.

---

### Git as the Source of Truth

Rather than maintaining a proprietary backup database, Grafana-DR treats Git as the definitive record of dashboard history.

This provides:

* Version control
* Audit history
* Rollback capability
* Remote replication
* Collaboration support

without introducing additional infrastructure.

---

# 2.11 Summary

The layered architecture adopted by Grafana-DR separates orchestration, implementation, and persistent data into clearly defined components.

This design provides:

* High maintainability
* Low coupling
* Clear separation of responsibilities
* Easy extensibility
* Reliable disaster recovery
* Efficient Git-based version management

The following chapter examines the project directory structure and explains the purpose of every file and directory in the repository.