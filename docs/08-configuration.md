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