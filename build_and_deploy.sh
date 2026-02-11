#!/bin/bash
# Build and deploy script with automatic version increment

echo "=== Roosterapp Build & Deploy ==="
echo ""

# Step 1: Increment version
echo "Step 1: Incrementing version..."
./increment_version.sh
echo ""

# Step 2: Build Flutter web
echo "Step 2: Building Flutter web..."
flutter build web --release
if [ $? -ne 0 ]; then
    echo "Error: Flutter build failed!"
    exit 1
fi
echo ""

# Step 3: Deploy to server
echo "Step 3: Deploying to server..."
rsync -avz --delete --exclude='assets/' build/web/ root@91.99.141.133:/var/www/roosterapp/
if [ $? -ne 0 ]; then
    echo "Error: Deployment failed!"
    exit 1
fi
echo ""

# Step 4: Deploy changelog
echo "Step 4: Deploying changelog..."
VERSION=$(grep "version = " lib/config/version.dart | sed "s/.*'\(.*\)'.*/\1/")
if [ -f "changelog.txt" ]; then
    # Voeg build-versie header toe bovenaan en kopieer naar server
    { echo "Build: v${VERSION} ($(date '+%Y-%m-%d'))"; echo ""; cat changelog.txt; } | ssh root@91.99.141.133 "cat > /opt/rooster_server/changelog.txt"
    echo "Changelog gedeployed (v${VERSION})"
else
    echo "Waarschuwing: changelog.txt niet gevonden, overgeslagen"
fi
echo ""

echo "=== Build & Deploy Complete ==="
echo "Version: ${VERSION}"
