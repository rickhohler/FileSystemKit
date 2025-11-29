#!/bin/bash

# Install FileSystemKit Git Hooks
# This script copies the hooks from scripts/hooks to .git/hooks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"
SOURCE_HOOKS="$SCRIPT_DIR/hooks"

if [ ! -d "$REPO_ROOT/.git" ]; then
    echo "Error: Not a git repository"
    exit 1
fi

mkdir -p "$HOOKS_DIR"

echo "Installing git hooks..."

# Install pre-commit hook
if [ -f "$SOURCE_HOOKS/pre-commit" ]; then
    cp "$SOURCE_HOOKS/pre-commit" "$HOOKS_DIR/pre-commit"
    chmod +x "$HOOKS_DIR/pre-commit"
    echo "✓ Installed pre-commit hook"
else
    echo "✗ pre-commit hook not found"
fi

# Install commit-msg hook
if [ -f "$SOURCE_HOOKS/commit-msg" ]; then
    cp "$SOURCE_HOOKS/commit-msg" "$HOOKS_DIR/commit-msg"
    chmod +x "$HOOKS_DIR/commit-msg"
    echo "✓ Installed commit-msg hook"
else
    echo "✗ commit-msg hook not found"
fi

echo ""
echo "Git hooks installed successfully!"
echo ""
echo "The hooks will:"
echo "  - Check for CHANGELOG.md updates (pre-commit)"
echo "  - Remind about CHANGELOG and push (commit-msg)"

