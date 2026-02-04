#!/usr/bin/env python3
"""
Korrekte Ellipsen-Erkennung basierend auf X-Achsen-Richtungsänderungen
Jeder Umkehrpunkt ist gleichzeitig Ende einer Ellipse und Start der nächsten
"""

import matplotlib.pyplot as plt
import numpy as np

# === DATEN AUS DEM LOG ===
csv_data = """Frame,X,Y
0,0.782227,0.399475
2,0.746582,0.417328
3,0.715820,0.433258
9,0.460938,0.545868
10,0.420410,0.562073
11,0.383789,0.577316
12,0.351807,0.592422
13,0.323730,0.603683
14,0.299561,0.615494
15,0.280518,0.624146
16,0.262939,0.632660
17,0.249023,0.640076
18,0.238525,0.645981
19,0.231445,0.649620
20,0.229736,0.650581
21,0.232422,0.650719
22,0.241577,0.648453
23,0.258545,0.643166
24,0.281738,0.634857
25,0.313232,0.623596
26,0.352539,0.608627
27,0.400391,0.591736
28,0.454102,0.570038
29,0.515137,0.546967
30,0.576172,0.522659
31,0.645020,0.496429
32,0.710449,0.470886
33,0.772461,0.446991
34,0.828125,0.426117
35,0.872070,0.410461
36,0.903320,0.398926
37,0.917969,0.393158
38,0.913574,0.393433
39,0.895020,0.401398
40,0.859863,0.409912
41,0.813965,0.423920
42,0.754395,0.441498
43,0.693359,0.458801
48,0.379883,0.548065
49,0.335693,0.564957
50,0.298340,0.581436
51,0.268799,0.596130
52,0.243408,0.610275
53,0.228516,0.623047
54,0.223877,0.636230
55,0.235352,0.645088
56,0.264648,0.650169
57,0.312744,0.649551
58,0.378662,0.643166
59,0.461426,0.630051
60,0.555176,0.611786
61,0.658691,0.588303
62,0.762695,0.558228
63,0.858398,0.525955
64,0.936035,0.495331
65,0.983398,0.467590
66,0.991699,0.442871
67,0.977539,0.429962
68,0.919434,0.423370
69,0.835938,0.424194
70,0.718750,0.431610
73,0.342285,0.490936
74,0.236694,0.517303
75,0.156128,0.547791
76,0.111389,0.578278
77,0.108398,0.607666
78,0.157349,0.633209
79,0.247437,0.648933
80,0.386230,0.653191
81,0.552734,0.644127
82,0.722656,0.622498
83,0.867188,0.589539
84,0.978027,0.550674
87,0.939453,0.433807
89,0.645996,0.405243
91,0.302246,0.446716
92,0.168945,0.487366
93,0.082642,0.539688
94,0.066772,0.597229
95,0.134033,0.653122
96,0.275391,0.693977
97,0.473633,0.712551
98,0.685059,0.701462
99,0.863770,0.664658
100,0.972168,0.608353
102,0.936035,0.482422
103,0.788086,0.437103
106,0.202148,0.449188
107,0.067017,0.503845
108,0.015495,0.575668
109,0.070435,0.651405
110,0.220947,0.713169
111,0.447998,0.746832
112,0.687988,0.740704
113,0.880859,0.696312
114,0.978027,0.626617
115,0.976562,0.546417
116,0.871094,0.475281
120,0.077148,0.467041
121,0.005993,0.544907
122,0.032196,0.637329
123,0.183105,0.720413
124,0.423096,0.771199
125,0.684570,0.774251
126,0.889648,0.736549
127,0.989746,0.663834
128,0.987305,0.575256
129,0.879883,0.491760
130,0.683105,0.429138
132,0.212402,0.415955
133,0.050018,0.478851
134,0.005936,0.578964"""

# === CSV PARSEN & SORTIEREN ===
lines = csv_data.strip().split('\n')[1:]
data_points = []

for line in lines:
    parts = line.split(',')
    frame = int(parts[0])
    x = float(parts[1])
    y = float(parts[2])
    data_points.append({'frame': frame, 'x': x, 'y': y})

# Nach Frame-Nummer sortieren
data_points.sort(key=lambda p: p['frame'])

print(f"📊 {len(data_points)} Punkte geladen (Frame {data_points[0]['frame']} → {data_points[-1]['frame']})")

# === UMKEHRPUNKT-ERKENNUNG ===
MIN_MOVEMENT = 0.015  # Schwellwert für signifikante Bewegung
MIN_FRAMES_BETWEEN = 10  # Mindestabstand zwischen Umkehrpunkten

turning_points = []
current_direction = None

# 1. Erster Punkt ist immer Startpunkt
turning_points.append({
    'index': 0,
    'frame': data_points[0]['frame'],
    'x': data_points[0]['x'],
    'y': data_points[0]['y'],
    'type': 'START'
})
print(f"\n🎯 Umkehrpunkt 0 (START): Frame {data_points[0]['frame']} bei ({data_points[0]['x']:.3f}, {data_points[0]['y']:.3f})")

# 2. Bestimme initiale Richtung
for i in range(1, min(5, len(data_points))):
    dx = data_points[i]['x'] - data_points[i-1]['x']
    if abs(dx) > MIN_MOVEMENT:
        current_direction = 1 if dx > 0 else -1
        print(f"   Initiale Richtung: {'rechts →' if current_direction > 0 else 'links ←'}")
        break

# 3. Finde alle Umkehrpunkte
frames_since_last_turn = 0
for i in range(1, len(data_points)):
    frames_since_last_turn += 1

    dx = data_points[i]['x'] - data_points[i-1]['x']

    if abs(dx) > MIN_MOVEMENT and frames_since_last_turn >= MIN_FRAMES_BETWEEN:
        new_direction = 1 if dx > 0 else -1

        if current_direction is not None and new_direction != current_direction:
            # Richtungswechsel erkannt!
            turning_points.append({
                'index': i-1,
                'frame': data_points[i-1]['frame'],
                'x': data_points[i-1]['x'],
                'y': data_points[i-1]['y'],
                'type': 'MAXIMUM' if current_direction > 0 else 'MINIMUM'
            })

            print(f"🔄 Umkehrpunkt {len(turning_points)-1}: Frame {data_points[i-1]['frame']} "
                  f"({data_points[i-1]['x']:.3f}, {data_points[i-1]['y']:.3f}) - "
                  f"{'MAXIMUM' if current_direction > 0 else 'MINIMUM'}")

            current_direction = new_direction
            frames_since_last_turn = 0

print(f"\n✅ Insgesamt {len(turning_points)} Umkehrpunkte gefunden")

# === ELLIPSEN BERECHNEN (3-PUNKT-ELLIPSEN) ===
# Jede Ellipse umfasst 3 Umkehrpunkte: TP(i) → TP(i+1) → TP(i+2)
# Der Winkel wird von TP(i) zu TP(i+2) gemessen!
# TP(i+2) wird dann zum Start der nächsten Ellipse (Überlappung)

ellipses = []
colors = ['#FF4444', '#44FF44', '#4444FF', '#FF44FF', '#44FFFF', '#FFFF44', '#FF8844']

print("\n🔍 Erstelle 3-Punkt-Ellipsen (mit Überlappung):")

# Gehe in 2er-Schritten: 0, 2, 4, 6, ...
# Jede Ellipse: TP(i) → TP(i+1) → TP(i+2)
ellipse_number = 1
for i in range(0, len(turning_points) - 2, 2):
    tp1 = turning_points[i]      # Start
    tp2 = turning_points[i + 1]  # Mitte
    tp3 = turning_points[i + 2]  # Ende (wird Start der nächsten)

    print(f"\n📐 Ellipse {ellipse_number}:")
    print(f"   TP{i} → TP{i+1} → TP{i+2}")
    print(f"   Frame {tp1['frame']} → {tp2['frame']} → {tp3['frame']}")
    print(f"   Position: ({tp1['x']:.3f}, {tp1['y']:.3f}) → ({tp2['x']:.3f}, {tp2['y']:.3f}) → ({tp3['x']:.3f}, {tp3['y']:.3f})")

    # Winkel berechnen: Von TP1 zu TP3!
    dx = tp3['x'] - tp1['x']
    dy = tp3['y'] - tp1['y']

    angle_rad = np.arctan2(abs(dy), abs(dx))
    angle_deg = angle_rad * 180.0 / np.pi

    # Richtung bestimmen (Y=0 ist oben)
    if tp1['y'] > tp3['y']:
        angle_deg = angle_deg  # Positiv = fällt nach oben
    else:
        angle_deg = -angle_deg  # Negativ = fällt nach unten

    print(f"   Winkel (TP{i} → TP{i+2}): {angle_deg:.2f}°")

    ellipse = {
        'number': ellipse_number,
        'start_frame': tp1['frame'],
        'end_frame': tp3['frame'],
        'start_index': tp1['index'],
        'end_index': tp3['index'],
        'mid_frame': tp2['frame'],
        'mid_index': tp2['index'],
        'start_x': tp1['x'],
        'start_y': tp1['y'],
        'mid_x': tp2['x'],
        'mid_y': tp2['y'],
        'end_x': tp3['x'],
        'end_y': tp3['y'],
        'angle': angle_deg,
        'color': colors[(ellipse_number - 1) % len(colors)],
        'tp_start': i,
        'tp_mid': i + 1,
        'tp_end': i + 2
    }

    ellipses.append(ellipse)
    ellipse_number += 1

print(f"\n✅ {len(ellipses)} Ellipsen gefunden")

average_angle = sum(e['angle'] for e in ellipses) / len(ellipses) if ellipses else 0
print(f"\n📊 Durchschnittlicher Winkel: {average_angle:.2f}°")

# === VISUALISIERUNG ===
fig, ax = plt.subplots(figsize=(16, 10))

# Extrahiere sortierte Koordinaten
frames = [p['frame'] for p in data_points]
x_coords = [p['x'] for p in data_points]
y_coords = [1 - p['y'] for p in data_points]  # Y-Flip

# Zeichne jede 3-Punkt-Ellipse als farbige Linie
for ellipse in ellipses:
    # Sammle alle Punkte dieser Ellipse
    ellipse_x = []
    ellipse_y = []

    for i, p in enumerate(data_points):
        if ellipse['start_index'] <= i <= ellipse['end_index']:
            ellipse_x.append(p['x'])
            ellipse_y.append(1 - p['y'])

    # Zeichne Ellipsen-Segment
    ax.plot(
        ellipse_x, ellipse_y,
        color=ellipse['color'],
        linewidth=5,
        alpha=0.85,
        zorder=4,
        label=f"Ellipse {ellipse['number']}: {ellipse['angle']:.2f}°"
    )

    # Zeichne Punkte
    ax.scatter(
        ellipse_x, ellipse_y,
        s=70,
        color=ellipse['color'],
        alpha=0.8,
        edgecolors='black',
        linewidth=1.5,
        zorder=5
    )

# Zeichne Umkehrpunkte
for i, tp in enumerate(turning_points):
    if tp['type'] == 'START':
        color = '#FFD700'
        marker = 'o'
        size = 500
    elif tp['type'] == 'MAXIMUM':
        color = '#FF1493'
        marker = '^'
        size = 400
    else:  # MINIMUM
        color = '#00CED1'
        marker = 'v'
        size = 400

    ax.scatter(
        tp['x'], 1 - tp['y'],
        s=size,
        color=color,
        marker=marker,
        edgecolors='black',
        linewidth=3,
        zorder=10,
        alpha=0.95
    )

    # Label
    label_offset = -0.07 if i % 2 == 0 else 0.07
    va = 'top' if i % 2 == 0 else 'bottom'

    ax.text(
        tp['x'], 1 - tp['y'] + label_offset,
        f"TP{i}\nF{tp['frame']}",
        ha='center', va=va,
        fontsize=10, fontweight='bold',
        bbox=dict(boxstyle='round,pad=0.5', facecolor='white', alpha=0.95, edgecolor='black', linewidth=2),
        zorder=11
    )

# Markiere Mittelpunkte der Ellipsen besonders
for ellipse in ellipses:
    mid_tp = turning_points[ellipse['tp_mid']]
    # Zeichne gestrichelte Linie von Start zu Ende (Winkel-Linie)
    ax.plot(
        [ellipse['start_x'], ellipse['end_x']],
        [1 - ellipse['start_y'], 1 - ellipse['end_y']],
        color=ellipse['color'],
        linewidth=2,
        linestyle=':',
        alpha=0.6,
        zorder=3
    )

# Layout
ax.set_xlim(-0.05, 1.05)
ax.set_ylim(-0.05, 1.05)
ax.set_xlabel('X-Position (normalisiert)', fontsize=13, fontweight='bold')
ax.set_ylabel('Y-Position (normalisiert, geflippt)', fontsize=13, fontweight='bold')
ax.set_title(f'HammerTrack: 3-Punkt-Ellipsen-Analyse\n{len(data_points)} Frames • {len(ellipses)} Ellipsen • {len(turning_points)} Umkehrpunkte',
             fontsize=15, fontweight='bold', pad=20)
ax.grid(True, alpha=0.3, linestyle='--')
ax.set_aspect('equal')

# Legende
ax.legend(loc='upper right', fontsize=11, framealpha=0.95, edgecolor='black')

# Info-Box
info_text = f"""3-Punkt-Ellipsen:
• {len(turning_points)} Umkehrpunkte gefunden
• {len(ellipses)} Ellipsen (je 3 Umkehrpunkte)
• Winkel: TP(i) → TP(i+2)
• TP(i+2) wird Start der nächsten Ellipse
• Durchschnittlicher Winkel: {average_angle:.2f}°
• Gestrichelte Linien = Winkel-Messung"""

ax.text(
    0.02, 0.98, info_text,
    transform=ax.transAxes,
    fontsize=11,
    verticalalignment='top',
    bbox=dict(boxstyle='round,pad=1', facecolor='lightgreen', alpha=0.9, edgecolor='black', linewidth=2),
    family='monospace'
)

plt.tight_layout()
output_path = '/Users/merlinhummel/Documents/HammerTrack/correct_ellipses.png'
plt.savefig(output_path, dpi=150, bbox_inches='tight')
print(f"\n✅ Visualisierung gespeichert: {output_path}")
