#!/bin/bash
# Script to increment version number before build

VERSION_FILE="lib/config/version.dart"

# Read current version
CURRENT_VERSION=$(grep "version = " "$VERSION_FILE" | sed "s/.*'\(.*\)'.*/\1/")

# Split version into parts (e.g., 2.01.01 -> 2 01 01)
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Increment patch version (10# prefix forces decimal to avoid octal interpretation)
PATCH=$((10#$PATCH + 1))

# Format new version (ensure two digits for patch)
NEW_VERSION="$MAJOR.$MINOR.$(printf "%02d" $PATCH)"

# Update version file
cat > "$VERSION_FILE" << EOF
/// App version configuration
/// Update this after each build
class AppVersion {
  static const String version = '$NEW_VERSION';
}
EOF

echo "Version incremented: $CURRENT_VERSION → $NEW_VERSION"
