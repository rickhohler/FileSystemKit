# GitHub Actions Monitoring Guide

This guide provides commands and scripts for monitoring GitHub Actions workflows using the GitHub CLI (`gh`).

## Quick Commands

### List Recent Runs
```bash
gh run list --limit 10
```

### View Specific Run
```bash
gh run view <run-id>
```

### Watch a Run (Live Updates)
```bash
gh run watch <run-id>
```

### View Run Logs
```bash
gh run view <run-id> --log
gh run view <run-id> --log-failed  # Failed steps only
```

### View Run as JSON
```bash
gh run view <run-id> --json conclusion,status,databaseId,workflowName,headBranch,createdAt,updatedAt,url
```

### List Workflows
```bash
gh workflow list
```

### View Workflow File
```bash
gh workflow view tests.yml
```

### Download Artifacts
```bash
gh run download <run-id>
```

### Rerun Failed Workflow
```bash
gh run rerun <run-id>
```

## Monitoring Scripts

### monitor-actions.sh
Monitors the latest workflow run with live updates:
```bash
./monitor-actions.sh
```

### watch-new-runs.sh
Watches for new workflow runs and automatically monitors them:
```bash
./watch-new-runs.sh
```

## Current Status

Latest successful runs:
- **Run #24** (19793239517): ✅ Success - "ci: Update GitHub Actions runner to macos-latest"
- **Run #23** (19793223141): ✅ Success - "fix: Remove redundant originalFilename insertion in metadata merging"

## Workflow Information

- **Workflow Name**: Unit Tests
- **Workflow ID**: 211308016
- **File**: `.github/workflows/tests.yml`
- **Triggers**: Push to main/develop, Pull requests, Manual dispatch

## Example: Monitor Latest Run

```bash
# Get latest run ID
LATEST_RUN=$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')

# View details
gh run view $LATEST_RUN

# Watch it live
gh run watch $LATEST_RUN
```

## Example: Check for Failures

```bash
# List only failed runs
gh run list --limit 10 --json databaseId,status,conclusion,displayTitle --jq '.[] | select(.conclusion == "failure") | "\(.databaseId) | \(.displayTitle)"'
```

## Example: Get Run Summary

```bash
gh run list --limit 5 --json databaseId,status,conclusion,name,headBranch,createdAt --jq '.[] | "\(.databaseId) | \(.status) | \(.conclusion // "in_progress") | \(.name) | \(.headBranch) | \(.createdAt)"'
```

