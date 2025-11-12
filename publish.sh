#!/bin/bash

# Serve Haxelib Publishing Script
# This script creates a clean zip file and submits it to haxelib

set -e  # Exit on any error

echo "🚀 Publishing Serve HTTP Server to Haxelib..."

# Get version from haxelib.json
VERSION=$(grep '"version":' haxelib.json | sed 's/.*"version": *"\([^"]*\)".*/\1/')
echo "📦 Version: $VERSION"

# Create temporary directory for clean packaging
TEMP_DIR="serve-$VERSION"
ZIP_FILE="serve-$VERSION.zip"

echo "🧹 Cleaning up any existing build artifacts..."
rm -rf "$TEMP_DIR" "$ZIP_FILE"

echo "📋 Creating package directory..."
mkdir -p "$TEMP_DIR"

echo "📂 Copying files to package..."
# Copy only the files we want to include
cp haxelib.json "$TEMP_DIR/"
echo "   ✓ haxelib.json"

# Copy README if it exists
if [ -f "README.md" ]; then
    cp README.md "$TEMP_DIR/"
    echo "   ✓ README.md"
fi

# Copy LICENSE if it exists
if [ -f "LICENSE" ]; then
    cp LICENSE "$TEMP_DIR/"
    echo "   ✓ LICENSE"
fi

# Copy all .hxml files
for hxml in *.hxml; do
    if [ -f "$hxml" ]; then
        cp "$hxml" "$TEMP_DIR/"
        echo "   ✓ $hxml"
    fi
done

# Copy src source directory (main library source)
if [ -d "src" ]; then
    cp -r src "$TEMP_DIR/"
    echo "   ✓ src/"
else
    echo "❌ Error: src/ directory not found!"
    exit 1
fi

# Copy test directory (optional, but useful for examples)
if [ -d "test" ]; then
    cp -r test "$TEMP_DIR/"
    echo "   ✓ test/"
fi

echo "📦 Creating zip file..."
# Create zip from inside temp directory so files are at root level
cd "$TEMP_DIR"
zip -r "../$ZIP_FILE" *
cd ..

echo "🗑️  Cleaning up temporary directory..."
rm -rf "$TEMP_DIR"

echo "📦 Package contents:"
unzip -l "$ZIP_FILE"

echo ""
echo "✅ Package created: $ZIP_FILE"
echo ""
echo "🚀 Submitting to haxelib..."

# Submit to haxelib
haxelib submit "$ZIP_FILE"

echo ""
echo "🎉 Successfully published Serve v$VERSION to haxelib!"
echo "📋 To install: haxelib install serve"
echo "📋 To use from git: haxelib git serve https://github.com/jeremyfa/serve.git"
echo ""