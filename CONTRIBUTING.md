# Contributing to FileSystemKit

Thank you for your interest in contributing to FileSystemKit! This document provides guidelines and information for contributors.

## Code of Conduct

This project adheres to a Code of Conduct that all contributors are expected to follow. Please be respectful and constructive in all interactions.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/FileSystemKit.git`
3. Create a branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Run tests: `swift test`
6. Ensure code builds: `swift build`
7. Commit your changes: `git commit -m "Add feature: description"`
8. Push to your fork: `git push origin feature/your-feature-name`
9. Create a Pull Request

## Development Setup

### Requirements

- Swift 6.0+
- Xcode 15.0+ (for macOS development)
- macOS 12.0+ (for building)

### Building

```bash
swift build
```

### Running Tests

```bash
swift test
```

### Running Tests with Coverage

```bash
swift test --enable-code-coverage
```

## Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Keep functions focused and single-purpose
- Use `async/await` for asynchronous operations
- Prefer value types (structs) over reference types (classes) when possible

## Testing Guidelines

- Write unit tests for all new functionality
- Aim for at least 80% code coverage
- Use descriptive test names: `testFunctionName_WhenCondition_ShouldReturnExpectedResult`
- Use mock implementations (`MockChunkStorage`, `MockMetadataStorage`) for testing
- Test both success and error cases

## Pull Request Process

1. Ensure all tests pass
2. Update CHANGELOG.md with your changes
3. Update documentation if needed
4. Ensure code coverage doesn't decrease
5. Request review from maintainers

## Adding New Features

### Adding a New Compression Adapter

1. Create a new file in `Sources/FileSystemKit/Compression/`
2. Implement the `CompressionAdapter` protocol
3. Register the adapter in `CompressionAdapterRegistry`
4. Add tests in `Tests/FileSystemKitTests/CompressionAdapterTests.swift`

### Adding a New Disk Image Adapter

1. Create a new file in `Sources/FileSystemKit/Adapters/`
2. Implement the `DiskImageAdapter` protocol
3. Register the adapter in `DiskImageAdapterRegistry`
4. Add tests

### Adding a New File System Strategy

1. Create a new file in `Sources/FileSystemKit/FileSystems/`
2. Implement the `FileSystemStrategy` protocol
3. Register the strategy in `FileSystemStrategyFactory`
4. Add tests

## Reporting Issues

When reporting issues, please include:

- Swift version
- Platform (macOS/iOS/tvOS/watchOS) and version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Relevant code snippets or error messages

## Questions?

Feel free to open an issue for questions or discussions about the project.

