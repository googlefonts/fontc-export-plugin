#!/bin/bash
# Exit on error, undefined variables, and pipeline failures
set -euo pipefail

# Validation script for fontc update
# Performs basic checks to ensure the update was successful

PLIST_PATH="fontcExport.glyphsFileFormat/Contents/Info.plist"
REQUIREMENTS_PATH="fontcExport.glyphsFileFormat/Contents/Resources/requirements.txt"
FONTC_VERSION_FILE="FONTC_VERSION"

# Check 1: All required files exist
echo "==> Checking required files exist"
if [ ! -f "$FONTC_VERSION_FILE" ]; then
    echo "Error: FONTC_VERSION file not found"
    exit 1
fi

if [ ! -f "$REQUIREMENTS_PATH" ]; then
    echo "Error: requirements.txt not found"
    exit 1
fi

if [ ! -f "$PLIST_PATH" ]; then
    echo "Error: Info.plist not found"
    exit 1
fi

echo "    All required files found:"
echo "      - $FONTC_VERSION_FILE"
echo "      - $REQUIREMENTS_PATH"
echo "      - $PLIST_PATH"

# Check 2: FONTC_VERSION file contains a valid version
echo "==> Validating FONTC_VERSION"
FONTC_VERSION=$(cat "$FONTC_VERSION_FILE")
if ! [[ "$FONTC_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: FONTC_VERSION contains invalid version: $FONTC_VERSION"
    exit 1
fi
echo "    FONTC_VERSION is valid: $FONTC_VERSION"

# Check 3: requirements.txt is valid format
echo "==> Validating requirements.txt format"

# Check for required header
if ! grep -q "^--only-binary :all:$" "$REQUIREMENTS_PATH"; then
    echo "Error: requirements.txt missing '--only-binary :all:' header"
    exit 1
fi

# Check for fontc package line
if ! grep -q "^fontc==" "$REQUIREMENTS_PATH"; then
    echo "Error: requirements.txt missing 'fontc==' package specification"
    exit 1
fi

# Extract version from requirements.txt
REQ_VERSION=$(grep "^fontc==" "$REQUIREMENTS_PATH" | sed 's/fontc==\([0-9.]*\).*/\1/')
if [ "$REQ_VERSION" != "$FONTC_VERSION" ]; then
    echo "Error: Version mismatch between FONTC_VERSION ($FONTC_VERSION) and requirements.txt ($REQ_VERSION)"
    exit 1
fi

# Check for SHA256 hashes (should have at least one)
if ! grep -q "    --hash=sha256:" "$REQUIREMENTS_PATH"; then
    echo "Error: requirements.txt missing SHA256 hashes"
    exit 1
fi

HASH_COUNT=$(grep -c "    --hash=sha256:" "$REQUIREMENTS_PATH" || true)
echo "    requirements.txt is valid (version: $REQ_VERSION, $HASH_COUNT SHA256 hashes)"

# Check 4: Info.plist is valid XML
echo "==> Validating Info.plist XML structure"

if xmllint --noout "$PLIST_PATH" 2>&1; then
    echo "    Info.plist is valid XML"
else
    echo "Error: Info.plist is not valid XML"
    exit 1
fi

# Check 5: Version numbers in Info.plist are present and valid
echo "==> Validating Info.plist version numbers"

# Use PlistBuddy to read version numbers
SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST_PATH" 2>/dev/null)
BUILD_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST_PATH" 2>/dev/null)

if [ -z "$SHORT_VERSION" ]; then
    echo "Error: Could not extract CFBundleShortVersionString from Info.plist"
    exit 1
fi

if [ -z "$BUILD_VERSION" ]; then
    echo "Error: Could not extract CFBundleVersion from Info.plist"
    exit 1
fi

# Validate format of short version (should be MAJOR.MINOR)
if ! [[ "$SHORT_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "Error: CFBundleShortVersionString has invalid format: $SHORT_VERSION"
    exit 1
fi

# Validate format of build version (should be integer)
if ! [[ "$BUILD_VERSION" =~ ^[0-9]+$ ]]; then
    echo "Error: CFBundleVersion has invalid format: $BUILD_VERSION"
    exit 1
fi

echo "    CFBundleShortVersionString: $SHORT_VERSION"
echo "    CFBundleVersion: $BUILD_VERSION"

# Check 6: Test fontc installation in Python 3.11 venv
echo "==> Testing fontc installation"

# Create temporary directory for venv
TEMP_VENV=$(mktemp -d)

echo "    Creating Python 3.11 virtual environment..."
if ! python3.11 -m venv "$TEMP_VENV" 2>/dev/null; then
    echo "Error: Failed to create Python 3.11 venv. Is Python 3.11 installed?"
    echo "Temporary venv left at: $TEMP_VENV"
    exit 1
fi

echo "    Installing fontc from requirements.txt..."
if ! "$TEMP_VENV/bin/pip" install --quiet --disable-pip-version-check -r "$REQUIREMENTS_PATH" 2>&1; then
    echo "Error: Failed to install fontc from requirements.txt"
    echo "Temporary venv left at: $TEMP_VENV"
    exit 1
fi

FONTC_VERSION_OUTPUT=$("$TEMP_VENV/bin/fontc" --version 2>&1)
if [ $? -ne 0 ]; then
    echo "Error: Failed to run fontc --version"
    echo "Output: $FONTC_VERSION_OUTPUT"
    echo "Temporary venv left at: $TEMP_VENV"
    exit 1
fi

# Extract version from output (expected format: "fontc X.Y.Z")
INSTALLED_VERSION=$(echo "$FONTC_VERSION_OUTPUT" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
if [ -z "$INSTALLED_VERSION" ]; then
    echo "Error: Could not extract version from fontc --version output: $FONTC_VERSION_OUTPUT"
    echo "Temporary venv left at: $TEMP_VENV"
    exit 1
fi

echo "    fontc installed successfully: $INSTALLED_VERSION"

# Verify installed version matches expected version
if [ "$INSTALLED_VERSION" != "$FONTC_VERSION" ]; then
    echo "Error: Installed fontc version ($INSTALLED_VERSION) does not match expected version ($FONTC_VERSION)"
    echo "Temporary venv left at: $TEMP_VENV"
    exit 1
fi

# Clean up venv on success
echo "    Cleaning up temporary venv..."
rm -rf "$TEMP_VENV"

# All checks passed
echo ""
echo "==> All validation checks passed!"
echo ""
echo "Summary:"
echo "  fontc version: $FONTC_VERSION"
echo "  Plugin version: $SHORT_VERSION (build $BUILD_VERSION)"
echo "  SHA256 hashes: $HASH_COUNT"
echo "  Installation test: PASSED"
