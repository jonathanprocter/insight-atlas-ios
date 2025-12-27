#!/bin/bash

# Script to remove ZIPFoundation references from Xcode project
# Run this from your project directory

PROJECT_FILE="InsightAtlas.xcodeproj/project.pbxproj"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "Error: Cannot find $PROJECT_FILE"
    echo "Make sure you're running this script from the project root directory"
    exit 1
fi

echo "Creating backup of project.pbxproj..."
cp "$PROJECT_FILE" "${PROJECT_FILE}.backup"

echo "Removing ZIPFoundation references..."

# Remove package references
sed -i '' '/ZIPFoundation/d' "$PROJECT_FILE"
sed -i '' '/weichsel/d' "$PROJECT_FILE"

echo "Done! Project file has been updated."
echo "Backup saved as: ${PROJECT_FILE}.backup"
echo ""
echo "Next steps:"
echo "1. Close Xcode if it's open"
echo "2. Reopen your project"
echo "3. Product -> Clean Build Folder (Shift+Cmd+K)"
echo "4. Build (Cmd+B)"
