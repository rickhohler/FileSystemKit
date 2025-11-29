# Contributing to FileSystemKit

Thank you for your interest in FileSystemKit!

## Contribution Policy

**FileSystemKit is currently maintained internally and does not accept external code contributions or pull requests.**

However, we greatly value and welcome your feedback in the following ways:

### What We Welcome

- **Bug Reports** - Help us identify and fix issues
- **Feature Requests** - Share your ideas for improvements
- **Documentation Feedback** - Report documentation issues or suggest improvements
- **Questions** - Ask questions about usage or implementation
- **Discussions** - Share your experiences and use cases

### What We Don't Accept

- **Pull Requests** - Code changes are managed internally
- **Code Contributions** - Development is done by the maintainer team
- **Direct Code Patches** - Please report issues instead

## How to Contribute Feedback

All feedback should be submitted via [GitHub Issues](https://github.com/rickhohler/FileSystemKit/issues):

1. **Bug Reports**: Use the [bug report template](https://github.com/rickhohler/FileSystemKit/issues/new?template=bug_report.md)
2. **Feature Requests**: Use the [feature request template](https://github.com/rickhohler/FileSystemKit/issues/new?template=feature_request.md)
3. **Questions**: Use the [question template](https://github.com/rickhohler/FileSystemKit/issues/new?template=question.md)

## Code of Conduct

This project adheres to a Code of Conduct. Please be respectful and constructive in all interactions.

## For Maintainers

The following sections are for internal maintainers only.

### Development Setup

#### Requirements

- Swift 6.0+
- Xcode 15.0+ (for macOS development)
- macOS 12.0+ (for building)

#### Building

```bash
swift build
```

#### Running Tests

```bash
swift test
```

#### Running Tests with Coverage

```bash
swift test --enable-code-coverage
```

### Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Keep functions focused and single-purpose
- Use `async/await` for asynchronous operations
- Prefer value types (structs) over reference types (classes) when possible

### Testing Guidelines

- Write unit tests for all new functionality
- Aim for at least 80% code coverage
- Use descriptive test names: `testFunctionName_WhenCondition_ShouldReturnExpectedResult`
- Use mock implementations (`MockChunkStorage`, `MockMetadataStorage`) for testing
- Test both success and error cases

### Adding New Features

#### Adding a New Compression Adapter

1. Create a new file in `Sources/FileSystemKit/Compression/`
2. Implement the `CompressionAdapter` protocol
3. Register the adapter in `CompressionAdapterRegistry`
4. Add tests in `Tests/FileSystemKitTests/CompressionAdapterTests.swift`

#### Adding a New Disk Image Adapter

1. Create a new file in `Sources/FileSystemKit/Adapters/`
2. Implement the `DiskImageAdapter` protocol
3. Register the adapter in `DiskImageAdapterRegistry`
4. Add tests

#### Adding a New File System Strategy

1. Create a new file in `Sources/FileSystemKit/FileSystems/`
2. Implement the `FileSystemStrategy` protocol
3. Register the strategy in `FileSystemStrategyFactory`
4. Add tests

## Issue Tracking

**All issues are tracked using GitHub Issues.** This includes:
- Bug reports
- Feature requests
- Questions and discussions
- Documentation improvements
- Performance issues

### Reporting Issues

All issues should be reported via [GitHub Issues](https://github.com/rickhohler/FileSystemKit/issues). Please use the appropriate issue template:
- **Bug Report**: Use the bug report template for bugs and unexpected behavior
- **Feature Request**: Use the feature request template for new features or enhancements

When reporting issues, please include:

- Swift version
- Platform (macOS/iOS/tvOS/watchOS) and version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Relevant code snippets or error messages

**Before creating a new issue**, please:
1. Search existing issues to see if your issue has already been reported
2. Check if your issue has been resolved in a recent release
3. Use the appropriate issue template
4. Provide as much detail as possible

## Release Process

Releases are managed internally by maintainers:
- Releases follow semantic versioning
- Release notes are generated from CHANGELOG.md
- New features and bug fixes are included based on issue tracking and internal development priorities

## Questions?

All questions and discussions should be tracked via **GitHub Issues**:
- Open a new issue with the "question" label for questions
- Search existing issues first to see if your question has been answered
- For general discussions, you can also use GitHub Discussions

**Note**: All project-related issues, bugs, features, and questions are tracked in [GitHub Issues](https://github.com/rickhohler/FileSystemKit/issues).

