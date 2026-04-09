# Externer Plugin-Standard (manifest.json)

Dieses Dokument beschreibt den Standard für externe Repositories ("Plugins"), die automatisch in die Geodata-Pipeline eingebunden werden können.

## 1. Verzeichnisstruktur
Ein externes Repository muss seine fertigen Artefakte in einem Verzeichnis namens `dist/` ablegen.

```text
mein-overlay-repo/
├── dist/
│   ├── manifest.json         # Pflicht: Beschreibt den Inhalt
│   ├── pmtiles/              # PMTiles Dateien
│   ├── styles/               # Stylesheets (style.json)
│   └── assets/               # Sprites und Fonts
└── update.sh                 # Optional: Skript zum Aktualisieren der Daten
```

## 2. Die Datei manifest.json
Das Manifest im Root von `dist/` steuert den Deployment-Prozess.

### Beispiel Struktur
```json
{
  "version": "1.0",
  "project": "Mein Spezial-Overlay",
  "tileset": "overlays", 
  "generated_at": "2026-04-09T08:00:00Z",
  "datasets": [
    {
      "id": "meine-karte",
      "name": "Meine Spezialkarte",
      "style_path": "styles/style.json",
      "pmtiles_path": "pmtiles/data.pmtiles"
    }
  ],
  "resources": {
    "sprites": [
      {
        "id": "mein-sprite",
        "path": "assets/sprites/mein-sprite"
      }
    ],
    "fonts": [
      {
        "id": "MeineSchrift",
        "path": "assets/fonts/MeineSchrift"
      }
    ]
  }
}
```

### Felder im Detail
- **`tileset`**: Bestimmt die Kategorie im Zielsystem.
  - `osm`, `basemap-at` -> Grundkarten
  - `overlays` -> Overlays (Standard)
- **`datasets`**: Ein Array von Karten-Definitionen.
  - `id`: Eindeutiger Bezeichner (wird Teil der URL).
  - `name`: Anzeigename des Datensatzes.
  - `style_path`: Relativer Pfad zur `style.json` innerhalb von `dist/`.
  - `pmtiles_path`: Relativer Pfad zur `.pmtiles` Datei innerhalb von `dist/`.
  - `sprite_id`: (Optional) ID des zu verwendenden Spritesets (muss unter `resources.sprites` definiert sein). Überschreibt Standard-Mappings.
- **`resources`**: Optionale zusätzliche Assets.
  - `sprites`: Kopiert den `path` nach `/srv/assets/sprites/<id>/`.
  - `fonts`: Kopiert den `path` nach `/srv/assets/fonts/<id>/`.

### Abwärtskompatibilität
Der Updater unterstützt für eine Übergangszeit auch:
- `overlays` (Array) anstelle von `datasets`.
- `sprite_url` anstelle von `path` innerhalb der Sprites-Ressourcen.

## 3. Update Hook
Wenn im Root des Repositories ein ausführbares Skript namens `update.sh` oder `build.sh` liegt, wird dieses von der Haupt-Pipeline aufgerufen, bevor das Deployment startet. Dies erlaubt es dem Plugin, seine Daten selbstständig aktuell zu halten.
