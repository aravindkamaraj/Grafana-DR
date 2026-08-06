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