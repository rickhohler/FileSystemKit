#!/bin/bash
# Monitor GitHub Actions workflow runs

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

echo "=== GitHub Actions Workflow Monitor ==="
echo "Repository: $(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo ""

# Get latest run
LATEST_RUN=$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')

if [ -z "$LATEST_RUN" ]; then
    echo "No workflow runs found."
    exit 1
fi

echo "Latest run ID: $LATEST_RUN"
echo ""

# Show latest runs
echo "=== Recent Workflow Runs ==="
gh run list --limit 5

echo ""
echo "=== Latest Run Details ==="
gh run view "$LATEST_RUN"

echo ""
echo "=== Monitoring Latest Run (Press Ctrl+C to stop) ==="
gh run watch "$LATEST_RUN" --interval 3
