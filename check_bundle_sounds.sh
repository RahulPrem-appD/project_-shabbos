#!/bin/bash
# Script to verify .caf files are in the iOS app bundle

echo "=== Checking iOS App Bundle for .caf Files ==="
echo ""

# Find the built app bundle
APP_BUNDLE=$(find ~/Library/Developer/Xcode/DerivedData -name "Runner.app" -type d 2>/dev/null | head -1)

if [ -z "$APP_BUNDLE" ]; then
    echo "❌ No built app bundle found!"
    echo "   Build the app first: flutter build ios"
    exit 1
fi

echo "Found app bundle: $APP_BUNDLE"
echo ""

# Check for .caf files in bundle root
echo "Checking bundle root for .caf files:"
ROOT_CAF=$(find "$APP_BUNDLE" -maxdepth 1 -name "*.caf" 2>/dev/null)
if [ -z "$ROOT_CAF" ]; then
    echo "  ⚠️  No .caf files in bundle root"
else
    echo "  ✓ Found .caf files in bundle root:"
    echo "$ROOT_CAF" | sed 's/^/    /'
fi

# Check for .caf files anywhere in bundle
echo ""
echo "Checking entire bundle for .caf files:"
ALL_CAF=$(find "$APP_BUNDLE" -name "*.caf" 2>/dev/null)
if [ -z "$ALL_CAF" ]; then
    echo "  ❌ NO .caf files found in bundle at all!"
    echo ""
    echo "  This means the files are NOT being copied to the bundle."
    echo "  Check Xcode → Runner target → Build Phases → Copy Bundle Resources"
    echo "  Ensure all .caf files are listed there."
else
    echo "  ✓ Found .caf files in bundle:"
    echo "$ALL_CAF" | sed 's/^/    /'
fi

# List all files in bundle root
echo ""
echo "Files in bundle root:"
ls -1 "$APP_BUNDLE" | head -20 | sed 's/^/    /'

echo ""
echo "=== Check Complete ==="
