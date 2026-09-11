#!/bin/bash

# DPDC Balance Checker - Deployment Script
# Usage: ./deploy.sh [patch|major|major-apk]
#
# patch     - Incremental OTA update via Shorebird (no version bump)
# major     - Full release with version bump (AAB for Play Store)
# major-apk - Full release with version bump (APK for direct install)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if deployment type is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Deployment type required${NC}"
    echo "Usage: ./deploy.sh [patch|major|major-apk]"
    echo ""
    echo "  patch     - Incremental OTA update (Shorebird code push)"
    echo "  major     - Full release with version bump (AAB for Play Store)"
    echo "  major-apk - Full release with version bump (APK for direct install)"
    exit 1
fi

DEPLOY_TYPE="$1"

# Validate deployment type
if [[ "$DEPLOY_TYPE" != "patch" && "$DEPLOY_TYPE" != "major" && "$DEPLOY_TYPE" != "major-apk" ]]; then
    echo -e "${RED}Error: Invalid deployment type '$DEPLOY_TYPE'${NC}"
    echo "Valid types: patch, major, major-apk"
    exit 1
fi

# Check if shorebird is installed, install if missing
if ! command -v shorebird &>/dev/null; then
    echo -e "${YELLOW}Shorebird CLI not found. Installing...${NC}"
    curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash

    # Add to PATH for current session
    export PATH="$HOME/.shorebird/bin:$PATH"

    # Verify installation
    if ! command -v shorebird &>/dev/null; then
        echo -e "${RED}Error: Shorebird installation failed${NC}"
        echo "Please install manually: curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash"
        exit 1
    fi
    echo -e "${GREEN}Shorebird installed successfully!${NC}"
fi

# Check if logged in to Shorebird
if ! shorebird login:ci --help &>/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: You may need to login to Shorebird first${NC}"
    echo "Run: shorebird login"
fi

# Function to get current version from pubspec.yaml
get_current_version() {
    grep 'version:' pubspec.yaml | head -1 | sed 's/version: //' | tr -d ' '
}

# Function to bump version
bump_version() {
    local current_version="$1"
    local version_part=$(echo "$current_version" | cut -d'+' -f1)
    local build_number=$(echo "$current_version" | cut -d'+' -f2)

    # Split version into major.minor.patch
    local major=$(echo "$version_part" | cut -d'.' -f1)
    local minor=$(echo "$version_part" | cut -d'.' -f2)

    # Bump minor version
    local new_minor=$((minor + 1))
    local new_version="${major}.${new_minor}.0"
    local new_build_number=$((build_number + 1))

    echo "${new_version}+${new_build_number}"
}

# Function to update pubspec.yaml version
update_pubspec_version() {
    local new_version="$1"
    sed -i '' "s/^version: .*/version: ${new_version}/" pubspec.yaml
    echo -e "${GREEN}Updated pubspec.yaml version to: ${new_version}${NC}"
}

# Get current version
CURRENT_VERSION=$(get_current_version)
echo -e "${YELLOW}Current version: ${CURRENT_VERSION}${NC}"

# Run flutter clean and get dependencies
echo -e "${YELLOW}Running flutter clean...${NC}"
flutter clean

echo -e "${YELLOW}Getting dependencies...${NC}"
flutter pub get

# Run flutter analyze to check for issues
echo -e "${YELLOW}Running flutter analyze...${NC}"
flutter analyze

if [ "$DEPLOY_TYPE" = "patch" ]; then
    echo -e "${GREEN}=== Creating Shorebird Patch (OTA Update) ===${NC}"
    echo ""
    echo "This will push an incremental update to users without app store review."
    echo ""

    # Create patch
    shorebird patch android

    echo ""
    echo -e "${GREEN}✓ Patch created successfully!${NC}"
    echo "Users will receive the update automatically on next app launch."

elif [ "$DEPLOY_TYPE" = "major" ]; then
    echo -e "${GREEN}=== Creating Major Release (AAB) ===${NC}"
    echo ""

    # Bump version
    NEW_VERSION=$(bump_version "$CURRENT_VERSION")
    echo -e "${YELLOW}Bumping version: ${CURRENT_VERSION} → ${NEW_VERSION}${NC}"

    # Update pubspec.yaml
    update_pubspec_version "$NEW_VERSION"

    # Create release
    echo -e "${YELLOW}Creating Shorebird release...${NC}"
    shorebird release android

    echo ""
    echo -e "${GREEN}✓ Major release created successfully!${NC}"
    echo -e "${GREEN}Version: ${NEW_VERSION}${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Upload AAB to Google Play Console: build/app/outputs/bundle/release/app-release.aab"
    echo "2. Submit for review"

elif [ "$DEPLOY_TYPE" = "major-apk" ]; then
    echo -e "${GREEN}=== Creating Major Release (APK) ===${NC}"
    echo ""

    # Bump version
    NEW_VERSION=$(bump_version "$CURRENT_VERSION")
    echo -e "${YELLOW}Bumping version: ${CURRENT_VERSION} → ${NEW_VERSION}${NC}"

    # Update pubspec.yaml
    update_pubspec_version "$NEW_VERSION"

    # Create release
    echo -e "${YELLOW}Creating Shorebird release...${NC}"
    shorebird release android

    # Build APK
    echo -e "${YELLOW}Building APK...${NC}"
    flutter build apk --release

    echo ""
    echo -e "${GREEN}✓ Major release created successfully!${NC}"
    echo -e "${GREEN}Version: ${NEW_VERSION}${NC}"
    echo ""
    echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    echo "You can distribute this APK directly or via Firebase App Distribution."
fi

echo ""
echo -e "${GREEN}Deployment complete!${NC}"
