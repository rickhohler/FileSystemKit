# Security Policy

## Supported Versions

We release patches for security vulnerabilities. Which versions are eligible for receiving such patches depends on the CVSS v3.0 Rating:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

Please report (suspected) security vulnerabilities by opening a [GitHub Security Advisory](https://github.com/rickhohler/FileSystemKit/security/advisories/new) or by emailing the maintainers privately. You will receive a response within 48 hours. If the issue is confirmed, we will release a patch as soon as possible depending on complexity but historically within a few days.

**Please do not report security vulnerabilities through public GitHub issues.**

## Security Best Practices

When using FileSystemKit:

1. **Validate Input**: Always validate disk image files before processing
2. **Sandboxing**: Use appropriate sandboxing when processing untrusted disk images
3. **Resource Limits**: Set appropriate limits on file sizes and processing time
4. **Error Handling**: Implement proper error handling for all file system operations
5. **Permissions**: Follow the principle of least privilege when accessing file systems

## Known Security Considerations

- **Path Traversal**: FileSystemKit validates paths, but consumers should also validate user-provided paths
- **Resource Exhaustion**: Large disk images may consume significant memory; implement appropriate limits
- **Malformed Images**: Malformed disk images may cause unexpected behavior; always validate format before processing

## Disclosure Policy

When we receive a security bug report, we will:

1. Confirm the problem and determine affected versions
2. Audit code to find any potential similar problems
3. Prepare fixes for all releases still under support
4. Publish a security advisory once patches are available

