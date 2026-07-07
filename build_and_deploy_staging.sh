#!/bin/bash
# Build and deploy script voor staging

echo "=== Roosterapp Build & Deploy (STAGING) ==="
echo ""

# Stap 1: Build Flutter web
echo "Stap 1: Flutter web bouwen..."
flutter build web --dart-define=ENV=staging
if [ $? -ne 0 ]; then
    echo "Fout: Flutter build mislukt!"
    exit 1
fi
echo ""

# Stap 2: Deploy naar staging server
echo "Stap 2: Deployen naar staging..."
scp -r build/web/* root@91.99.141.133:/var/www/roosterapp_staging/
if [ $? -ne 0 ]; then
    echo "Fout: Deploy mislukt!"
    exit 1
fi
echo ""

# Stap 3: Permissies fixen
echo "Stap 3: Permissies instellen..."
ssh root@91.99.141.133 "chmod -R 755 /var/www/roosterapp_staging/"
echo ""

echo "=== Staging Deploy Compleet ==="
echo "URL: https://staging.4ub2b.com"
