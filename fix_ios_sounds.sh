#!/bin/bash
# Comprehensive script to fix iOS notification sounds

set -e

echo "=========================================="
echo "iOS Notification Sound Fix Script"
echo "=========================================="
echo ""

cd "$(dirname "$0")"

# Step 1: Verify .caf files exist
echo "Step 1: Verifying .caf files exist..."
CAF_COUNT=$(ls -1 ios/Runner/Sounds/*.caf 2>/dev/null | wc -l | tr -d ' ')
if [ "$CAF_COUNT" -eq 6 ]; then
    echo "✓ Found 6 .caf files"
else
    echo "✗ Expected 6 .caf files, found $CAF_COUNT"
    echo "  Run: ./convert_ios_sounds.sh"
    exit 1
fi

# Step 2: Verify files are in Xcode project
echo ""
echo "Step 2: Verifying files are in Xcode project..."
PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"
if grep -q "RavShalomShofarDefaultlouder.caf" "$PROJECT_FILE"; then
    echo "✓ .caf files are referenced in Xcode project"
else
    echo "✗ .caf files not found in Xcode project"
    echo "  Files need to be added manually in Xcode"
    exit 1
fi

# Step 3: Verify files are in Copy Bundle Resources
echo ""
echo "Step 3: Verifying files are in Copy Bundle Resources..."
if grep -q "SHAB0070000000000001.*RavShalomShofarDefaultlouder.caf in Resources" "$PROJECT_FILE"; then
    echo "✓ .caf files are in Copy Bundle Resources"
else
    echo "✗ .caf files not found in Copy Bundle Resources"
    echo "  This is the problem! Files need to be added to Copy Bundle Resources in Xcode"
    echo ""
    echo "  To fix:"
    echo "  1. Open ios/Runner.xcworkspace in Xcode"
    echo "  2. Select Runner target"
    echo "  3. Go to Build Phases → Copy Bundle Resources"
    echo "  4. Click + and add all .caf files from ios/Runner/Sounds/"
    exit 1
fi

# Step 4: Clean build
echo ""
echo "Step 4: Cleaning build artifacts..."
flutter clean
flutter pub get
echo "✓ Flutter dependencies updated"
cd ios
if [ -d "Pods" ]; then
    rm -rf Pods Podfile.lock
    echo "✓ Removed Pods"
fi
pod install
cd ..
echo "✓ iOS dependencies updated"

# Step 5: Build instructions
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Build the app:"
echo "   flutter build ios"
echo ""
echo "2. Or run directly:"
echo "   flutter run"
echo ""
echo "3. Check console output when app launches:"
echo "   Look for: 'ShabbosApp: Verifying sound files in bundle...'"
echo "   Should see: 'ShabbosApp: Found 6/6 sound files in bundle'"
echo ""
echo "4. If you see 'NOT FOUND' messages:"
echo "   - Open ios/Runner.xcworkspace in Xcode"
echo "   - Select Runner target → Build Phases → Copy Bundle Resources"
echo "   - Ensure all .caf files are listed"
echo "   - Clean build folder (Product → Clean Build Folder)"
echo "   - Rebuild"
echo ""
echo "=========================================="
