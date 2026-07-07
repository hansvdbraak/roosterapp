# Build & Deployment Guide

## Version Management

The app version is displayed on the welcome screen below "Ruimte Reserveringssysteem".

**Current version location:** `lib/config/version.dart`

### Manual Version Increment

To manually increment the version:
```bash
./increment_version.sh
```

This will increment the version from `2.01.01` → `2.01.02` → `2.01.03`, etc.

### Build and Deploy (with Auto Version Increment)

To build, increment version, and deploy in one command:
```bash
./build_and_deploy.sh
```

This script will:
1. Automatically increment the version number
2. Build the Flutter web app
3. Deploy to production server (rooster.4ub2b.com)

### Manual Build (Old Method)

If you prefer to build manually without version increment:
```bash
flutter build web --release && rsync -avz --delete --exclude='assets/' build/web/ root@91.99.141.133:/var/www/roosterapp/
```

**Note:** This will NOT increment the version number.

## Version Format

- **Format:** `MAJOR.MINOR.PATCH`
- **Example:** `2.01.01`
- **Increment:** Only PATCH number increases (+1 each build)
- **Display:** Shows as "V 2.01.01" on welcome screen
