Grafana-DR

A lightweight Disaster Recovery (DR) toolkit for Grafana dashboards written entirely in Bash.

Grafana-DR automates the backup, version control, and restoration of Grafana dashboards using the Grafana HTTP API and Git. It is designed for home labs, production environments, and disaster recovery scenarios where a standby Grafana instance must be restored quickly with minimal manual intervention.

---

Features

* Backup all Grafana dashboards through the Grafana HTTP API
* Restore dashboards to another Grafana instance
* Cross-instance dashboard restoration
* Automatic dashboard filename generation
* Dashboard integrity verification using SHA-256 checksums
* Manifest generation and validation
* Atomic file writes
* Git integration for version-controlled backups
* Automatic detection of unchanged dashboards
* Modular Bash architecture
* Designed for Disaster Recovery and GitOps workflows

---

Architecture

```
                    Primary Grafana
                  (Production Server)
                          │
                          │
                Grafana HTTP API
                          │
                          ▼
                  Backup Service
                          │
        ┌─────────────────┴─────────────────┐
        │                                   │
 Dashboard JSON Files                 manifest.json
        │                                   │
        └─────────────────┬─────────────────┘
                          │
                          ▼
                     Git Repository
                          │
                          ▼
                        GitHub
                          │
                          ▼
                Standby Grafana Server
                     (Mac mini)
                          │
                          ▼
                  Restore Service
                          │
                          ▼
               Grafana HTTP Import API
```

---

Project Structure

```
Grafana-DR/
│
├── backup-grafana.sh
├── restore-grafana.sh
├── VERSION
├── README.md
│
├── dashboards/
│   ├── *.json
│   └── manifest.json
│
├── lib/
│   ├── api.sh
│   ├── bootstrap.sh
│   ├── common.sh
│   ├── config.sh
│   ├── dashboard.sh
│   ├── file_utils.sh
│   ├── git.sh
│   └── manifest.sh
│
├── services/
│   ├── backup_service.sh
│   └── restore_service.sh
│
├── logs/
│
└── scripts/
    ├── test-backup.sh
    ├── test-dashboard.sh
    ├── test-git.sh
    ├── test-import.sh
    └── test-restore.sh
```

---

Requirements

* Bash 5+
* curl
* jq
* Git
* Grafana 13+
* Grafana Service Account Token

---

Configuration

Configure the following values inside `lib/config.sh`.

* Grafana URL
* API Token location
* Backup directory
* Log directory
* Manifest location
* API timeout
* Retry count

Store the Grafana Service Account Token separately and never commit it into Git.

---

How It Works

Backup Workflow

```
Initialize
      │
      ▼
Verify Dependencies
      │
      ▼
Connect to Grafana
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
Detect Changes
      │
      ▼
Save Dashboard
      │
      ▼
Generate Manifest
      │
      ▼
Git Commit & Push
```

---

Restore Workflow

```
Initialize
      │
      ▼
Read Manifest
      │
      ▼
Validate Checksums
      │
      ▼
Transform Export JSON
      │
      ▼
Prepare Import Payload
      │
      ▼
Restore Dashboard
      │
      ▼
Verify Success
```

---

Cross-Instance Restore

Grafana exports and imports use different JSON formats.

During restoration Grafana-DR automatically converts exported dashboards into the format required by the Grafana Import API.

The restore process automatically:

* Converts exported dashboard JSON into import payloads
* Sets dashboard ID to `null`
* Resets dashboard version
* Preserves folder information
* Enables overwrite mode

This allows dashboards to be restored into a different Grafana installation.

---

Git Integration

Grafana-DR automatically integrates with Git.

If no dashboard changes are detected:

```
No dashboard changes
        │
        ▼
No manifest update
        │
        ▼
No Git commit
```

If dashboards change:

```
Dashboard Updated
        │
        ▼
Manifest Updated
        │
        ▼
Git Add
        │
        ▼
Git Commit
        │
        ▼
Git Push
```

Only meaningful configuration changes are committed.

---

Disaster Recovery Workflow

Primary Server

* Grafana runs normally.
* Scheduled backups execute automatically.
* Dashboard backups are committed to Git.

Standby Server

Grafana remains stopped to conserve system resources.

During a disaster:

```
Git Pull
      │
      ▼
Start Grafana
      │
      ▼
Restore Dashboards
      │
      ▼
Production Ready
```

---

Usage

Backup Dashboards

./backup-grafana.sh

Restore Dashboards

./restore-grafana.sh

---

Design Goals

* Minimal resource usage
* Modular architecture
* Easy maintenance
* Production-ready scripting practices
* GitOps-friendly workflow
* Disaster Recovery automation
* Cross-platform compatibility

---

Technologies Used

* Bash
* Grafana HTTP API
* jq
* curl
* Git
* SHA-256
* JSON

---
Future Enhancements

* Dashboard folder synchronization
* Datasource backup and restore
* Alert rule backup
* Grafana organization support
* Plugin backup
* Scheduled systemd timer installation
* Automated DR activation
* Configuration backup
* GitHub Actions integration

---

Version

Current Release: **v1.1.0**

---

License

This project is released under the MIT License.
