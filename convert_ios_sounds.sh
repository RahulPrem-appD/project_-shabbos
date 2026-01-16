#!/bin/bash
# Convert MP3 sound files to CAF format for iOS notifications
# iOS does NOT support MP3 for notification sounds - must use CAF, WAV, or AIFF

echo "Converting MP3 files to CAF format for iOS..."
echo ""

SOUNDS_DIR="ios/Runner/Sounds"

if [ ! -d "$SOUNDS_DIR" ]; then
    echo "Error: $SOUNDS_DIR directory not found!"
    exit 1
fi

cd "$SOUNDS_DIR"

for mp3_file in *.mp3; do
    if [ -f "$mp3_file" ]; then
        caf_file="${mp3_file%.mp3}.caf"
        echo "Converting: $mp3_file -> $caf_file"
        
        # Use afconvert (macOS built-in tool)
        if command -v afconvert &> /dev/null; then
            afconvert "$mp3_file" "$caf_file" -d ima4 -f caff -v
            if [ $? -eq 0 ]; then
                echo "  ✓ Successfully converted to $caf_file"
            else
                echo "  ✗ Failed to convert $mp3_file"
            fi
        else
            echo "  ✗ Error: afconvert not found. Install Xcode command line tools."
            echo "  Run: xcode-select --install"
            exit 1
        fi
    fi
done

echo ""
echo "Conversion complete!"
echo ""
echo "Next steps:"
echo "1. Open Xcode project"
echo "2. Add the .caf files to the project (if not already added)"
echo "3. Ensure they're included in the app bundle (Target Membership)"
echo "4. Rebuild the app"
