#!/bin/bash

# Hammer Track - App Store Build Preparation Script
# Dieses Script bereitet das Projekt für den App Store vor

echo "🏆 Hammer Track - App Store Build Vorbereitung"
echo "=============================================="

# Projekt-Verzeichnis setzen
PROJECT_DIR="/Users/merlinhummel/Documents/HammerTrack"
PROJECT_NAME="Hammer Track"

cd "$PROJECT_DIR"

echo "📍 Arbeitsverzeichnis: $PROJECT_DIR"

# 1. Clean Build Directory
echo "🧹 Bereinige Build-Verzeichnis..."
xcodebuild clean -project "$PROJECT_NAME.xcodeproj" -scheme "$PROJECT_NAME"

# 2. Build für Release
echo "🔨 Erstelle Release Build..."
xcodebuild -project "$PROJECT_NAME.xcodeproj" \
           -scheme "$PROJECT_NAME" \
           -configuration Release \
           -destination "generic/platform=iOS" \
           -allowProvisioningUpdates

# 3. Tests ausführen (optional)
echo "🧪 Führe Tests aus..."
xcodebuild test -project "$PROJECT_NAME.xcodeproj" \
                -scheme "$PROJECT_NAME" \
                -destination "platform=iOS Simulator,name=iPhone 15 Pro"

# 4. Archive für App Store erstellen
echo "📦 Erstelle Archive für App Store..."
ARCHIVE_PATH="$PROJECT_DIR/build/HammerTrack.xcarchive"

xcodebuild archive -project "$PROJECT_NAME.xcodeproj" \
                   -scheme "$PROJECT_NAME" \
                   -configuration Release \
                   -destination "generic/platform=iOS" \
                   -archivePath "$ARCHIVE_PATH" \
                   -allowProvisioningUpdates

if [ $? -eq 0 ]; then
    echo "✅ Archive erfolgreich erstellt: $ARCHIVE_PATH"
    echo ""
    echo "🎯 Nächste Schritte:"
    echo "1. Öffne Xcode > Window > Organizer"
    echo "2. Wähle das Archive aus"
    echo "3. Klicke 'Distribute App'"
    echo "4. Wähle 'App Store Connect'"
    echo "5. Folge dem Upload-Wizard"
else
    echo "❌ Fehler beim Erstellen des Archives"
    exit 1
fi

echo ""
echo "📊 Build-Informationen:"
echo "- Projekt: $PROJECT_NAME"
echo "- Konfiguration: Release"
echo "- Platform: iOS"
echo "- Archive: $ARCHIVE_PATH"
echo ""
echo "🚀 Bereit für App Store Upload!"