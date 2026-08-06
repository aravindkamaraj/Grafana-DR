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