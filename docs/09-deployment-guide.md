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