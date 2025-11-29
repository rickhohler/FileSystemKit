# FileSystemKit Commit Workflow

## Standard Commit Process

1. **Make your changes**
2. **Update CHANGELOG.md** - Add entry under `[Unreleased]` section
3. **Stage changes**: `git add .`
4. **Commit**: `git commit` (will use template)
5. **Push**: `git push origin main`

## Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Example

```
feat(adapters): Add support for new disk image format

Added DiskImageAdapter implementation for XYZ format.
Includes format detection, reading, and metadata extraction.

Closes #123
```

## Quick Commit Template

```bash
# Update CHANGELOG.md first!
git add .
git commit -m "feat(scope): Description

Detailed explanation of changes.

Closes #issue"
git push origin main
```

## Reminders

- ✅ Update CHANGELOG.md before committing
- ✅ Use conventional commit format
- ✅ Push after committing
- ✅ Reference issues in commit message

