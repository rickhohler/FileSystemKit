#!/bin/bash
# Generate DocC documentation for FileSystemKit

set -e

echo "Generating FileSystemKit documentation..."

# Generate documentation to Documentation/ directory (not docs/ which is for design docs)
swift package generate-documentation \
    --target FileSystemKit \
    --output-path ./Documentation

echo "Documentation generated in ./Documentation"
echo "Open Documentation/index.html in a browser to view"

