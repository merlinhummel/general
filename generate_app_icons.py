#!/usr/bin/env python3
import os
from PIL import Image
import json

# Pfade definieren
base_path = "/Users/merlinhummel/Documents/HammerTrack/Hammer Track/Assets.xcassets/AppIcon.appiconset"
source_image_path = os.path.join(base_path, "logo dark.png")
output_path = base_path

# Icon-Größen definieren (exakt wie im Screenshot)
icon_configs = [
    # iPhone Notification - 20pt
    {"idiom": "iphone", "size": "20x20", "scale": "2x", "filename": "icon-40x40.png"},
    {"idiom": "iphone", "size": "20x20", "scale": "3x", "filename": "icon-60x60.png"},
    
    # iPhone Settings - 29pt  
    {"idiom": "iphone", "size": "29x29", "scale": "2x", "filename": "icon-58x58.png"},
    {"idiom": "iphone", "size": "29x29", "scale": "3x", "filename": "icon-87x87.png"},
    
    # iPhone Spotlight - 40pt
    {"idiom": "iphone", "size": "40x40", "scale": "2x", "filename": "icon-80x80.png"},
    {"idiom": "iphone", "size": "40x40", "scale": "3x", "filename": "icon-120x120.png"},
    
    # iPhone App - 60pt
    {"idiom": "iphone", "size": "60x60", "scale": "2x", "filename": "icon-120x120-2.png"},
    {"idiom": "iphone", "size": "60x60", "scale": "3x", "filename": "icon-180x180.png"},
    
    # iPad Notification - 20pt
    {"idiom": "ipad", "size": "20x20", "scale": "1x", "filename": "icon-20x20.png"},
    {"idiom": "ipad", "size": "20x20", "scale": "2x", "filename": "icon-40x40-ipad.png"},
    
    # iPad Settings - 29pt
    {"idiom": "ipad", "size": "29x29", "scale": "1x", "filename": "icon-29x29.png"},
    {"idiom": "ipad", "size": "29x29", "scale": "2x", "filename": "icon-58x58-ipad.png"},
    
    # iPad Spotlight - 40pt
    {"idiom": "ipad", "size": "40x40", "scale": "1x", "filename": "icon-40x40-ipad-spot.png"},
    {"idiom": "ipad", "size": "40x40", "scale": "2x", "filename": "icon-80x80-ipad.png"},
    
    # iPad App - 76pt
    {"idiom": "ipad", "size": "76x76", "scale": "1x", "filename": "icon-76x76.png"},
    {"idiom": "ipad", "size": "76x76", "scale": "2x", "filename": "icon-152x152.png"},
    
    # iPad Pro App - 83.5pt
    {"idiom": "ipad", "size": "83.5x83.5", "scale": "2x", "filename": "icon-167x167.png"},
    
    # App Store
    {"idiom": "ios-marketing", "size": "1024x1024", "scale": "1x", "filename": "icon-1024x1024.png"}
]

# Contents.json erstellen
contents = {
    "images": icon_configs,
    "info": {
        "author": "xcode",
        "version": 1
    }
}

print("🎨 Generiere App Icons...")
print(f"📂 Quellbild: {source_image_path}")
print(f"📂 Ausgabeordner: {output_path}")
print("")

# Quellbild laden
try:
    source_image = Image.open(source_image_path)
    print(f"✅ Quellbild geladen: {source_image.size[0]}x{source_image.size[1]} Pixel")
    
    # In RGBA konvertieren für Transparenz-Support
    if source_image.mode != 'RGBA':
        source_image = source_image.convert('RGBA')
    
except Exception as e:
    print(f"❌ Fehler beim Laden des Quellbilds: {e}")
    exit(1)

# Alle benötigten Größen extrahieren
sizes_to_generate = set()
for config in icon_configs:
    filename = config["filename"]
    # Größe aus Dateinamen extrahieren
    size_str = filename.replace("icon-", "").replace(".png", "").split("-")[0]
    size = int(size_str.split("x")[0])
    sizes_to_generate.add((size, filename))

# Icons generieren
for size, filename in sizes_to_generate:
    filepath = os.path.join(output_path, filename)
    
    try:
        # Icon erstellen mit Antialiasing
        icon = source_image.resize((size, size), Image.Resampling.LANCZOS)
        
        # Als PNG speichern
        icon.save(filepath, "PNG", optimize=True)
        print(f"✅ Erstellt: {filename} ({size}x{size})")
            
    except Exception as e:
        print(f"❌ Fehler beim Erstellen von {filename}: {e}")

# Contents.json speichern
contents_path = os.path.join(output_path, "Contents.json")
try:
    with open(contents_path, 'w') as f:
        json.dump(contents, f, indent=2)
    print(f"\n✅ Contents.json aktualisiert")
except Exception as e:
    print(f"❌ Fehler beim Speichern von Contents.json: {e}")

print("\n🎉 Icon-Generierung abgeschlossen!")
print(f"📁 Alle Icons wurden in {output_path} gespeichert")
print("\n🔄 Nächster Schritt: Erstelle ein neues Archive in Xcode")
