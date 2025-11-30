#!/bin/bash
# Watch for new GitHub Actions workflow runs

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

echo "=== Watching for new GitHub Actions runs ==="
echo "Press Ctrl+C to stop"
echo ""

LAST_RUN=""

while true; do
    CURRENT_RUN=$(gh run list --limit 1 --json databaseId,status -q '.[0].databaseId')
    
    if [ -z "$CURRENT_RUN" ]; then
        echo "No workflow runs found. Waiting..."
        sleep 5
        continue
    fi
    
    if [ "$CURRENT_RUN" != "$LAST_RUN" ]; then
        echo ""
        echo "=== New workflow run detected: $CURRENT_RUN ==="
        gh run view "$CURRENT_RUN"
        echo ""
        echo "Watching run $CURRENT_RUN..."
        gh run watch "$CURRENT_RUN" --interval 3 --exit-status || true
        LAST_RUN="$CURRENT_RUN"
        echo ""
        echo "Waiting for next run..."
    else
        STATUS=$(gh run list --limit 1 --json status -q '.[0].status')
        if [ "$STATUS" = "completed" ] || [ "$STATUS" = "failure" ]; then
            echo -n "."
            sleep 10
        else
            echo -n "."
            sleep 3
        fi
    fi
done
