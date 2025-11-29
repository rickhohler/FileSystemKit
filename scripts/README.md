# FileSystemKit Scripts

## Git Hooks

Git hooks help enforce commit workflow standards.

### Installation

Run the install script:

```bash
./scripts/install-hooks.sh
```

Or manually copy hooks:

```bash
cp scripts/hooks/pre-commit .git/hooks/pre-commit
cp scripts/hooks/commit-msg .git/hooks/commit-msg
chmod +x .git/hooks/pre-commit .git/hooks/commit-msg
```

### Hooks

- **pre-commit**: Checks if CHANGELOG.md is updated when committing source/documentation changes
- **commit-msg**: Reminds about CHANGELOG updates and pushing changes

### Commit Workflow

1. Make your changes
2. Update CHANGELOG.md (under `[Unreleased]` section)
3. Stage changes: `git add .`
4. Commit: `git commit` (uses `.gitmessage` template)
5. Push: `git push origin main`

### Commit Message Template

Git is configured to use `.gitmessage` as the commit template. When you run `git commit` without `-m`, it will open your editor with the template.

### Bypassing Hooks

If you need to bypass hooks (not recommended):

```bash
git commit --no-verify -m "message"
```

