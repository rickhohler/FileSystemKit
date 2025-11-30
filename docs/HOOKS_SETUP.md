# Git Hooks Setup Guide

## Quick Installation

### For FileSystemKit

```bash
cd FileSystemKit
./scripts/install-hooks.sh
```

### For RetroboxFS

```bash
cd RetroboxFS
./scripts/install-hooks.sh
```

## What the Hooks Do

### Pre-commit Hook
- **Checks**: Verifies that `CHANGELOG.md` is included when committing source/documentation changes
- **Warning**: If you have `.swift` or `.md` file changes but `CHANGELOG.md` is not staged, you'll get a warning
- **Bypass**: Use `git commit --no-verify` if needed (not recommended)

### Commit-msg Hook
- **Reminders**: 
  - Reminds to update `CHANGELOG.md` if not mentioned in commit message
  - Reminds to push changes after committing

## Manual Installation

If the install script doesn't work, you can install hooks manually:

```bash
# Copy hooks to .git/hooks/
cp scripts/hooks/pre-commit .git/hooks/pre-commit
cp scripts/hooks/commit-msg .git/hooks/commit-msg

# Make them executable
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/commit-msg
```

## Verifying Installation

Check if hooks are installed:

```bash
ls -la .git/hooks/pre-commit .git/hooks/commit-msg
```

You should see both files listed and they should be executable (have `x` in permissions).

## Using the Hooks

### Standard Workflow

1. **Make your changes**
   ```bash
   # Edit files, add features, fix bugs, etc.
   ```

2. **Update CHANGELOG.md**
   ```bash
   # Edit CHANGELOG.md and add entry under [Unreleased] section
   ```

3. **Stage changes**
   ```bash
   git add .
   # or
   git add CHANGELOG.md
   git add Sources/...
   ```

4. **Commit** (hooks will run automatically)
   ```bash
   git commit
   # Opens editor with .gitmessage template
   # Pre-commit hook checks for CHANGELOG.md
   # Commit-msg hook shows reminders
   ```

5. **Push**
   ```bash
   git push origin main
   ```

### Example Session

```bash
# 1. Make changes
vim Sources/FileSystemKit/Adapters/NewAdapter.swift

# 2. Update CHANGELOG.md
vim CHANGELOG.md
# Add: "- **New Adapter**: Added support for XYZ format"

# 3. Stage changes
git add CHANGELOG.md Sources/FileSystemKit/Adapters/NewAdapter.swift

# 4. Commit
git commit
# Pre-commit hook: ✓ CHANGELOG.md is included in this commit
# Commit-msg hook: 💡 REMINDER: After committing, run: git push origin main
# Editor opens with template, fill in:
# feat(adapters): Add XYZ format adapter
#
# Added support for XYZ disk image format with detection and reading.
#
# Closes #123

# 5. Push
git push origin main
```

## Bypassing Hooks

If you need to bypass hooks (emergency fixes, etc.):

```bash
git commit --no-verify -m "Emergency fix"
```

**Note**: Only bypass hooks when absolutely necessary. The hooks help maintain code quality and documentation.

## Troubleshooting

### Hook not running?

1. Check if hooks are installed:
   ```bash
   ls -la .git/hooks/pre-commit .git/hooks/commit-msg
   ```

2. Check if hooks are executable:
   ```bash
   chmod +x .git/hooks/pre-commit .git/hooks/commit-msg
   ```

3. Reinstall hooks:
   ```bash
   ./scripts/install-hooks.sh
   ```

### Hook preventing commit?

If the pre-commit hook is preventing your commit:

1. **Best option**: Update CHANGELOG.md and stage it
   ```bash
   # Edit CHANGELOG.md
   git add CHANGELOG.md
   git commit
   ```

2. **Skip check** (not recommended):
   ```bash
   git commit --no-verify -m "message"
   ```

### Commit template not showing?

Check git config:
```bash
git config --get commit.template
```

Should show: `.gitmessage`

If not, set it:
```bash
git config commit.template .gitmessage
```

## Uninstalling Hooks

To remove hooks:

```bash
rm .git/hooks/pre-commit
rm .git/hooks/commit-msg
```

To remove commit template:

```bash
git config --unset commit.template
```

