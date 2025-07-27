#!/bin/bash

# 🧪 Hammer Track - TestFlight Setup & Upload Script
# Erstellt Archive und uploaded zu TestFlight für Beta-Testing

echo "🧪 Hammer Track - TestFlight Setup"
echo "=================================="

# Konfiguration
PROJECT_DIR="/Users/merlinhummel/Documents/HammerTrack"
PROJECT_NAME="Hammer Track"
SCHEME_NAME="Hammer Track"
ARCHIVE_PATH="$PROJECT_DIR/build/HammerTrack-$(date +%Y%m%d-%H%M%S).xcarchive"
BUILD_DIR="$PROJECT_DIR/build"

# Arbeitsverzeichnis wechseln
cd "$PROJECT_DIR"
echo "📍 Arbeitsverzeichnis: $PROJECT_DIR"

# Build-Verzeichnis erstellen
mkdir -p "$BUILD_DIR"

# 1. Projekt bereinigen
echo "🧹 Bereinige vorherige Builds..."
xcodebuild clean -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME_NAME"

# 2. Version und Build Number prüfen/erhöhen
echo "🔢 Prüfe Versionsnummern..."
CURRENT_VERSION=$(xcodebuild -project "$PROJECT_NAME.xcodeproj" -target "$PROJECT_NAME" -showBuildSettings | grep "MARKETING_VERSION" | sed 's/.*= //')
CURRENT_BUILD=$(xcodebuild -project "$PROJECT_NAME.xcodeproj" -target "$PROJECT_NAME" -showBuildSettings | grep "CURRENT_PROJECT_VERSION" | sed 's/.*= //')

echo "   Aktuelle Version: $CURRENT_VERSION"
echo "   Aktuelle Build: $CURRENT_BUILD"

# Build Number automatisch erhöhen
NEW_BUILD=$((CURRENT_BUILD + 1))
echo "   Neue Build Number: $NEW_BUILD"

# 3. Tests ausführen
echo "🧪 Führe Unit Tests aus..."
xcodebuild test \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
    -quiet

if [ $? -ne 0 ]; then
    echo "⚠️  Tests fehlgeschlagen, aber Archive wird trotzdem erstellt..."
fi

# 4. Archive für TestFlight erstellen
echo "📦 Erstelle TestFlight Archive..."
echo "   Archive Pfad: $ARCHIVE_PATH"

xcodebuild archive \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    CURRENT_PROJECT_VERSION="$NEW_BUILD"

# 5. Archive validieren
if [ $? -eq 0 ]; then
    echo "✅ Archive erfolgreich erstellt!"
    
    # 6. Export für App Store Connect vorbereiten
    echo "📤 Validiere Archive für Upload..."
    
    # Export Options Plist erstellen
    EXPORT_OPTIONS_PLIST="$BUILD_DIR/ExportOptions.plist"
    cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>teamID</key>
    <string>\$(DEVELOPMENT_TEAM)</string>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
EOF

    echo "📤 Lade zu App Store Connect hoch..."
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$BUILD_DIR/TestFlight" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
        -allowProvisioningUpdates

    if [ $? -eq 0 ]; then
        echo ""
        echo "🎉 ERFOLG! TestFlight Upload abgeschlossen!"
        echo ""
        echo "📱 Nächste Schritte:"
        echo "1. Öffne App Store Connect (appstoreconnect.apple.com)"
        echo "2. Gehe zu 'Meine Apps' > 'Hammer Track'"
        echo "3. Wähle 'TestFlight' Tab"
        echo "4. Der neue Build sollte unter 'iOS Builds' erscheinen"
        echo "5. Füge Test-Informationen hinzu"
        echo "6. Lade interne/externe Tester ein"
        echo ""
        echo "📋 Build-Details:"
        echo "   Version: $CURRENT_VERSION"
        echo "   Build: $NEW_BUILD"
        echo "   Archive: $ARCHIVE_PATH"
    else
        echo "❌ Upload fehlgeschlagen!"
        echo ""
        echo "🔧 Manueller Upload:"
        echo "1. Öffne Xcode > Window > Organizer"
        echo "2. Wähle Archive: $(basename "$ARCHIVE_PATH")"
        echo "3. Klicke 'Distribute App'"
        echo "4. Wähle 'App Store Connect'"
        echo "5. Folge dem Wizard"
    fi
else
    echo "❌ Fehler beim Erstellen des Archives!"
    echo ""
    echo "🔍 Häufige Probleme:"
    echo "- Code Signing Probleme"
    echo "- Fehlende Provisioning Profiles"
    echo "- Bundle ID Konfiguration"
    echo ""
    echo "💡 Lösungsansätze:"
    echo "1. Xcode > Preferences > Accounts > Download Manual Profiles"
    echo "2. Project Settings > Signing & Capabilities > Automatically manage signing"
    echo "3. Clean Build Folder (Shift+Cmd+K)"
    exit 1
fi

echo ""
echo "🏁 TestFlight Setup abgeschlossen!"