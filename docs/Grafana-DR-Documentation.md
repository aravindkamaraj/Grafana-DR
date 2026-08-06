# Grafana-DR Technical Documentation

**Version:** 1.1.0

---

# Chapter 1 – Introduction

## 1.1 Project Overview

Grafana-DR is a modular Bash-based Disaster Recovery (DR) toolkit designed to automate the backup, version control, and restoration of Grafana dashboards.

The project was created to provide a lightweight, reliable, and fully scriptable solution for protecting Grafana dashboard configurations without relying on proprietary backup software or manual exports.

Instead of treating Grafana dashboards as static configuration files, Grafana-DR interacts directly with the Grafana HTTP API to export dashboards, store them in Git, and restore them whenever required.

The toolkit was intentionally designed around standard Linux utilities such as Bash, curl, jq, Git, and SHA-256 so that it can run on virtually any Linux or macOS system without requiring additional frameworks or programming languages.

---

## 1.2 Problem Statement

Grafana stores dashboards internally within its database.

Although dashboards can be exported manually through the Grafana web interface, this approach presents several limitations:

* Manual exports are time consuming.
* Version history is difficult to maintain.
* Human error increases during repetitive exports.
* Disaster recovery requires multiple manual steps.
* Restoring dashboards to another Grafana instance can become inconsistent.

In production environments these limitations become increasingly problematic.

A reliable Disaster Recovery solution should automatically:

* Detect dashboard changes.
* Export dashboards.
* Maintain historical versions.
* Preserve dashboard integrity.
* Restore dashboards to another Grafana instance with minimal manual effort.

Grafana-DR was created to satisfy these requirements.

---

## 1.3 Project Objectives

The primary objectives of Grafana-DR are:

* Automate dashboard backups.
* Eliminate manual dashboard exports.
* Maintain dashboard history using Git.
* Support cross-instance dashboard restoration.
* Verify backup integrity.
* Minimize recovery time during disasters.
* Provide a modular and maintainable codebase.
* Follow production-quality Bash scripting practices.

The project intentionally focuses only on dashboard backup and restoration. Other Grafana resources such as datasources, plugins, alert rules, and users are considered future enhancements.

---

## 1.4 Design Philosophy

Several architectural principles guided the design of Grafana-DR.

### Modularity

Every component has a single responsibility.

For example:

* `api.sh` only communicates with the Grafana HTTP API.
* `dashboard.sh` only performs dashboard-specific operations.
* `manifest.sh` only manages backup metadata.
* `git.sh` only performs Git operations.

This separation reduces coupling between components and simplifies future maintenance.

---

### Reusability

Functions are written to be generic whenever possible.

Examples include:

* Generic HTTP request functions.
* Generic file utility functions.
* Generic logging utilities.

These functions can be reused by multiple services without duplication.

---

### Separation of Responsibilities

Entry-point scripts contain almost no implementation logic.

Instead:

* Entry-point scripts initialize the application.
* Services implement workflows.
* Libraries implement reusable functionality.

This creates a clear separation between orchestration and implementation.

---

### Reliability

Reliability was prioritized throughout the project.

Examples include:

* Dependency validation before execution.
* API connectivity verification.
* JSON validation.
* SHA-256 checksum verification.
* Atomic file replacement.
* Manifest validation.
* Error handling using return codes.

These checks reduce the likelihood of silent failures and corrupted backups.

---

### GitOps-Oriented Workflow

Instead of treating backups as isolated files, Grafana-DR integrates with Git.

Every dashboard becomes a version-controlled artifact.

This provides:

* Complete history
* Change tracking
* Rollback capability
* Remote replication through GitHub

Only meaningful changes generate Git commits, preventing unnecessary repository updates.

---

### Cross-Platform Compatibility

The toolkit was designed to operate across different operating systems.

Current deployment model:

* Primary Grafana Server

  * Debian Linux
  * Grafana running continuously

* Disaster Recovery Server

  * macOS (Mac mini)
  * Grafana installed using Homebrew
  * Grafana service started only during disaster recovery

Because the project depends only on standard command-line utilities, the same codebase operates consistently across both environments.

---

## 1.5 Project Scope

Current project scope includes:

* Dashboard backup
* Dashboard restoration
* Manifest generation
* Manifest validation
* Dashboard integrity verification
* Git synchronization
* Cross-instance dashboard restoration

The following capabilities are outside the current scope:

* Datasource backup
* Alert rule backup
* User management
* Plugin management
* Grafana provisioning files
* Database backup

These features may be implemented in future releases.

---

## 1.6 Intended Audience

This documentation is intended for:

* Linux System Administrators
* DevOps Engineers
* Site Reliability Engineers (SREs)
* Home Lab Enthusiasts
* Infrastructure Engineers
* Future maintainers of the Grafana-DR project

No prior knowledge of the internal implementation is assumed. Each component of the project is documented in detail throughout the following chapters.

---

## 1.7 Document Structure

This documentation is organized into multiple chapters.

Subsequent chapters cover:

* System Architecture
* Project Structure
* Library Reference
* Service Reference
* Backup Workflow
* Restore Workflow
* Git Integration
* Configuration
* Deployment
* Troubleshooting
* Future Enhancements

Together, these chapters provide a complete technical reference for understanding, deploying, maintaining, and extending Grafana-DR.

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

# Chapter 3 – Project Structure

## 3.1 Repository Overview

Grafana-DR follows a structured repository layout that separates executable scripts, reusable libraries, service implementations, backup artifacts, and project documentation.

The directory structure was intentionally designed to make the project easy to understand, extend, and maintain.

```
Grafana-DR/
│
├── backup-grafana.sh
├── restore-grafana.sh
├── VERSION
├── LICENSE
├── README.md
├── CHANGELOG.md
│
├── dashboards/
├── docs/
├── lib/
├── logs/
├── scripts/
└── services/
```

Each directory serves a specific purpose and contains only closely related files.

---

# 3.2 Root Directory

The root directory contains the project's public interface and metadata.

```
Grafana-DR/
│
├── backup-grafana.sh
├── restore-grafana.sh
├── README.md
├── CHANGELOG.md
├── LICENSE
└── VERSION
```

These files represent the entry point of the project.

---

## backup-grafana.sh

This is the production backup executable.

Responsibilities:

* Initialize the application.
* Load all required libraries.
* Execute the backup workflow.
* Synchronize changes to Git.

This script intentionally contains almost no implementation logic.

All backup operations are delegated to the Backup Service.

---

## restore-grafana.sh

This is the production restore executable.

Responsibilities:

* Initialize the application.
* Validate the backup repository.
* Restore dashboards into Grafana.

Like the backup entry point, this script delegates all business logic to the Restore Service.

---

## README.md

Provides a concise overview of the project.

Target audience:

* GitHub visitors
* Recruiters
* New users

It explains:

* What the project does.
* Features.
* Installation.
* Basic usage.
* High-level architecture.

The README intentionally avoids implementation details.

---

## CHANGELOG.md

Maintains the release history.

Each version documents:

* Added features.
* Changed functionality.
* Bug fixes.
* Breaking changes.

The changelog provides historical context for the evolution of the project.

---

## LICENSE

Defines the legal terms under which the project is distributed.

Grafana-DR uses the MIT License.

---

## VERSION

Stores the current project version.

Keeping the version in a dedicated file avoids hardcoding version strings throughout the project.

---

# 3.3 dashboards/

```
dashboards/
│
├── host-temperature__adpj4mw.json
├── ...
└── manifest.json
```

This directory contains all exported dashboard backups.

Each dashboard is stored as an individual JSON file.

Using one file per dashboard provides several advantages:

* Independent version history.
* Smaller Git commits.
* Easier comparison between versions.
* Simpler restoration.

---

## Dashboard File Naming

Dashboard filenames are automatically generated.

Example:

```
host-temperature__adpj4mw.json
```

The filename contains:

* Sanitized dashboard title
* Dashboard UID

Including the UID guarantees uniqueness even when dashboard titles are duplicated.

---

## manifest.json

The manifest acts as the index for the backup repository.

It contains metadata such as:

* Backup timestamp
* Grafana version
* Dashboard count
* Dashboard filename
* Dashboard UID
* SHA-256 checksum
* File size

The manifest enables integrity verification before restoration.

---

# 3.4 lib/

```
lib/
│
├── api.sh
├── bootstrap.sh
├── common.sh
├── config.sh
├── dashboard.sh
├── file_utils.sh
├── git.sh
└── manifest.sh
```

The `lib` directory contains reusable components shared throughout the project.

Libraries never implement complete workflows.

Instead, they expose reusable functions.

---

## bootstrap.sh

Responsible for application startup.

Typical responsibilities include:

* Loading configuration.
* Loading all required libraries.
* Preparing the runtime environment.
* Providing the `initialize()` function.

Every executable script begins by sourcing this library.

---

## config.sh

Contains project configuration.

Examples include:

* Grafana URL
* API timeout
* Retry count
* Directory locations
* Manifest path
* Log file location

Keeping configuration separate from implementation simplifies maintenance.

---

## common.sh

Contains generic helper functions shared across the application.

Examples include:

* Logging
* Dependency checking
* Directory creation
* Token loading
* Banner display
* Environment initialization

This library provides the common functionality used throughout the project.

---

## api.sh

Implements generic HTTP communication.

This library intentionally has no Grafana-specific knowledge.

It provides reusable wrappers for:

* GET
* POST
* PUT
* DELETE

All HTTP requests pass through this abstraction layer.

---

## dashboard.sh

Implements Grafana dashboard operations.

Examples include:

* Listing dashboards
* Exporting dashboards
* Importing dashboards

Unlike `api.sh`, this library understands Grafana's REST API and dashboard JSON format.

---

## file_utils.sh

Provides generic filesystem utilities.

Examples:

* Temporary file creation
* JSON validation
* Atomic writes
* SHA-256 calculation
* Filename generation
* File comparison

These utilities are reusable outside of Grafana-specific workflows.

---

## manifest.sh

Manages the backup manifest.

Responsibilities include:

* Manifest initialization
* Dashboard registration
* Manifest generation
* Manifest validation
* Manifest reading

The manifest is treated as the authoritative inventory of the backup repository.

---

## git.sh

Encapsulates all Git operations.

Responsibilities include:

* Repository validation
* Detecting changes
* Staging files
* Creating commits
* Pushing to the remote repository

Separating Git functionality from the backup workflow improves modularity.

---

# 3.5 services/

```
services/
│
├── backup_service.sh
└── restore_service.sh
```

Services coordinate multiple library functions to implement complete workflows.

---

## backup_service.sh

Responsible for:

* Listing dashboards
* Exporting dashboards
* Validating JSON
* Writing backup files
* Updating the manifest
* Producing backup summaries

It represents the core backup engine.

---

## restore_service.sh

Responsible for:

* Reading the manifest
* Verifying checksums
* Transforming dashboard JSON
* Restoring dashboards
* Reporting results

It represents the core recovery engine.

---

# 3.6 logs/

```
logs/
└── grafana-dr.log
```

All runtime logs are written to this directory.

The log file records:

* Informational messages
* Warnings
* Errors
* Backup activity
* Restore activity

The directory is excluded from Git version control because log files are operational data rather than source code.

---

# 3.7 scripts/

```
scripts/
│
├── test-backup.sh
├── test-dashboard.sh
├── test-git.sh
├── test-import.sh
└── test-restore.sh
```

The `scripts` directory contains development and testing utilities.

These scripts are not intended for production use.

They exist to verify individual components during development.

Examples include:

* Testing dashboard exports.
* Testing dashboard imports.
* Testing Git integration.
* Testing backup workflows.
* Testing restore workflows.

Maintaining separate test scripts avoids mixing development logic with production entry points.

---

# 3.8 Documentation Files

Project documentation is separated into multiple files.

| File             | Purpose             |
| ---------------- | ------------------- |
| README.md        | Project overview    |
| CHANGELOG.md     | Release history     |
| LICENSE          | License information |
| DOCUMENTATION.md | Technical reference |

Each document targets a different audience and serves a distinct purpose.

---

# 3.9 Design Principles Behind the Structure

Several principles guided the repository layout.

### Single Responsibility

Every directory exists for one purpose.

Examples:

* Libraries contain reusable code.
* Services contain workflows.
* Scripts contain test utilities.
* Dashboards contain backup artifacts.

---

### Predictability

Developers should know where new functionality belongs.

For example:

* New reusable helpers belong in `lib/`.
* New workflows belong in `services/`.
* New production commands belong in the repository root.
* New test programs belong in `scripts/`.

---

### Scalability

The current structure allows future additions without major reorganization.

Potential future files include:

```
services/
    datasource_service.sh

lib/
    datasource.sh

scripts/
    test-datasource.sh

backup-datasources.sh
```

Existing code would remain unaffected.

---

# 3.10 Summary

The repository layout reflects the project's architectural principles:

* Clear separation of responsibilities.
* Minimal coupling.
* High maintainability.
* Easy extensibility.
* Consistent organization.

Understanding the repository structure provides the foundation for understanding the implementation details covered in subsequent chapters.

The next chapter begins the Library Reference, starting with the application bootstrap process and the configuration subsystem.

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


# Chapter 7 – Error Handling and Reliability

## Overview

Reliability was a primary design objective throughout the development of Grafana-DR.

Rather than assuming that every API request, filesystem operation, or Git command succeeds, the application validates every critical operation before continuing.

Failures are detected as early as possible and propagated back to the service layer, where they are reported to the user through standardized log messages and execution summaries.

The objective is not to eliminate failures, but to ensure that failures are:

* Predictable
* Detectable
* Recoverable
* Informative

---

# 7.1 Error Handling Philosophy

Grafana-DR follows the **Fail Fast** principle.

Whenever a critical prerequisite cannot be satisfied, execution stops immediately rather than allowing subsequent operations to produce inconsistent results.

Examples include:

* Missing dependencies
* Missing API token
* Grafana unavailable
* Invalid configuration
* Invalid manifest

Stopping early prevents cascading failures later in the workflow.

---

# 7.2 Error Handling Layers

Errors are handled at multiple layers throughout the application.

```text
                User
                  ▲
                  │
          Entry Point Script
                  ▲
                  │
             Service Layer
                  ▲
                  │
           Library Layer
                  ▲
                  │
 Operating System / Grafana API
```

Each layer is responsible only for errors that belong to that layer.

---

# 7.3 Dependency Validation

Before any backup or restore operation begins, Grafana-DR verifies that all required software is installed.

Examples include:

* curl
* jq
* Git

Workflow:

```text
Start
 │
 ▼
Dependency Check
 │
 ├── curl?
 ├── jq?
 └── Git?
 │
 ▼
Continue
```

If any dependency is missing, initialization terminates immediately with an informative log message.

---

# 7.4 Configuration Validation

Configuration values are validated during initialization.

Typical validation includes:

* Required directories
* Token file
* Project structure
* Environment preparation

Configuration errors are treated as fatal because execution cannot continue safely without them.

---

# 7.5 Grafana Connectivity

Before interacting with the Grafana API, connectivity is verified using the health endpoint.

```text
/api/health
```

Possible outcomes:

```text
Reachable
    │
    ▼
Continue

Unavailable
    │
    ▼
Abort
```

This prevents unnecessary processing when Grafana is offline.

---

# 7.6 HTTP Request Reliability

Every HTTP request uses standardized connection settings.

These include:

* Connection timeout
* Maximum execution time
* Retry attempts
* Authentication headers

Temporary network interruptions therefore do not immediately cause backup failures.

---

# 7.7 JSON Validation

Every dashboard export is validated before being accepted as a backup.

Workflow:

```text
Dashboard Export
       │
       ▼
jq Validation
       │
 ┌─────┴─────┐
 │           │
Valid     Invalid
 │           │
 ▼           ▼
Continue   Reject
```

Invalid JSON is never written into the backup repository.

---

# 7.8 Safe File Replacement

Existing backups are protected through atomic replacement.

Workflow:

```text
Temporary File
      │
      ▼
Validate JSON
      │
      ▼
Compare Existing Backup
      │
      ▼
Atomic Replace
```

This ensures that valid backups are never overwritten by incomplete or corrupted files.

---

# 7.9 Manifest Validation

The manifest is validated both after creation and before restoration.

Validation ensures:

* Correct JSON syntax
* Readable manifest
* Consistent recovery inventory

Restoration is never attempted using an invalid manifest.

---

# 7.10 Integrity Verification

Dashboard integrity is verified using SHA-256 checksums.

Workflow:

```text
Backup
   │
   ▼
Generate SHA-256
   │
   ▼
Store in Manifest
   │
   ▼
Restore
   │
   ▼
Recalculate SHA-256
   │
   ▼
Compare
```

A mismatch indicates that the backup has been modified or corrupted.

---

# 7.11 Return Code Strategy

Rather than returning only success or failure, several libraries return symbolic status codes.

Examples include:

| Return Code       | Meaning                          |
| ----------------- | -------------------------------- |
| FILE_SUCCESS      | Operation completed successfully |
| FILE_NO_CHANGE    | Backup already current           |
| FILE_INVALID_JSON | Invalid JSON detected            |
| FILE_TEMP_MISSING | Temporary file unavailable       |

This allows higher-level services to distinguish between expected conditions and actual failures.

---

# 7.12 Logging Strategy

Every significant operation is recorded.

Typical log levels include:

```text
INFO
ERROR
```

Examples:

```text
[INFO] Backing up dashboard: Host Temperature

[INFO] Saved: host-temperature__adpj4mw.json

[ERROR] Invalid JSON received.
```

Standardized logging simplifies troubleshooting and provides a chronological execution record.

---

# 7.13 Failure Isolation

One dashboard failure should not necessarily terminate the entire backup.

Instead:

```text
Dashboard 1
   │
Success

Dashboard 2
   │
Failure

Dashboard 3
   │
Success
```

Execution continues whenever possible.

This maximizes successful backups during partial failures.

---

# 7.14 Recovery from Failures

Grafana-DR attempts recovery where appropriate.

Examples include:

* HTTP retries
* Safe file replacement
* Validation before replacement

Operations that cannot be recovered safely are aborted.

---

# 7.15 Design Decisions

## Validate Before Trust

External data is never trusted automatically.

Every dashboard export is validated before becoming part of the backup repository.

---

## Fail Early

Critical errors are detected during initialization rather than during processing.

This avoids wasted execution and confusing error messages.

---

## Separate Detection from Reporting

Libraries detect failures.

Services determine how those failures affect the overall workflow.

This keeps libraries reusable while allowing services to implement application-specific behaviour.

---

## Protect Existing Backups

An existing valid backup is always considered more valuable than an unverified replacement.

For this reason, validation always precedes replacement.

---

## Minimize Silent Failures

Every failure produces:

* A return code
* A log entry
* Updated execution statistics

This provides operators with enough information to diagnose problems without inspecting the source code.

---

# 7.16 Summary

Grafana-DR implements multiple independent layers of validation and error handling to ensure reliable operation.

Rather than relying on optimistic assumptions, every critical operation is verified before execution continues.

This layered approach significantly reduces the likelihood of corrupted backups, inconsistent restores, and silent failures, making the toolkit suitable for disaster recovery scenarios where reliability is more important than execution speed.


# Chapter 8 – Configuration

## Overview

Grafana-DR was designed with the principle that deployment-specific values should be separated from application logic.

Rather than embedding environment-specific information throughout the codebase, all configurable parameters are centralized within the Configuration Library (`config.sh`).

This separation provides several benefits:

* Easier deployment
* Simplified maintenance
* Environment portability
* Reduced implementation complexity

Changing deployment settings should rarely require modifications to service or library code.

---

# 8.1 Configuration Architecture

The configuration subsystem provides a single source of truth for application settings.

```text id="c7p4rn"
                 config.sh
                     │
     ┌───────────────┼───────────────┐
     │               │               │
     ▼               ▼               ▼
 Grafana         Directories      API Settings
 Configuration    & Paths         & Timeouts
                     │
                     ▼
            All Libraries & Services
```

Every component references configuration values through this central configuration file.

---

# 8.2 Configuration Categories

Configuration values are organized into logical groups.

## Application Configuration

Contains general project information.

Typical values include:

* Project version
* Project root directory

These values identify the running version of Grafana-DR and define the project's filesystem layout.

---

## Grafana Configuration

Contains parameters required to communicate with Grafana.

Typical values include:

* Grafana URL
* Service Account Token location

Example:

```text id="9qjylu"
GRAFANA_URL

TOKEN_FILE
```

These settings are deployment-specific and should be updated whenever Grafana is installed in a different environment.

---

## API Configuration

Controls HTTP communication behaviour.

Typical settings include:

* Retry count
* Connection timeout
* Maximum request duration

These values balance reliability with execution time.

Increasing retry counts improves resilience during temporary network interruptions but may increase overall execution time.

---

## Directory Configuration

Defines the locations used by Grafana-DR.

Typical directories include:

```text id="2ztjqt"
Dashboard Backup Directory

Log Directory

Documentation Directory

Project Root
```

Centralizing directory paths avoids hardcoded filesystem locations throughout the project.

---

## Manifest Configuration

Defines the location of the generated backup manifest.

Typical value:

```text id="hbxg3g"
MANIFEST_FILE
```

The Restore Service relies on this location to locate the backup inventory.

---

## Return Code Definitions

Several symbolic return codes are defined within the configuration subsystem.

Examples include:

```text id="3t6j3n"
FILE_SUCCESS

FILE_NO_CHANGE

FILE_INVALID_JSON

FILE_TEMP_MISSING
```

Using symbolic names instead of numeric literals greatly improves readability.

---

# 8.3 Configuration Flow

The configuration loading process occurs during application initialization.

```text id="cn8twv"
Application Start
        │
        ▼
bootstrap.sh
        │
        ▼
Load config.sh
        │
        ▼
Export Configuration
        │
        ▼
Load Libraries
        │
        ▼
Ready
```

Every library receives the same configuration values.

---

# 8.4 Sensitive Configuration

Not all configuration values should be stored in version control.

The Grafana Service Account Token is considered sensitive information.

Rather than embedding the token inside the source code, Grafana-DR loads it from an external file during initialization.

Advantages include:

* Reduced risk of accidental disclosure
* Easier token rotation
* Cleaner Git history
* Improved security

The token file should never be committed to the repository.

---

# 8.5 Environment Portability

One of the project's design goals is supporting multiple environments with minimal configuration changes.

Examples include:

### Primary Server

```text id="s8vfkr"
Operating System:
Debian Linux

Grafana URL:
http://localhost:3000
```

### Standby Server

```text id="m3crsu"
Operating System:
macOS

Grafana URL:
http://localhost:3000
```

Although the operating systems differ, the application code remains unchanged.

Only deployment-specific configuration values require adjustment.

---

# 8.6 Configuration Validation

Configuration values are validated during initialization.

Examples include:

* Required directories
* Token file existence
* Grafana connectivity

Invalid configuration causes initialization to terminate before any backup or restore operation begins.

This prevents inconsistent application behaviour.

---

# 8.7 Configuration Best Practices

Several practices were followed during development.

## Centralization

Configuration values exist in only one location.

This prevents conflicting definitions.

---

## Readability

Variable names are descriptive and self-explanatory.

Examples:

```text id="z6ztot"
API_TIMEOUT

TOKEN_FILE

DASHBOARD_DIR
```

The purpose of each variable should be immediately obvious.

---

## Separation from Business Logic

Configuration should never be mixed with implementation.

Libraries consume configuration values but never define deployment-specific settings.

---

## Future Expansion

The current configuration structure allows future additions without restructuring.

Potential future configuration sections include:

* Datasource backup settings
* Alert rule settings
* Plugin backup configuration
* Compression options
* Encryption settings

---

# 8.8 Version Management

The project version is maintained separately from implementation logic.

Rather than embedding version strings throughout the codebase, Grafana-DR maintains a single project version that is referenced by:

* Application banner
* Documentation
* Git release tags

This ensures version consistency throughout the project.

---

# 8.9 Configuration Lifecycle

The complete configuration lifecycle is shown below.

```text id="qw81kj"
Load Configuration
        │
        ▼
Validate Values
        │
        ▼
Initialize Environment
        │
        ▼
Execute Workflow
        │
        ▼
Application Exit
```

Configuration remains constant throughout execution.

No runtime modification of configuration values occurs.

---

# Design Decisions

## Single Source of Truth

Every configurable value exists in one place.

This greatly simplifies deployment and maintenance.

---

## Environment Independence

Application logic is completely independent of deployment-specific configuration.

This allows Grafana-DR to operate across multiple environments without code modifications.

---

## Minimal Configuration Surface

Only deployment-specific values are configurable.

Implementation details remain fixed.

This reduces the likelihood of accidental misconfiguration.

---

## Secure by Design

Sensitive values such as authentication tokens are stored outside the source code and loaded during initialization.

This minimizes the risk of credential exposure.

---

# Summary

The Configuration subsystem provides a clean separation between deployment-specific settings and application logic.

By centralizing configuration, validating values during initialization, and isolating sensitive information, Grafana-DR remains portable, maintainable, and easy to deploy across multiple environments.

The next chapter documents the deployment architecture, installation procedures, and operational setup for both the primary Grafana server and the standby disaster recovery server.


# Chapter 9 – Deployment Guide

## Overview

This chapter describes how Grafana-DR is deployed in a production-like environment.

Unlike the previous chapters, which focused on implementation details, this chapter explains how the application is installed, configured, and operated.

The deployment architecture consists of two independent Grafana instances:

* Primary Grafana Server
* Standby Disaster Recovery Server

Dashboard backups are synchronized between the two systems using Git.

This architecture enables rapid recovery without requiring direct communication between Grafana instances.

---

# 9.1 Deployment Architecture

The production deployment consists of the following components.

```text
                  Primary Site
          ┌─────────────────────────┐
          │ Debian 12               │
          │                         │
          │ Grafana                 │
          │ Prometheus              │
          │ Grafana-DR              │
          └──────────┬──────────────┘
                     │
                     │ Git Push
                     ▼
               GitHub Repository
                     ▲
                     │ Git Pull
                     │
          ┌──────────┴──────────────┐
          │ macOS (Mac mini)        │
          │                         │
          │ Grafana                 │
          │ Grafana-DR              │
          └─────────────────────────┘
```

The standby server does not receive dashboards directly from the primary server.

Instead, Git acts as the synchronization mechanism.

---

# 9.2 Primary Server

The primary environment is responsible for:

* Hosting Grafana
* Running Prometheus
* Exporting dashboards
* Creating backups
* Updating Git

Typical software stack:

| Component  | Purpose            |
| ---------- | ------------------ |
| Debian 12  | Operating System   |
| Grafana    | Dashboard Platform |
| Prometheus | Metrics Collection |
| Grafana-DR | Backup Engine      |
| Git        | Version Control    |

---

# 9.3 Standby Server

The standby environment serves as the disaster recovery target.

Responsibilities include:

* Maintaining a synchronized repository
* Restoring dashboards
* Verifying recovery procedures

Typical software stack:

| Component  | Purpose                    |
| ---------- | -------------------------- |
| macOS      | Operating System           |
| Grafana    | Recovery Target            |
| Homebrew   | Package Management         |
| Grafana-DR | Restore Engine             |
| Git        | Repository Synchronization |

---

# 9.4 Grafana Installation

Grafana must be installed independently on both systems.

The application does not manage Grafana installation.

Grafana-DR assumes that a working Grafana instance already exists.

---

# 9.5 Service Account

Grafana-DR authenticates using a Grafana Service Account Token.

Required permissions include:

* Dashboard Read
* Dashboard Write

The token is stored separately from the application source code.

Example:

```text
token/
└── grafana.token
```

The token file is loaded during application initialization.

---

# 9.6 Repository Setup

Clone the repository.

```bash
git clone https://github.com/<username>/Grafana-DR.git

cd Grafana-DR
```

The repository contains:

```text
backup-grafana.sh

restore-grafana.sh

lib/

services/

dashboards/

scripts/
```

---

# 9.7 Directory Structure

Required directories include:

```text
Grafana-DR/

dashboards/

logs/

lib/

services/

scripts/
```

The initialization process automatically creates runtime directories when necessary.

---

# 9.8 Primary Backup Workflow

The backup process is initiated by executing:

```bash
./backup-grafana.sh
```

Workflow:

```text
Initialize
     │
     ▼
Export Dashboards
     │
     ▼
Update Manifest
     │
     ▼
Git Commit
     │
     ▼
Git Push
```

The Git repository becomes the authoritative backup source.

---

# 9.9 Standby Restore Workflow

After synchronizing the latest repository:

```bash
git pull

./restore-grafana.sh
```

Workflow:

```text
Validate Manifest
        │
        ▼
Read Dashboard Files
        │
        ▼
Transform Payload
        │
        ▼
Import Dashboards
```

This recreates the dashboard configuration on the standby Grafana instance.

---

# 9.10 macOS Considerations

Grafana installed through Homebrew is managed differently from Linux services.

Grafana should be started using:

```bash
brew services start grafana
```

Service status can be verified using:

```bash
brew services list
```

This differs from Linux systems using `systemctl`.

---

# 9.11 Linux Considerations

On Debian systems, Grafana typically runs as a systemd service.

Example commands:

```bash
sudo systemctl start grafana-server

sudo systemctl status grafana-server

sudo systemctl enable grafana-server
```

Grafana-DR itself does not depend on the service manager.

Only the Grafana HTTP API must be reachable.

---

# 9.12 Datasource Requirements

Dashboard restoration assumes that required datasources already exist.

Datasource UIDs referenced by dashboard JSON must be present on the destination Grafana instance.

During development, cross-instance restoration required creating matching datasource UIDs before dashboards could be restored successfully. In order to ensure consistency between environments, a Prometheus datasource was explicitly created using the Grafana HTTP API with a predefined UID matching the source system. This was achieved using a `curl` request to the `/api/datasources` endpoint, for example:

```bash
curl -X POST \
  -H "Authorization: Bearer <SERVICE_ACCOUNT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://192.168.1.6:9090",
    "access": "proxy",
    "uid": "<source system datasource UID",
    "jsonData": {
      "httpMethod": "POST"
    }
  }' \
  http://localhost:3000/api/datasources
```

This approach ensured that the datasource UID remained identical across both Grafana instances, allowing dashboard JSON references to resolve correctly during restoration.

This requirement should be verified whenever restoring into a fresh environment.

---

# 9.13 Network Requirements

Grafana-DR communicates with Grafana exclusively through the REST API.

Required connectivity:

```text
Grafana-DR
     │
     ▼
http://localhost:3000
```

If Grafana is hosted remotely, only the configured URL must be updated.

No changes to application logic are required.

---

# 9.14 Git Synchronization

Git serves as the synchronization mechanism between environments.

Workflow:

```text
Primary Server
      │
      ▼
Git Push
      │
      ▼
GitHub
      │
      ▼
Git Pull
      │
      ▼
Standby Server
```

This design avoids direct communication between Grafana instances and allows recovery even if the primary server becomes unavailable.

---

# 9.15 Deployment Validation

After deployment, the following checks should be performed:

* Grafana reachable
* API token valid
* Repository initialized
* Backup completes successfully
* Manifest generated
* Git synchronization succeeds
* Restore succeeds on standby system

Successful completion confirms that the deployment is operational.

---

# 9.16 Operational Workflow

The complete operational lifecycle is shown below.

```text
Create Dashboard
        │
        ▼
Run Backup
        │
        ▼
Git Synchronization
        │
        ▼
Repository Updated
        │
        ▼
Standby Pull
        │
        ▼
Run Restore
        │
        ▼
Dashboard Available
```

This workflow enables continuous synchronization between production and disaster recovery environments.

---

# Deployment Best Practices

Several operational practices were established during development.

## Separate Authentication

Store Grafana API tokens outside the repository.

---

## Protect Runtime Files

Operational files such as logs should be excluded from version control.

---

## Validate Before Restoring

Always validate the manifest before beginning recovery.

---

## Test Disaster Recovery Regularly

Periodic restoration tests ensure that backups remain usable and that the standby environment remains synchronized with production.

---

# Summary

Grafana-DR is designed for straightforward deployment across independent environments.

By separating application logic from deployment-specific configuration and using Git as the synchronization layer, the toolkit provides a portable and reliable disaster recovery solution.

The deployment architecture allows dashboard backups to be created on the primary server, synchronized through Git, and restored onto a standby Grafana instance without requiring direct communication between the two systems.

---

# Next Chapter

The next chapter focuses on **Testing and Validation**, documenting the development testing strategy, component-level validation, integration testing, cross-instance recovery testing, and lessons learned while building Grafana-DR.

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


# Chapter 11 – Troubleshooting Guide

## Overview

This chapter documents common issues encountered during the development and testing of Grafana-DR, along with their causes and resolutions.

Rather than serving as a debugging log, this chapter acts as an operational reference for diagnosing and resolving problems during deployment and maintenance.

The troubleshooting procedures are organized by subsystem and include both expected runtime errors and development-time issues that may reoccur in future versions.

---

# 11.1 Initialization Issues

## Missing Dependencies

### Symptoms

Application initialization fails before any backup or restore operation begins.

Example:

```text
[ERROR] Missing dependency: jq
```

### Cause

A required external utility is not installed.

Typical dependencies include:

* curl
* jq
* Git

### Resolution

Install the missing dependency using the operating system's package manager and rerun the application.

---

## Missing API Token

### Symptoms

Initialization completes with authentication errors when attempting to communicate with Grafana.

### Cause

The configured Service Account Token file does not exist or cannot be read.

### Resolution

Verify:

* Token file exists.
* File permissions allow reading.
* Configuration points to the correct location.

---

# 11.2 Grafana Connectivity Issues

## Grafana Unreachable

### Symptoms

Health checks fail.

HTTP requests return connection errors.

### Cause

Grafana is not running or the configured URL is incorrect.

### Resolution

Verify:

* Grafana service is running.
* Correct port is configured.
* Firewall rules permit access.
* `GRAFANA_URL` is correct.

---

## HTTP 401 Unauthorized

### Symptoms

Every API request fails with an authorization error.

### Cause

Invalid or expired Service Account Token.

### Resolution

Generate a new Service Account Token and update the token file.

---

# 11.3 Dashboard Backup Issues

## Dashboard Export Failure

### Symptoms

Dashboard backup fails for a single dashboard while others continue successfully.

### Cause

Possible causes include:

* Dashboard deleted during backup
* API communication failure
* Permission issue

### Resolution

Verify the dashboard exists and the Service Account has Dashboard Read permission.

---

## Invalid JSON

### Symptoms

```text
Invalid JSON received
```

### Cause

Grafana returned malformed or incomplete data.

### Resolution

Verify Grafana API availability and inspect the API response before retrying.

---

# 11.4 Dashboard Restore Issues

## Invalid Manifest

### Symptoms

```text
Invalid manifest.
```

### Cause

`manifest.json` is missing or contains invalid JSON.

### Resolution

Run a new backup to regenerate the manifest or restore a valid copy from Git history.

---

## HTTP 400 During Import

### Symptoms

```text
curl: (22)
The requested URL returned error: 400
```

### Cause

The import payload does not conform to Grafana's expected format.

Common causes include:

* Dashboard ID not reset
* Dashboard version not reset
* Invalid payload structure

### Resolution

Ensure the Restore Service generates an import payload that:

* Sets `dashboard.id` to `null`
* Sets `dashboard.version` to `0`
* Includes `overwrite: true`

---

## Datasource UID Mismatch

### Symptoms

Dashboard imports successfully but panels display datasource errors.

### Cause

Datasource UIDs referenced by the dashboard do not exist on the destination Grafana instance.

### Resolution

Create matching datasources with identical UIDs before restoring dashboards.

---

# 11.5 Git Issues

## No Changes Detected

### Symptoms

```text
No Git changes detected.
```

### Cause

Dashboard backups are identical to the previous backup.

### Resolution

No action required.

This is expected behaviour.

---

## Unexpected Git Commits

### Symptoms

Every backup produces a new commit despite no dashboard changes.

### Cause

The manifest timestamp or another tracked runtime file changes on every execution.

### Resolution

Ensure:

* `manifest.json` is regenerated only when dashboard backups change.
* Runtime logs are excluded using `.gitignore`.

---

# 11.6 Bash Issues

## UID Readonly Variable

### Symptoms

```text
UID: readonly variable
```

### Cause

The variable name `UID` conflicts with Bash's built-in readonly variable.

### Resolution

Rename the variable to a non-reserved identifier such as:

```text
DASHBOARD_UID
```

---

## Command Not Found

### Symptoms

```text
file_safe_write: command not found
```

### Cause

The required library has not been sourced.

### Resolution

Verify that `bootstrap.sh` loads all required libraries before executing services.

---

# 11.7 Recovery Checklist

If restoration fails, verify the following:

* Grafana is reachable.
* Service Account Token is valid.
* Manifest exists.
* Manifest contains valid JSON.
* Dashboard backup files exist.
* SHA-256 checksums match.
* Datasource UIDs exist.
* Dashboard import payload resets `id` and `version`.

Performing these checks resolves the majority of operational issues.

---

# Summary

Most issues encountered during development originated from configuration mismatches, API expectations, or environment differences rather than defects in the backup workflow itself.

The modular architecture of Grafana-DR makes it possible to isolate failures quickly by identifying the subsystem responsible for each stage of execution.

---

# Next Chapter

The following chapter presents the planned evolution of Grafana-DR, documenting features that can be added in future releases without requiring significant architectural changes.


# Chapter 12 – Future Enhancements & Roadmap

## Overview

Grafana-DR was intentionally designed with a modular architecture to simplify future expansion.

Throughout development, reusable libraries, service-oriented workflows, and clear separation of responsibilities were prioritized over tightly coupled implementations.

As a result, the existing architecture can be extended to support additional Grafana resources with minimal changes to the core framework.

This chapter outlines potential future enhancements that could further improve the functionality, reliability, and usability of Grafana-DR.

---

# 12.1 Datasource Backup and Restore

## Current State

Dashboard backups are fully supported.

Datasource configuration is not currently included.

---

## Motivation

Dashboards often depend on specific datasource configurations.

Although datasource UIDs can be recreated manually, automating datasource backup would significantly simplify disaster recovery.

---

## Proposed Workflow

```text
Datasources
      │
      ▼
Grafana API
      │
      ▼
datasources/
      │
      ▼
Manifest
      │
      ▼
Git
```

---

## Benefits

* Complete environment recovery
* No manual datasource recreation
* Simplified cross-instance migration

---

# 12.2 Folder Backup

## Current State

Dashboards are restored into their recorded folders when folder metadata exists.

Folder definitions themselves are not currently backed up.

---

## Proposed Enhancement

Backup:

* Folder names
* Folder UIDs
* Folder permissions

Restoring folders before dashboards would preserve the original organizational structure.

---

# 12.3 Alert Rule Backup

Grafana Unified Alerting stores alert rules independently of dashboards.

Future versions could support:

* Alert rule export
* Alert rule restoration
* Alert folder hierarchy
* Notification policy backup

This would expand Grafana-DR from dashboard recovery to monitoring platform recovery.

---

# 12.4 Library Panel Backup

Grafana Library Panels allow reusable visualizations across multiple dashboards.

Supporting Library Panels would ensure dashboards remain fully functional after restoration.

Potential workflow:

```text
Library Panels
      │
      ▼
Export
      │
      ▼
Git
      │
      ▼
Restore
```

---

# 12.5 Scheduled Backups

Currently, backups are executed manually.

Future versions could support automated scheduling.

Examples include:

### Linux

```text
cron

systemd timers
```

### macOS

```text
launchd
```

This would allow unattended periodic backups.

---

# 12.6 Backup Compression

Dashboard repositories are generally small, but environments with hundreds of dashboards could benefit from optional compression.

Possible approaches include:

* gzip
* tar.gz

Compression would reduce repository size while remaining transparent to the restore process.

---

# 12.7 Backup Encryption

Future versions could support encrypted backup storage.

Potential features include:

* AES-encrypted archives
* GPG encryption
* Password-protected backup packages

This would improve security when storing backups in external repositories.

---

# 12.8 Multiple Organization Support

Current development focused on a single Grafana organization.

Future enhancements could allow:

* Organization discovery
* Per-organization backup
* Organization-specific manifests
* Organization filtering

This would make the project suitable for larger Grafana deployments.

---

# 12.9 Configuration Backup

Future versions could extend backup coverage to include:

* Grafana preferences
* Teams
* Users
* Permissions
* Organization settings

This would enable near-complete Grafana environment reconstruction.

---

# 12.10 Backup Verification Mode

A verification mode could validate backup integrity without performing restoration.

Example workflow:

```text
Repository
      │
      ▼
Verify Manifest
      │
      ▼
Verify SHA-256
      │
      ▼
Verify JSON
      │
      ▼
Verification Report
```

This would allow administrators to confirm repository integrity at any time.

---

# 12.11 Notification Support

Backup results could be delivered automatically through external notification systems.

Possible integrations include:

* Email
* Slack
* Microsoft Teams
* Discord
* Webhooks

Example notifications:

```text
Backup Successful

Backup Failed

Restore Completed
```

---

# 12.12 Incremental Backup Reporting

Future releases could generate execution reports summarizing changes between backup runs.

Example:

```text
Backup Report

New Dashboards : 2

Updated Dashboards : 5

Removed Dashboards : 1

Duration : 8 seconds
```

Such reports would provide administrators with a concise overview of configuration changes.

---

# 12.13 Command-Line Interface

The current project uses dedicated scripts such as:

```text
backup-grafana.sh

restore-grafana.sh
```

A unified command-line interface could provide a more flexible user experience.

Example:

```bash
grafana-dr backup

grafana-dr restore

grafana-dr verify

grafana-dr version
```

This would simplify usage while maintaining compatibility with the existing architecture.

---

# 12.14 Testing Framework

Current testing relies on dedicated Bash scripts.

Future versions could introduce:

* Automated regression testing
* Continuous Integration (CI)
* GitHub Actions workflows
* Static analysis using ShellCheck

This would improve long-term maintainability and ensure new features do not introduce regressions.

---

# 12.15 Roadmap Summary

The current architecture was intentionally designed so that additional resource types can reuse the existing framework.

For example:

```text
New Resource
      │
      ▼
API Library
      │
      ▼
File Utility Library
      │
      ▼
Manifest Library
      │
      ▼
Git Library
```

Only a resource-specific library and service would need to be added.

This demonstrates the scalability of the existing design.

---

# Design Philosophy

Future development should continue to follow the principles established during the initial implementation.

* Reuse existing libraries wherever possible.
* Keep services focused on orchestration.
* Preserve immutable backup artifacts.
* Validate before modifying data.
* Keep Git as the authoritative backup repository.
* Maintain clear separation between implementation and configuration.

Following these principles will ensure that future enhancements remain consistent with the current architecture.

---

# Summary

Although Grafana-DR currently focuses on dashboard disaster recovery, its modular architecture provides a solid foundation for supporting additional Grafana resources and operational features.

Future enhancements can be implemented incrementally while preserving the existing design, allowing the project to evolve from a dashboard backup utility into a comprehensive Grafana disaster recovery platform.

---

# Next Chapter

The final chapter reflects on the development process, summarising the key architectural decisions, technical challenges, and lessons learned while building Grafana-DR from concept to a fully functional disaster recovery solution.


# Chapter 13 – Lessons Learned & Conclusion

## Overview

Developing Grafana-DR was more than an exercise in automating dashboard backups.

The project evolved into an exploration of software architecture, reliability, automation, and disaster recovery design.

Several implementation decisions that initially appeared straightforward became significantly more complex as real-world scenarios were introduced.

Many of the final architectural choices were the result of problems encountered during implementation and extensive testing rather than assumptions made during initial design.

This chapter summarises the most important technical lessons learned throughout the development of the project.

---

# 13.1 Design for Reliability Rather Than Success

One of the earliest lessons learned was that a backup tool cannot assume success.

Network interruptions, filesystem errors, malformed responses, and configuration issues are inevitable.

Instead of assuming every operation succeeds, Grafana-DR validates every critical step before proceeding.

Examples include:

* Dependency validation
* Grafana health checks
* JSON validation
* Atomic file replacement
* Manifest validation
* SHA-256 verification

The result is a system that prioritizes reliability over execution speed.

---

# 13.2 Modular Architecture Simplifies Growth

Initially, it would have been possible to implement the entire project as a single Bash script.

However, separating responsibilities into libraries and services proved invaluable.

The final architecture allows each component to focus on a single responsibility.

Examples include:

* API communication
* Dashboard operations
* Filesystem operations
* Manifest management
* Git synchronization

This separation reduced code duplication and simplified debugging throughout development.

---

# 13.3 Preserve Backup Artifacts

An important design decision was to preserve exported dashboards exactly as Grafana produced them.

Although it would have been possible to modify dashboard JSON during backup, doing so would permanently alter the original export.

Instead, all modifications required for restoration are performed only during the restore process.

As a result:

* Backups remain immutable.
* Original Grafana exports are preserved.
* Future import strategies remain possible without regenerating backups.

---

# 13.4 Cross-Instance Testing Reveals Real Problems

Testing backup and restore operations on the same Grafana instance created the illusion that everything worked correctly.

Only after restoring dashboards into a completely separate Grafana installation were several important issues discovered.

These included:

* Internal dashboard identifiers
* Dashboard version handling
* Datasource UID consistency

This demonstrated that disaster recovery testing should always be performed in an independent environment rather than the original system.

---

# 13.5 API Documentation Is Not Always Sufficient

The Grafana HTTP API documentation describes the available endpoints but does not always highlight practical behaviours encountered during real-world usage.

Several implementation details were discovered experimentally, including:

* Export and import payload differences.
* Dashboard ID restrictions.
* Dashboard version requirements.
* Datasource UID dependencies.

Practical testing proved just as valuable as official documentation.

---

# 13.6 Version Control as a Backup Platform

Rather than treating Git as a convenient storage location, Grafana-DR uses Git as the authoritative history of dashboard configurations.

This approach provides several advantages:

* Version history
* Change tracking
* Rollback capability
* Remote replication
* Auditability

Using Git eliminated the need for a custom backup database while providing mature version control functionality.

---

# 13.7 Small Improvements Have Large Effects

Several seemingly minor implementation details significantly improved the overall quality of the project.

Examples include:

* Avoiding Bash reserved variable names such as `UID`.
* Using temporary files before replacement.
* Comparing files before overwriting.
* Ignoring runtime logs in Git.
* Preventing unnecessary manifest updates.

Although individually small, together these improvements made the project more reliable and maintainable.

---

# 13.8 Automation Requires Validation

Automating a manual process is only valuable if the automated process is trustworthy.

Throughout development, every automated operation was paired with validation.

Examples include:

* Validate before writing.
* Verify before restoring.
* Check connectivity before execution.
* Confirm integrity before import.

Automation without validation simply automates failure.

---

# 13.9 Design for Future Expansion

From the beginning, the architecture was designed to support more than dashboard backups.

By separating reusable libraries from workflow orchestration, the project can be extended to support additional Grafana resources with minimal structural changes.

Potential future additions include:

* Datasources
* Alert rules
* Folders
* Library panels
* Organization settings

The existing architecture already provides the framework needed for these enhancements.

---

# 13.10 Bash Remains a Viable Engineering Tool

One objective of this project was to demonstrate that Bash can support more than small automation scripts.

By applying software engineering principles such as:

* Modularization
* Separation of concerns
* Error handling
* Reusable libraries
* Consistent interfaces

the resulting codebase became structured, maintainable, and scalable despite being implemented entirely in Bash.

The project demonstrates that language choice is less important than architectural discipline.

---

# 13.11 Project Outcomes

The completed Grafana-DR toolkit provides:

* Reliable dashboard backup
* Cross-instance restoration
* Manifest-driven recovery
* Git-based version control
* Backup integrity verification
* Modular architecture
* Portable deployment
* Comprehensive documentation

The project successfully achieved its original objective of creating a practical disaster recovery solution for Grafana dashboards while remaining extensible for future development.

---

# 13.12 Final Architecture

The completed architecture is illustrated below.

```text id="zwxk3g"
                    Grafana
                       │
                       ▼
               Dashboard Library
                       │
                       ▼
                 API Library
                       │
                       ▼
                Backup Service
                       │
                       ▼
              File Utility Library
                       │
                       ▼
               Manifest Library
                       │
                       ▼
                  Git Library
                       │
                       ▼
                Git Repository
                       ▲
                       │
                Restore Service
                       │
                       ▼
             Dashboard Import API
                       │
                       ▼
                 Standby Grafana
```

Each layer has a clearly defined responsibility and interacts only through well-defined interfaces.

---

# 13.13 Final Thoughts

Grafana-DR began as a simple idea: create a reliable backup for Grafana dashboards.

As development progressed, the project expanded into a complete disaster recovery framework featuring modular architecture, automated validation, version-controlled backups, and cross-instance restoration.

More importantly, the project reinforced several fundamental software engineering principles:

* Design for maintainability.
* Validate before trusting external data.
* Separate responsibilities clearly.
* Automate repetitive operations.
* Test against real-world scenarios.
* Build systems that fail safely.

These principles are applicable far beyond Grafana and will continue to influence future infrastructure automation projects.

---

# Conclusion

Grafana-DR demonstrates that reliable infrastructure automation is achieved not through complexity, but through thoughtful design, careful validation, and disciplined engineering practices.

The resulting toolkit provides a dependable mechanism for protecting Grafana dashboard configurations while serving as a foundation for future enhancements and a practical example of modular Bash application development.

---

# End of Documentation

This document has covered the complete design, implementation, deployment, testing, and operation of Grafana-DR.

It is intended to serve both as a technical reference for future maintenance and as a record of the architectural decisions made throughout the project's development.

Future contributors should be able to understand not only *how* the project works, but also *why* it was designed the way it is.



