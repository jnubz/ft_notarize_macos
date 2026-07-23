#!/bin/bash

set -e

CONFIG_FILE="flet_notarize.config"

echo "======================================="
echo "Flet macOS Notarization Setup"
echo "======================================="
echo ""

# Check for existing config
if [ ! -f "$CONFIG_FILE" ]; then
    echo "No config file found. Creating template..."
    
    # Create template
    printf '%s\n' \
        '# Flet macOS Notarization Configuration' \
        '# Fill in all required fields below' \
        '' \
        'TEAM_ID=""' \
        'CERT_NAME="Developer ID Application: Your Name (TEAM_ID)"' \
        'APP_PATH="/Users/username/Downloads/MyApp.app"' \
        'APPLE_ID="your@email.com"' \
        'APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"' \
        > "$CONFIG_FILE"
    
    echo "✓ Created: $CONFIG_FILE"
    echo ""
    echo "Opening editor..."
    
    # Open editor and wait for it to close
    ${EDITOR:-nano} "$CONFIG_FILE"
    
    # Ask user to confirm they saved
    echo ""
    read -p "Press Enter once you've saved and closed the editor: " -r
    echo ""
fi

# Load config
echo "Loading config..."
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found!"
    exit 1
fi

source "$CONFIG_FILE"

# Validate fields
if [ -z "$TEAM_ID" ] || [ -z "$CERT_NAME" ] || [ -z "$APP_PATH" ] || [ -z "$APPLE_ID" ] || [ -z "$APP_PASSWORD" ]; then
    echo "❌ Error: Some required fields are empty."
    echo ""
    echo "Reopening editor..."
    
    ${EDITOR:-nano} "$CONFIG_FILE"
    
    echo ""
    read -p "Press Enter once you've saved and closed the editor: " -r
    echo ""
    
    source "$CONFIG_FILE"
    
    if [ -z "$TEAM_ID" ] || [ -z "$CERT_NAME" ] || [ -z "$APP_PATH" ] || [ -z "$APPLE_ID" ] || [ -z "$APP_PASSWORD" ]; then
        echo "❌ Configuration still incomplete. Exiting."
        exit 1
    fi
fi

echo "✓ Config loaded successfully"
echo ""

# ===== DERIVE VARIABLES FROM APP_PATH =====
APP_NAME="${APP_PATH##*/}"      # Extract filename: MyApp.app
APP_NAME="${APP_NAME%.app}"     # Remove .app extension: MyApp
APP_DIR="${APP_PATH%/*}"        # Get parent directory
WORK_DIR="/tmp/notarize_work"
ZIP_PATH="$APP_PATH/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/app/app.zip"
DMG_PATH="$APP_DIR/$APP_NAME.dmg"

# Display configuration
echo "======================================="
echo "Configuration Summary"
echo "======================================="
echo "App Name:    $APP_NAME"
echo "App Path:    $APP_PATH"
echo "DMG Path:    $DMG_PATH"
echo "Team ID:     $TEAM_ID"
echo "Apple ID:    $APPLE_ID"
echo "======================================="
echo ""

read -p "Continue with notarization? (y/n) " -n 1 -r
echo ""

if ! [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""

echo "======================================="
echo "STEP 1: Handle zipped venv (if present)"
echo "======================================="

if [ -f "$ZIP_PATH" ]; then
    echo "Found app.zip, extracting..."
    mkdir -p "$WORK_DIR"
    rm -rf "$WORK_DIR/app_extracted"
    cp "$ZIP_PATH" "$WORK_DIR/app.zip.backup"
    unzip -q "$ZIP_PATH" -d "$WORK_DIR/app_extracted"
    
    if [ -d "$WORK_DIR/app_extracted/.venv" ]; then
        echo "Found .venv, signing venv binaries..."
        
        VENV_PATH="$WORK_DIR/app_extracted/.venv"
        find "$VENV_PATH" \( -name "*.so" -o -name "*.dylib" \) -exec codesign --force --timestamp --verbose --sign "$CERT_NAME" --options runtime {} \;
        find "$VENV_PATH/bin" -type f ! -name "*.so" -exec codesign --force --timestamp --verbose --sign "$CERT_NAME" --options runtime {} \;
        find "$VENV_PATH" -path "*/PyInstaller/bootloader/Darwin-64bit/*" -type f ! -name "*.so" -exec codesign --force --timestamp --verbose --sign "$CERT_NAME" --options runtime {} \;
        
        echo "Re-zipping app.zip..."
        rm "$ZIP_PATH"
        cd "$WORK_DIR/app_extracted"
        /usr/bin/ditto -c -k --sequesterRsrc --keepParent . "$ZIP_PATH"
        cd - > /dev/null
    else
        echo "No .venv found in app.zip, skipping venv signing"
    fi
    
    # Always cleanup
    rm -rf "$WORK_DIR/app_extracted"
else
    echo "No app.zip found, skipping extraction"
fi

echo "✓ Venv handling complete"
echo ""

echo "======================================"
echo "STEP 2: Remove CocoaPods metadata."
echo "======================================"
find "$APP_PATH" -name ".pod" -delete

echo "======================================"
echo "STEP 3: Remove old signatures"
echo "======================================"
codesign --remove-signature "$APP_PATH"
find "$APP_PATH/Contents/Frameworks" -type d -name "*.framework" -exec codesign --remove-signature {} \;

echo "======================================"
echo "STEP 4: Re-sign entire app"
echo "======================================"
find "$APP_PATH" \( -name "*.so" -o -name "*.dylib" \) -not -path "*/.venv/*" -exec codesign --force --timestamp --verbose --sign "$CERT_NAME" --options runtime {} \;
find "$APP_PATH/Contents/Frameworks" -type d -name "*.framework" -exec codesign --force --timestamp --verbose --sign "$CERT_NAME" --options runtime {} \;
codesign --force --deep --timestamp --verbose --sign "$CERT_NAME" --options runtime "$APP_PATH"

echo "======================================"
echo "STEP 5: Verify app signature"
echo "======================================"
codesign --verify --deep --strict -vvv "$APP_PATH"

echo "======================================="
echo "STEP 6: Create fancy DMG with Applications folder"
echo "======================================="

# Create staging directory
DMG_STAGING="$WORK_DIR/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

echo "Copying app to staging (preserving signatures)..."
ditto "$APP_PATH" "$DMG_STAGING/$(basename "$APP_PATH")"

echo "Creating Applications link..."
ln -s /Applications "$DMG_STAGING/Applications"

echo "Creating DMG..."
rm -f "$DMG_PATH"
diskutil image create from --format UDZO --volumeName "$APP_NAME" "$DMG_STAGING" "$DMG_PATH"

echo "Cleaning up..."
rm -rf "$DMG_STAGING"

echo "✓ DMG created: $DMG_PATH"
echo ""

echo "======================================"
echo "STEP 7: Sign DMG"
echo "======================================"
codesign --force --timestamp --verbose --sign "$CERT_NAME" "$DMG_PATH"
codesign --verify --verbose "$DMG_PATH"

echo "======================================"
echo "STEP 8: Submit for notarization"
echo "======================================"
xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_PASSWORD" \
  --wait

echo "======================================"
echo "STEP 9: Staple notarization ticket"
echo "======================================"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "======================================"
echo "✅ NOTARIZATION COMPLETE!"
echo "======================================"
echo "Your notarized app is ready at:"
echo "$DMG_PATH"
