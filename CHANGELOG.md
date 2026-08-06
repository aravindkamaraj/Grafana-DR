# Changelog

All notable changes to this project will be documented in this file.

---

[1.1.0] - 2026-08-07

### Added

* Cross-instance Grafana dashboard restoration
* Production entry-point scripts:

  * `backup-grafana.sh`
  * `restore-grafana.sh`
* Git synchronization library
* Manifest generation and validation
* Atomic file writing
* Dashboard integrity verification using SHA-256

### Changed

* Dashboard import payload is automatically transformed before restore.
* Dashboard `id` is reset to `null` during restore.
* Dashboard `version` is reset before importing into a different Grafana instance.
* Backup workflow now regenerates `manifest.json` only when dashboards change.
* Git synchronization skips commits when no changes are detected.

### Fixed

* Cross-instance dashboard import compatibility with Grafana 13.
* Eliminated unnecessary Git commits caused by unchanged backups.

---

## [1.0.0] - 2026-08-06

### Initial Release

### Added

* Dashboard backup through Grafana HTTP API
* Dashboard restore
* Dashboard export library
* Generic HTTP API library
* Bootstrap initialization
* File utility library
* Backup service
* Restore service
* Manifest support
* Git integration
* JSON validation
* Logging framework
* Modular Bash architecture
