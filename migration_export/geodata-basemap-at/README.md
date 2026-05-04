# Arbeitsauftrag: Externes Repository `geodata-basemap-at`

Dieses Dokument beschreibt den Aufbau des neuen externen Repositories für den kombinierten Basemap AT (Raster/Vektor) und Basemap Contours (Höhenlinien) Stack.

## Ziel
Auslagerung der österreichischen Behörden-Geodaten (basemap.at VTPK Dateien) in ein eigenständiges Plugin-Repository. Beide Datensätze werden hier zusammengefasst, da sie eine identische Verarbeitungskette (VTPK -> MBTiles -> PMTiles) aufweisen.

## Verzeichnisstruktur (Ziel)
```text
geodata-basemap-at/
├── update.sh                 # Haupt-Einsprungspunkt (koordiniert Download, Extraktion & Konvertierung)
├── scripts/
│   ├── download.sh           # Logik für basemap & contours (mit Altersprüfung)
│   └── convert.sh            # Logik für VTPK -> PMTiles Konvertierung
└── dist/                     # Das fertige Ausgabeverzeichnis (dist-Ordner)
    ├── manifest.json         # Steuerung für das Deployment
    ├── pmtiles/              # Beinhaltet basemap-at.pmtiles und basemap-at-contours.pmtiles
    ├── styles/               # Extrahierte Styles (z.B. basemap-at-root.json)
    └── assets/
        └── sprites/          # Extrahierte Sprites aus den VTPKs
```

## Migration: Zu übernehmende Skripte & Logik
Folgende Skripte dienen als Vorlage:
1.  `scripts/download_basemap.sh` & `scripts/download_basemap_contours.sh`: Download via `aria2c`.
2.  `scripts/convert_basemap_at_pmtiles.sh` & `scripts/convert_basemap_at_contours_pmtiles.sh`: Komplette Konvertierungskette.

### Wichtige Abhängigkeiten (External Tools)
Die Verarbeitung erfordert spezialisierte Programme, die im Update-Skript automatisch geladen oder bereitgestellt werden müssen:

1.  **vtpk2mbtiles** (BergWerkGIS): Konvertiert die proprietäre ESRI-VTPK-Ordnerstruktur (nach dem Entpacken) in eine Standard-MBTiles-Datenbank.
    -   *Repo:* [https://github.com/BergWerkGIS/vtpk2mbtiles](https://github.com/BergWerkGIS/vtpk2mbtiles)
    -   *Besonderheit:* Benötigt .NET Core Runtime (bzw. entsprechende Umgebungsvariablen).
2.  **go-pmtiles** (Protomaps): Wandelt das MBTiles-Zwischenformat verlustfrei in das finale, web-optimierte PMTiles-Format (v3) um.
    -   *Repo:* [https://github.com/protomaps/go-pmtiles](https://github.com/protomaps/go-pmtiles)
3.  **aria2c**: Robuster Downloader für die großen VTPK Dateien.
4.  **unzip**: Zum Entpacken der `.vtpk` Archive (die eigentlich ZIP-Dateien sind).

### Spezielle Codeteile (Fixes & Fallstricke)
-   **Asset Extraktion (Styles & Sprites):** Die VTPK Dateien enthalten bereits fertige Stylesheets (`p12/resources/styles/root.json`) und Sprites (`p12/resources/sprites/`). Diese **müssen** während der Konvertierung extrahiert und in den `dist/` Ordner kopiert werden.
-   **.NET Umgebung:** Für `vtpk2mbtiles` muss zwingend `export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` gesetzt sein.
-   **Kategorisierung:** Basemap AT ist eine Grundkarte (`type: basemap`), während die Contours (Höhenlinien) ein Overlay sind (`type: overlay`).

## Technische Referenz (Code-Snippets)

### 1. Altersprüfung & Download
```bash
TWO_MONTHS_SECONDS=$((60 * 60 * 24 * 60))
if [ ! -f "$VTPK" ] || [ $(( $(date +%s) - $(stat -c %Y "$VTPK") )) -ge "$TWO_MONTHS_SECONDS" ]; then
    aria2c -x16 -s16 -c -d "$DIR" -o "$FILE" "$URL"
fi
```

### 2. VTPK Konvertierungsschritte (Detailliert)
Der Prozess muss in dieser exakten Reihenfolge erfolgen:

1.  **Entpacken (`unzip`):** Die VTPK-Datei muss in ein temporäres Verzeichnis entpackt werden.
2.  **Asset-Sicherung (`cp`):** Styles (`root.json`) und Sprites aus dem entpackten `p12/resources/` Pfad in das `dist/` Verzeichnis kopieren.
3.  **MBTiles Erzeugung (`vtpk2mbtiles`):** Das Tool wird auf den **entpackten Ordner** angesetzt. Es erzeugt eine `.mbtiles` Datei.
    *   *Kommando:* `./vtpk2mbtiles <Entpackter_Ordner> <Output.mbtiles> false`
4.  **PMTiles Konvertierung (`pmtiles convert`):** Die MBTiles-Datei wird in PMTiles umgewandelt.
    *   *Kommando:* `./pmtiles convert <Input.mbtiles> <Output.pmtiles>`

```bash
# Beispielhafter Ablauf:
unzip -q "$VTPK" -d "$TMP_EXTRACT"
cp -f "$TMP_EXTRACT/p12/resources/styles/root.json" "dist/styles/basemap-at.json"
cp -r "$TMP_EXTRACT/p12/resources/sprites/" "dist/assets/sprites/basemap-at"

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
./vtpk2mbtiles "$TMP_EXTRACT" "$OUT_MBTILES" false
./pmtiles convert "$OUT_MBTILES" "$OUT_PMTILES"
```

## Output (dist/ Verzeichnis)
Das Manifest definiert beide Datensätze und die zugehörigen Ressourcen.

```json
{
  "version": "1.0",
  "project": "Basemap AT & Contours",
  "generated_at": "2026-04-10T00:00:00Z",
  "datasets": [
    {
      "id": "basemap-at",
      "type": "basemap",
      "source": "basemap-at",
      "name": "Basemap AT Vektor",
      "style_path": "styles/basemap-at.json",
      "pmtiles_path": "pmtiles/basemap-at.pmtiles",
      "sprite_id": "basemap-at"
    },
    {
      "id": "basemap-at-contours",
      "type": "overlay",
      "source": "basemap-at",
      "name": "Basemap AT Höhenlinien",
      "pmtiles_path": "pmtiles/basemap-at-contours.pmtiles"
    }
  ],
  "resources": {
    "sprites": [
      {
        "id": "basemap-at",
        "path": "assets/sprites/basemap-at"
      }
    ]
  }
}
```
