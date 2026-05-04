# Arbeitsauftrag: Externes Repository `geodata-osm`

Dieses Dokument beschreibt den Aufbau des neuen externen Repositories für den OSM-Stack, basierend auf dem `EXTERNAL_PLUGINS.md` Standard.

## Ziel
Auslagerung der OSM-Verarbeitung (Download, Merge, Planetiler-Konvertierung) aus dem Haupt-Geodata-Updater in ein eigenständiges Plugin-Repository.

## Verzeichnisstruktur (Ziel)
```text
geodata-osm/
├── update.sh                 # Haupt-Einsprungspunkt (koordiniert den gesamten Ablauf)
├── scripts/
│   ├── download.sh           # Logik für aria2c Download & MD5 Check
│   ├── merge.sh              # Logik für osmium merge
│   ├── convert.sh            # Logik für planetiler (Docker)
│   └── planetiler_follow.py  # Monitoring des Fortschritts (Python)
├── sources/                  # Definitionen der Regionen (.txt Dateien mit PBF-URLs)
├── styles/                   # Stylesheets (Vorlage: osm-style.json)
└── dist/                     # Das fertige Ausgabeverzeichnis (dist-Ordner)
    ├── manifest.json         # Steuerung für das Deployment
    ├── pmtiles/              # Beinhaltet die generierten PMTiles Dateien
    └── styles/               # Beinhaltet die style.json Dateien
```

## Migration: Zu übernehmende Skripte & Logik
Folgende aktuelle Skripte dienen als Vorlage:
1.  `scripts/download_osm.sh`: Nutzt `aria2c` und prüft MD5. Verarbeitet `.txt` Dateien aus einem `sources/` Ordner.
2.  `scripts/run_merge.sh`: Merged mehrere PBFs basierend auf `.list` Dateien via `osmium`.
3.  `scripts/convert_osm_pmtiles.sh`: Führt `ghcr.io/onthegomap/planetiler` via Docker aus.
4.  `scripts/planetiler_follow.py`: Unverzichtbar für das Monitoring des Java-Build-Prozesses.

### Wichtige Abhängigkeiten (Dependencies)
-   **aria2c**: Für parallele Downloads und effiziente HTTP-Prüfungen.
-   **osmium-tool**: Zum Mergen und vor allem zur Validierung der PBF-Dateien.
-   **docker**: Planetiler wird als Container ausgeführt.
-   **python3**: Wird für das Monitoring (`planetiler_follow.py`) benötigt.

### Spezielle Codeteile (Fixes & Fallstricke)
-   **PBF-Integritätsprüfung:** Bevor gemerged wird, muss die Datei mit `osmium fileinfo` und `osmium cat -f opl` auf Integrität geprüft werden, da Planetiler bei korrupten PBFs erst sehr spät abbricht.
-   **Ressourcen:** Planetiler benötigt für manche Features (Wikidata, Elevation) Internetzugriff oder vorab geladene Daten (`--download=true`).

## Stylesheets
Das Plugin muss seine eigene `osm-style.json` (Vorlage aus dem Haupt-Repo) mitbringen. 
- **Wichtig:** Im Stylesheet sollten die URLs für `sprite`, `glyphs` und `sources` so vorbereitet sein, dass sie vom `update_stylesheets.py` des Updaters automatisch auf die finale Ziel-URL gepatcht werden können.

## Technische Referenz (Code-Snippets)

### 1. PBF-Validierung
```bash
# Header Check
osmium fileinfo "$pbf" >/dev/null 2>&1
# Stream Check (zuverlässige Erkennung von Dekompressionsfehlern)
osmium cat -f opl "$pbf" >/dev/null 2>&1
```

### 2. Osmium Merge
```bash
# PBF_INPUTS ist ein Array von Pfaden
osmium merge "${PBF_INPUTS[@]}" -o "$TARGET_FILE" --overwrite
```

### 3. Planetiler Docker Aufruf
```bash
docker run --rm \
  -v "$INPUT_DIR":/in:ro \
  -v "$OUTPUT_DIR":/out \
  ghcr.io/onthegomap/planetiler:latest \
  --osm-path="/in/$(basename "$pbf_file")" \
  --output="/out/$PMTILES_NAME" \
  --force \
  --download=true
```

## Output (dist/ Verzeichnis)
Das Manifest beschreibt die fertigen Artefakte nach der neuen Konvention.

```json
{
  "version": "1.0",
  "project": "OSM Basiskarte",
  "generated_at": "2026-04-10T00:00:00Z",
  "datasets": [
    {
      "id": "at",
      "type": "basemap",
      "source": "osm",
      "name": "OSM Österreich",
      "style_path": "styles/osm-style.json",
      "pmtiles_path": "pmtiles/at.pmtiles"
    }
  ]
}
```
