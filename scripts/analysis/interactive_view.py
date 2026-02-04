#!/usr/bin/env python3
"""
Interaktives, zoombares Koordinatensystem für HammerTrack-Analyse
Zeigt ALLE detektierten Punkte und Umkehrpunkte
"""

import plotly.graph_objects as go
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

# Umkehrpunkte aus dem Log
turning_points = [
    {"frame": 0, "x": 0.782, "y": 0.399, "type": "START"},
    {"frame": 16, "x": 0.242, "y": 0.648, "type": "MINIMUM"},
    {"frame": 32, "x": 0.914, "y": 0.393, "type": "MAXIMUM"},
    {"frame": 47, "x": 0.313, "y": 0.650, "type": "MINIMUM"},
    {"frame": 62, "x": 0.237, "y": 0.517, "type": "MAXIMUM"},
    {"frame": 78, "x": 0.067, "y": 0.597, "type": "MINIMUM"},
    {"frame": 96, "x": 0.977, "y": 0.546, "type": "MAXIMUM"},
]

# === CSV PARSEN ===
lines = csv_data.strip().split('\n')[1:]
data_points = []

for line in lines:
    parts = line.split(',')
    frame = int(parts[0])
    x = float(parts[1])
    y = float(parts[2])
    data_points.append({'frame': frame, 'x': x, 'y': y})

# Nach Frame sortieren
data_points.sort(key=lambda p: p['frame'])

# Extrahiere Arrays
frames = [p['frame'] for p in data_points]
x_coords = [p['x'] for p in data_points]
y_coords = [1 - p['y'] for p in data_points]  # Y-Flip

print(f"📊 {len(data_points)} Punkte geladen")

# === PLOTLY INTERAKTIVES DIAGRAMM ===
fig = go.Figure()

# Alle Punkte als Linie
fig.add_trace(go.Scatter(
    x=x_coords,
    y=y_coords,
    mode='lines+markers',
    name='Trajektorie',
    line=dict(color='lightgray', width=2),
    marker=dict(size=6, color='lightblue', line=dict(width=1, color='gray')),
    text=[f"Frame {f}" for f in frames],
    hovertemplate='<b>Frame %{text}</b><br>X: %{x:.3f}<br>Y: %{y:.3f}<extra></extra>'
))

# Umkehrpunkte
tp_colors = {'START': 'gold', 'MINIMUM': 'cyan', 'MAXIMUM': 'magenta'}
tp_symbols = {'START': 'circle', 'MINIMUM': 'triangle-down', 'MAXIMUM': 'triangle-up'}

for i, tp in enumerate(turning_points):
    fig.add_trace(go.Scatter(
        x=[tp['x']],
        y=[1 - tp['y']],
        mode='markers',
        name=f"TP{i} ({tp['type']})",
        marker=dict(
            size=20,
            color=tp_colors[tp['type']],
            symbol=tp_symbols[tp['type']],
            line=dict(width=2, color='black')
        ),
        text=f"TP{i}<br>Frame {tp['frame']}<br>{tp['type']}",
        hovertemplate='<b>%{text}</b><br>X: %{x:.3f}<br>Y: %{y:.3f}<extra></extra>'
    ))

# Layout
fig.update_layout(
    title={
        'text': 'HammerTrack: Interaktive Analyse<br><sub>Zoomen: Mausrad | Verschieben: Linke Maustaste | Zurücksetzen: Doppelklick</sub>',
        'x': 0.5,
        'xanchor': 'center',
        'font': {'size': 18}
    },
    xaxis_title='X-Position (normalisiert)',
    yaxis_title='Y-Position (normalisiert, geflippt)',
    xaxis=dict(
        range=[-0.05, 1.05],
        constrain='domain',
        showgrid=True,
        gridwidth=1,
        gridcolor='lightgray'
    ),
    yaxis=dict(
        range=[-0.05, 1.05],
        scaleanchor='x',
        scaleratio=1,
        showgrid=True,
        gridwidth=1,
        gridcolor='lightgray'
    ),
    width=1400,
    height=1000,
    hovermode='closest',
    legend=dict(
        yanchor='top',
        y=0.99,
        xanchor='right',
        x=0.99,
        bgcolor='rgba(255,255,255,0.9)',
        bordercolor='black',
        borderwidth=1
    ),
    plot_bgcolor='white'
)

# Speichern als HTML
output_path = '/Users/merlinhummel/Documents/HammerTrack/interactive_analysis.html'
fig.write_html(output_path)

print(f"✅ Interaktive Visualisierung gespeichert: {output_path}")
print(f"📍 {len(turning_points)} Umkehrpunkte markiert")
print("\n🔍 ANLEITUNG:")
print("   • Öffne die HTML-Datei im Browser")
print("   • Mausrad: Zoomen")
print("   • Linke Maustaste + Ziehen: Verschieben")
print("   • Doppelklick: Zurücksetzen")
print("   • Hover über Punkte: Details anzeigen")
print("\n💬 Bitte erkläre mir nun anhand dieser Visualisierung,")
print("   wie genau die Ellipsen gebildet werden sollen!")
