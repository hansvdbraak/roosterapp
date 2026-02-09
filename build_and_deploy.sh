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

echo "=== Build & Deploy Complete ==="
echo "Version: $(grep "version = " lib/config/version.dart | sed "s/.*'\(.*\)'.*/\1/")"
