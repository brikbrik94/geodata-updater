# Arbeitsauftrag: Externes Repository `geodata-openskimap`

Dieses Dokument beschreibt den Aufbau des neuen externen Repositories für den OpenSkiMap-Stack, basierend auf dem `EXTERNAL_PLUGINS.md` Standard.

## Ziel
Auslagerung der OpenSkiMap-Verarbeitung (GPKG Download, ogr2ogr Extraktion, Tippecanoe Konvertierung) in ein eigenständiges Plugin-Repository.

## Verzeichnisstruktur (Ziel)
```text
geodata-openskimap/
├── update.sh                 # Haupt-Einsprungspunkt (koordiniert Download & Konvertierung)
├── scripts/
│   ├── download.sh           # Lädt das GeoPackage (.gpkg)
│   └── convert.sh            # OGR2OGR und Tippecanoe Logik
├── styles/
│   └── openskimap-style.json # Das Stylesheet (MapLibre Style)
├── assets/
│   └── sprites/
│       └── openskimap/       # Eigene Sprites für Ski-Symbole (sprite.json, sprite.png, etc.)
└── dist/                     # Das fertige Ausgabeverzeichnis (dist-Ordner)
    ├── manifest.json         # Steuerung für das Deployment
    ├── pmtiles/              # Beinhaltet die generierte PMTiles Datei
    ├── styles/               # Beinhaltet das Stylesheet
    └── assets/
        └── sprites/          # Beinhaltet das openskimap Sprite-Set
```

## Migration: Zu übernehmende Skripte & Logik
Folgende aktuelle Skripte dienen als Vorlage:
1.  `scripts/download_openskimap.sh`: Lädt die `openskidata.gpkg` via aria2c.
2.  `scripts/convert_openskimap_pmtiles.sh`: Extrahiert Layer und nutzt Tippecanoe.

### Wichtige Abhängigkeiten (External Tools)
-   **aria2c**: Nutzt `--conditional-get`, um nur bei echten Updates zu laden. [GitHub](https://github.com/aria2/aria2)
-   **gdal-bin (ogr2ogr)**: Zum Zerlegen des GeoPackage in einzelne Layer-Dateien (GeoJSONSeq). [Website](https://gdal.org/)
-   **tippecanoe**: Zur Erstellung der PMTiles aus den Layer-Dateien. [GitHub](https://github.com/felt/tippecanoe)

### Spezielle Codeteile (Fixes & Fallstricke)
-   **Layer-Namen (KRITISCH):** Damit das Stylesheet (`openskimap-style.json`) funktioniert, **MÜSSEN** die Layer im PMTiles exakt so benannt werden wie in der Quelle. Tippecanoe benennt Layer standardmäßig nach dem Dateinamen. Verwende die `-L` Syntax für ein explizites Mapping.
    -   *Erwartete Layer:* `ski_areas_point`, `ski_areas_multipolygon`, `lifts_linestring`, `runs_multipolygon`, `runs_linestring`.

## Technische Referenz (Code-Snippets)

### 1. Layer Extraktion (Exakte Layer-Namen)
```bash
ogr2ogr -f GeoJSONSeq areas_p.jsonseq    "$INPUT" ski_areas_point
ogr2ogr -f GeoJSONSeq areas_poly.jsonseq "$INPUT" ski_areas_multipolygon
ogr2ogr -f GeoJSONSeq lifts.jsonseq      "$INPUT" lifts_linestring
ogr2ogr -f GeoJSONSeq runs_poly.jsonseq  "$INPUT" runs_multipolygon
ogr2ogr -f GeoJSONSeq runs_line.jsonseq  "$INPUT" runs_linestring
```

### 2. Tippecanoe Aufruf (Layer-Mapping)
```bash
tippecanoe -o "dist/pmtiles/openskimap.pmtiles" --force \
  --minimum-zoom=0 --maximum-zoom=14 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  -L "ski_areas_point:areas_p.jsonseq" \
  -L "ski_areas_multipolygon:areas_poly.jsonseq" \
  -L "lifts_linestring:lifts.jsonseq" \
  -L "runs_multipolygon:runs_poly.jsonseq" \
  -L "runs_linestring:runs_line.jsonseq"
```

## Stylesheets & Assets
- **Stylesheet:** Das Repo muss die `openskimap-style.json` enthalten.
- **Sprites:** Da OpenSkiMap eigene Ski-Symbole benötigt, muss das Sprite-Set (zu finden unter `/srv/assets/sprites/openskimap/`) in den `assets/sprites/openskimap/` Ordner des Plugins kopiert werden.

## Output (dist/ Verzeichnis)
Das Manifest stellt sicher, dass das Sprite-Set ebenfalls deployed wird.

```json
{
  "version": "1.0",
  "project": "OpenSkiMap Overlay",
  "generated_at": "2026-04-10T00:00:00Z",
  "datasets": [
    {
      "id": "openskimap",
      "type": "overlay",
      "source": "openskimap",
      "name": "OpenSkiMap Pisten & Lifte",
      "style_path": "styles/openskimap-style.json",
      "pmtiles_path": "pmtiles/openskimap.pmtiles",
      "sprite_id": "openskimap"
    }
  ],
  "resources": {
    "sprites": [
      {
        "id": "openskimap",
        "path": "assets/sprites/openskimap"
      }
    ]
  }
}
```
