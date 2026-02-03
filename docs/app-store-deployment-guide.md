# App Store Deployment Guide - HammerTrack

## Übersicht
Diese Anleitung führt Sie durch den Prozess der direkten App Store Submission **ohne TestFlight Phase**.

---

## Voraussetzungen

### 1. Apple Developer Account
- **Benötigt**: Apple Developer Program Mitgliedschaft ($99/Jahr)
- **Registrierung**: https://developer.apple.com/programs/
- **Wichtig**: Account muss vollständig aktiviert sein (kann 24-48h dauern)

### 2. App Store Connect Zugang
- **URL**: https://appstoreconnect.apple.com/
- **Login**: Mit Apple Developer Account anmelden
- **Team**: Sicherstellen, dass Sie Admin-Rechte haben

### 3. Xcode Konfiguration
- **Version**: Xcode 15+ empfohlen
- **Signing**: Automatisches Signing aktiviert oder manuelle Provisioning Profiles eingerichtet

---

## Phase 1: Xcode Projekt Vorbereitung

### Schritt 1: Code Signing & Capabilities prüfen

1. Öffnen Sie **HammerTrack.xcodeproj** in Xcode
2. Wählen Sie das Projekt im Navigator
3. Gehen Sie zu **Signing & Capabilities**

**Prüfen Sie:**
```
✓ Team: [Ihr Apple Developer Team]
✓ Bundle Identifier: eindeutig (z.B. com.[IhrName].hammertrack)
✓ Signing Certificate: "Apple Distribution" (nicht "Development"!)
✓ Provisioning Profile: "App Store" oder "Automatic"
```

**Falls Fehler auftreten:**
- "Failed to register bundle identifier": Bundle ID bereits verwendet → ändern
- "No signing certificate": Certificate in Xcode → Preferences → Accounts → Download Manual Profiles

### Schritt 2: Build Configuration

1. Wählen Sie **Product → Scheme → Edit Scheme...**
2. Bei **Archive** links auswählen
3. **Build Configuration**: Auf "Release" setzen (nicht "Debug"!)

### Schritt 3: Version & Build Number

1. Projekt auswählen → **General** Tab
2. **Version**: z.B. `1.0.0` (Semantic Versioning: Major.Minor.Patch)
3. **Build**: z.B. `1` (fortlaufende Nummer, muss bei jedem Upload erhöht werden)

**Wichtig**: Bei jedem neuen Upload muss Build Number erhöht werden!

---

## Phase 2: App Archivieren

### Schritt 4: Archive erstellen

1. **Device**: Wählen Sie "Any iOS Device (arm64)" in Xcode Toolbar (NICHT Simulator!)
2. **Product → Archive** auswählen
3. **Warten**: Build-Prozess kann 5-15 Minuten dauern

**Mögliche Build-Fehler:**

| Fehler | Lösung |
|--------|--------|
| Code signing error | Signing & Capabilities überprüfen |
| Missing entitlements | Capabilities Tab prüfen |
| Deprecated API warnings | Warnings akzeptabel, Errors nicht |

### Schritt 5: Organizer öffnet sich automatisch

Nach erfolgreichem Archive sollte **Organizer** automatisch öffnen mit Ihrem Archive.

Falls nicht: **Window → Organizer**

**Was Sie sehen sollten:**
- Ihr Archive in der Liste
- Name: HammerTrack
- Version: 1.0.0 (1)
- Größe: ~XX MB

---

## Phase 3: App Store Connect Vorbereitung

### Schritt 6: Neue App in App Store Connect erstellen

1. Gehen Sie zu https://appstoreconnect.apple.com/
2. **My Apps** → **Plus Button (+)** → **New App**

**App-Informationen:**

```yaml
Platforms: iOS
Name: HammerTrack
Primary Language: German (Deutschland)
Bundle ID: [Wählen Sie Ihren Bundle ID aus Dropdown]
SKU: hammertrack-ios-1 (eindeutige Kennung, intern)
User Access: Full Access
```

**Wichtig**: Bundle ID muss genau mit Xcode übereinstimmen!

### Schritt 7: App-Informationen ausfüllen

Nach dem Erstellen müssen Sie folgende Bereiche ausfüllen:

#### 7.1 App Information

```yaml
Name: HammerTrack
Subtitle: Video-Analyse für Hammer-Würfe (max 30 Zeichen)
Primary Category: Sports
Secondary Category: Developer Tools (optional)
Content Rights: [Ihre Rechte bestätigen]
```

#### 7.2 Pricing and Availability

```yaml
Price Schedule: Free (oder gewünschter Preis)
Availability: All Countries/Regions (oder spezifisch auswählen)
Pre-Orders: No (für erste Version)
```

#### 7.3 App Privacy

**Erforderlich**: Privacy-Informationen angeben

1. **Data Collection**: Sammeln Sie Nutzerdaten?
   - Falls NEIN: "No, we do not collect data from this app"
   - Falls JA: Details angeben (z.B. Crash-Logs, Analytics)

2. **Privacy Policy URL**:
   - Falls Sie Daten sammeln: URL zu Ihrer Privacy Policy
   - Falls NEIN: Kann leer bleiben

**Beispiel für HammerTrack** (keine Server-Kommunikation):
```
✓ No data collected
✓ No tracking
✓ No third-party data
```

---

## Phase 4: Version vorbereiten

### Schritt 8: iOS App Section

1. In **App Store** Tab links
2. **Prepare for Submission** → **+** bei **iOS App**

#### 8.1 Screenshots (ERFORDERLICH!)

**Benötigte Größen** (mindestens eine):

```
iPhone 6.7" (iPhone 15 Pro Max): 1290 x 2796 px
iPhone 6.5" (iPhone 11 Pro Max): 1242 x 2688 px
iPhone 5.5" (iPhone 8 Plus): 1242 x 2208 px
```

**Wie erstellen:**
1. App auf Simulator starten (z.B. iPhone 15 Pro Max)
2. **Cmd + S** für Screenshot
3. Screenshots landen in ~/Desktop
4. In App Store Connect hochladen

**Mindestanforderung**: 3-5 Screenshots pro Größe

#### 8.2 App Description

**Promotional Text** (170 Zeichen, editierbar nach Release):
```
Analysieren Sie Ihre Hammer-Würfe mit präziser Video-Analyse.
Vergleichen Sie Techniken, messen Sie Trajektorien und verbessern
Sie Ihre Performance!
```

**Description** (4000 Zeichen max):
```markdown
HammerTrack ist die ultimative Video-Analyse-App für Hammerwerfer!

FEATURES:
• Video-Analyse: Laden Sie Ihre Wurf-Videos und analysieren Sie die Trajektorie
• Dual-Vergleich: Vergleichen Sie zwei Videos gleichzeitig Side-by-Side
• Geschwindigkeitskontrolle: Zeitlupe und Zeitraffer für detaillierte Analyse
• Zoom & Pan: Fokussieren Sie auf wichtige Bewegungsdetails
• Trajectory Tracking: Automatische Erkennung der Hammer-Flugbahn

IDEAL FÜR:
✓ Athleten: Verbessern Sie Ihre Technik durch visuelle Analyse
✓ Trainer: Analysieren Sie Schüler-Würfe und geben Sie präzises Feedback
✓ Teams: Vergleichen Sie verschiedene Wurftechniken

TECHNOLOGIE:
• Offline-Verarbeitung: Keine Internet-Verbindung nötig
• Lokale Speicherung: Ihre Videos bleiben auf Ihrem Gerät
• Schnelle Analyse: Optimiert für iOS Performance

Verbessern Sie Ihre Wurftechnik mit HammerTrack!
```

#### 8.3 Keywords (100 Zeichen max)

```
hammer throw,athletics,video analysis,sports,training,trajectory,tracking,comparison,slow motion
```

**Tipp**: Keine Leerzeichen nach Kommas (spart Zeichen)!

#### 8.4 Support & Marketing URLs

```
Support URL: [Ihre Website oder GitHub Issues]
Marketing URL: [Optional, Ihre Produkt-Website]
```

Falls keine Website vorhanden:
```
Support URL: mailto:ihr-email@example.com
```

#### 8.5 App Review Information

**WICHTIG für Review-Prozess!**

```yaml
Contact Information:
  First Name: [Ihr Vorname]
  Last Name: [Ihr Nachname]
  Phone: +49 [Ihre Nummer]
  Email: [Ihre Email]

Demo Account: No (nicht benötigt)

Notes:
"Diese App analysiert Hammer-Wurf Videos offline auf dem Gerät.
Keine Server-Kommunikation. Zum Testen: Videos aus Fotobibliothek
auswählen und analysieren."
```

#### 8.6 Version Information

```yaml
Version Number: 1.0.0
Copyright: 2025 [Ihr Name/Firma]
```

---

## Phase 5: Build hochladen

### Schritt 9: Upload über Xcode

**Zurück zu Xcode Organizer:**

1. Archive auswählen
2. **Distribute App** Button rechts
3. **App Store Connect** auswählen
4. **Upload** auswählen (NICHT "Export")
5. **Next** → Distribution Options:
   ```
   ✓ Upload your app's symbols (empfohlen für Crash Reports)
   ✓ Manage Version and Build Number (automatisch)
   ```
6. **Signing**: Automatisch signieren
7. **Review**: App Informationen überprüfen
8. **Upload** → Warten (5-20 Minuten)

**Upload-Status in Xcode:**
- "Processing..." → Warten
- "Upload Successful" → Weiter zu App Store Connect

### Schritt 10: Build in App Store Connect auswählen

1. Zurück zu https://appstoreconnect.apple.com/
2. **My Apps** → **HammerTrack**
3. **Prepare for Submission**
4. **Build Section** → **Plus Button (+)**
5. Warten, bis Build erscheint (kann 10-60 Minuten dauern!)

**Status-Check:**
- **Processing**: Warten, Apple verarbeitet noch
- **Invalid Binary**: Fehler, neue Build nötig
- **Ready to Submit**: ✅ Kann ausgewählt werden

---

## Phase 6: Submission

### Schritt 11: Exportkontrolle

**WICHTIG für US-Export-Richtlinien:**

```yaml
Export Compliance:
  "Does your app use encryption?"

Antwort: No (falls Sie keine eigene Verschlüsselung implementiert haben)
```

**Hinweis**: Standard HTTPS-Kommunikation zählt NICHT als Export-relevante Verschlüsselung.

### Schritt 12: Content Rights

```yaml
Advertising Identifier (IDFA):
  "Does this app use the Advertising Identifier (IDFA)?"

Antwort: No (falls Sie keine Werbung eingebunden haben)
```

### Schritt 13: Finale Prüfung

**Checkliste vor Submission:**

```
✓ Alle Screenshots hochgeladen (3-5 pro Gerät)
✓ App Description ausgefüllt
✓ Keywords gesetzt
✓ Support URL angegeben
✓ App Review Information ausgefüllt
✓ Build ausgewählt
✓ Export Compliance beantwortet
✓ Version Number korrekt (1.0.0)
✓ Pricing & Availability konfiguriert
```

### Schritt 14: Submit for Review

1. **Save** oben rechts (Änderungen speichern)
2. **Submit for Review** Button
3. **Bestätigen**

**🎉 Geschafft! App ist eingereicht!**

---

## Phase 7: Review-Prozess

### Was passiert jetzt?

**Timeline:**

```
1. Waiting for Review (1-3 Tage)
   ↓
2. In Review (wenige Stunden bis 2 Tage)
   ↓
3a. Approved → Ready for Sale ✅
   ODER
3b. Rejected → Feedback lesen → Fixes → Re-Submit
```

### Status-Tracking

**App Store Connect Notifications:**
- Email bei Status-Änderungen
- Push Notifications in App Store Connect App (iOS)

**Status-Bedeutungen:**

| Status | Bedeutung | Aktion |
|--------|-----------|--------|
| Waiting for Review | In Queue | Warten |
| In Review | Apple testet | Warten |
| Pending Developer Release | Approved, manueller Release | **Release Button drücken!** |
| Ready for Sale | Live im App Store | 🎉 |
| Rejected | Abgelehnt | Feedback lesen |

---

## Direkter Release (kein TestFlight)

### Schritt 15: Release konfigurieren

**Option während Submission:**

```yaml
Version Release:
  → "Automatically release this version" (empfohlen für v1.0.0)

  ODER

  → "Manually release this version" (für kontrollierten Launch)
```

**Empfehlung**: Automatischer Release für erste Version.

### Was wenn Rejected?

**Häufige Gründe für Rejection:**

1. **Guideline 2.1 - App Completeness**
   - App stürzt ab oder ist unvollständig
   - **Lösung**: Bugs fixen, neue Build hochladen

2. **Guideline 4.0 - Design**
   - UI-Fehler, schlechte UX
   - **Lösung**: UI verbessern

3. **Guideline 5.1.1 - Privacy**
   - Fehlende Privacy-Informationen
   - **Lösung**: Privacy Policy hinzufügen

4. **Guideline 2.3.10 - Accurate Metadata**
   - Screenshots nicht repräsentativ
   - **Lösung**: Echte App-Screenshots verwenden

**Re-Submission nach Rejection:**
1. Feedback in App Store Connect lesen
2. Fixes implementieren
3. Neue Build erstellen (Build Number erhöhen!)
4. Neue Build hochladen
5. Re-Submit for Review

---

## Post-Launch

### App ist Live! Was jetzt?

1. **App Store Link teilen**:
   ```
   https://apps.apple.com/app/id[IHRE_APP_ID]
   ```

2. **Monitoring**:
   - **App Store Connect**: Sales & Trends
   - **Xcode**: Crash Reports (Organizer → Crashes)

3. **Updates veröffentlichen**:
   - Neue Features entwickeln
   - **Version erhöhen** (z.B. 1.0.0 → 1.1.0)
   - **Build erhöhen**
   - Archive → Upload → Neue Version in App Store Connect

---

## Troubleshooting

### Problem: "No Accounts in Xcode"

**Lösung**:
1. Xcode → Preferences → Accounts
2. **Plus Button (+)** → Apple ID hinzufügen
3. Mit Apple Developer Account anmelden
4. Team sollte erscheinen

### Problem: "App uses non-exempt encryption"

**Lösung**:
- Info.plist eintragen:
  ```xml
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
  ```

### Problem: "Bundle identifier already in use"

**Lösung**:
1. Neuen Bundle Identifier in Xcode wählen
2. In App Store Connect neue App mit neuem Bundle ID erstellen

### Problem: "Build not appearing in App Store Connect"

**Wartezeit**: Bis zu 1 Stunde normal

**Falls länger**:
1. Email von Apple prüfen (Rejection wegen Processing)
2. Xcode Organizer → Crashes prüfen
3. Neue Build hochladen

---

## Checkliste: Quick Reference

### Pre-Submission:
- [ ] Apple Developer Account aktiv
- [ ] Bundle ID eindeutig
- [ ] Code Signing konfiguriert
- [ ] Version & Build Number gesetzt
- [ ] Archive erstellt

### App Store Connect:
- [ ] App erstellt
- [ ] 3-5 Screenshots hochgeladen
- [ ] Description ausgefüllt
- [ ] Keywords gesetzt
- [ ] Support URL angegeben
- [ ] App Review Information ausgefüllt
- [ ] Privacy-Informationen angegeben
- [ ] Build ausgewählt

### Submission:
- [ ] Export Compliance beantwortet
- [ ] IDFA beantwortet
- [ ] Release-Option gewählt
- [ ] Submit for Review gedrückt

### Post-Submission:
- [ ] Email-Benachrichtigungen aktiviert
- [ ] Status täglich prüfen
- [ ] Bei Rejection: Feedback lesen & fixen

---

## Hilfreiche Links

- **App Store Connect**: https://appstoreconnect.apple.com/
- **Apple Developer**: https://developer.apple.com/
- **App Review Guidelines**: https://developer.apple.com/app-store/review/guidelines/
- **Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/

---

## Support

Bei Fragen während des Prozesses:

1. **Apple Developer Forums**: https://developer.apple.com/forums/
2. **App Store Connect Help**: https://help.apple.com/app-store-connect/
3. **Stack Overflow**: Tag `app-store-connect` und `xcode`

---

**Viel Erfolg mit Ihrer App Store Submission!** 🚀
