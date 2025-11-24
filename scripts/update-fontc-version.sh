#!/bin/bash
# Exit on error, undefined variables, and pipeline failures
set -euo pipefail

# Auto-update script for fontc version
# Usage: ./update-fontc-version.sh [version]
# Examples:
#   ./update-fontc-version.sh          # Uses latest release from GitHub
#   ./update-fontc-version.sh 0.3.2    # Uses specific version

FONTC_REPO_URL="https://github.com/googlefonts/fontc"
FONTC_REPO_API="https://api.github.com/repos/googlefonts/fontc"
PLIST_PATH="fontcExport.glyphsFileFormat/Contents/Info.plist"
REQUIREMENTS_PATH="fontcExport.glyphsFileFormat/Contents/Resources/requirements.txt"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    echo "Install it with: brew install jq"
    exit 1
fi

if [ $# -gt 1 ]; then
    echo "Error: Too many arguments"
    echo "Usage: $0 [version]"
    echo "  If version is not provided, the latest release will be fetched from GitHub"
    exit 1
fi

# Determine version to use
if [ $# -eq 1 ]; then
    # Use provided version
    NEW_VERSION="$1"
    echo "==> Using specified version: $NEW_VERSION"
else
    # Fetch latest release from GitHub
    echo "==> Fetching latest fontc release from GitHub..."

    TAG_NAME=$(curl -fsSL "$FONTC_REPO_API/releases/latest" | jq -r '.tag_name')
    if [ $? -ne 0 ] || [ -z "$TAG_NAME" ] || [ "$TAG_NAME" = "null" ]; then
        echo "Error: Failed to fetch latest release tag from GitHub API"
        exit 1
    fi

    echo "    Latest release tag: $TAG_NAME"

    # Remove "fontc-v" prefix to get version number
    NEW_VERSION="${TAG_NAME#fontc-v}"

    if [ -z "$NEW_VERSION" ] || [ "$NEW_VERSION" = "$TAG_NAME" ]; then
        echo "Error: Could not extract version from tag name: $TAG_NAME"
        echo "Expected format: fontc-vX.Y.Z"
        exit 1
    fi

    echo "    Version: $NEW_VERSION"
fi

echo "==> Updating fontc to version $NEW_VERSION"

# Step 1: Update FONTC_VERSION file
echo "==> Updating FONTC_VERSION file"
echo "$NEW_VERSION" > FONTC_VERSION
echo "    Updated FONTC_VERSION to $NEW_VERSION"

# Step 2: Download requirements.txt from the release
echo "==> Downloading requirements.txt from fontc release"
REQUIREMENTS_URL="$FONTC_REPO_URL/releases/download/fontc-v$NEW_VERSION/requirements.txt"

if curl -fLJo "$REQUIREMENTS_PATH" "$REQUIREMENTS_URL"; then
    echo "    Successfully downloaded requirements.txt"
else
    echo "Error: Failed to download requirements.txt from $REQUIREMENTS_URL"
    exit 1
fi

# Step 3: Auto-increment plugin version numbers in Info.plist
echo "==> Updating plugin version numbers in Info.plist"

# Extract current version numbers using PlistBuddy
CURRENT_SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST_PATH")
CURRENT_BUILD_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST_PATH")

echo "    Current CFBundleShortVersionString: $CURRENT_SHORT_VERSION"
echo "    Current CFBundleVersion: $CURRENT_BUILD_VERSION"

# Increment build version (simple integer increment)
NEW_BUILD_VERSION=$((CURRENT_BUILD_VERSION + 1))

# Increment short version (minor version bump)
# Extract major and minor from current version (e.g., "0.5" -> major=0, minor=5)
MAJOR=$(echo "$CURRENT_SHORT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_SHORT_VERSION" | cut -d. -f2)
NEW_MINOR=$((MINOR + 1))
NEW_SHORT_VERSION="$MAJOR.$NEW_MINOR"

echo "    New CFBundleShortVersionString: $NEW_SHORT_VERSION"
echo "    New CFBundleVersion: $NEW_BUILD_VERSION"

# Update Info.plist using PlistBuddy
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_SHORT_VERSION" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD_VERSION" "$PLIST_PATH"

echo "    Successfully updated Info.plist"

# Step 4: Summary
echo ""
echo "==> Update completed successfully!"
echo "    fontc version: $NEW_VERSION"
echo "    Plugin version: $NEW_SHORT_VERSION (build $NEW_BUILD_VERSION)"
echo ""
echo "Files updated:"
echo "  - FONTC_VERSION"
echo "  - $REQUIREMENTS_PATH"
echo "  - $PLIST_PATH"
