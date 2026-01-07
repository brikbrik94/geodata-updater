# Geodata Updater

Dieses Repository enthält Skripte für eine OSM-Geodata-Pipeline:

- Download von Geofabrik-PBFs
- Optionaler Download der basemap.at VTPK (zeitbasiert)
- Merge zu einer Gesamtdatei
- Generierung von PMTiles via Planetiler (Docker)

## Installation / Setup

```bash
./install.sh
```

Hinweis: Auf Debian 13.x ist das Docker-CLI in einem separaten Paket (`docker-cli`).
Das Installationsskript installiert daher sowohl `docker.io` als auch `docker-cli`.

## Nutzung

```bash
/srv/scripts/start.sh
```

Die Einzelschritte können auch separat getestet werden:

```bash
/srv/scripts/run_download.sh
/srv/scripts/run_merge.sh
/srv/scripts/run_pmtiles.sh
```

Optionaler ORS-Graphenbuild:

```bash
/srv/scripts/start.sh --rebuild-ors
```

### basemap.at Download (VTPK)

Der Download erfolgt über `scripts/download_basemap.sh` von:
`https://cdn.basemap.at/offline/bmapv_vtpk_3857.vtpk`.

Die Datei wird nur neu geladen, wenn sie älter als 2 Jahre ist. Zielpfad:
`/srv/build/basemap-at/src/bmapv_vtpk_3857.vtpk` (anpassbar via `BASEMAP_OUTPUT_DIR`).

### basemap.at Contours (VTPK)

Für Höhenlinien gibt es `scripts/download_basemap_contours.sh` mit dem Link:
`https://cdn.basemap.at/offline/bmapvhl_vtpk_3857.vtpk`.

Der Download erfolgt nur, wenn die Datei noch nicht vorhanden ist. Ein erneuter
Download kann über `FORCE_DOWNLOAD=1` erzwungen werden. Zielpfad:
`/srv/build/basemap-at-contours/src/bmapvhl_vtpk_3857.vtpk` (anpassbar via `CONTOURS_OUTPUT_DIR`).

### style.json (PMTiles Stylesheet)

Lege dein `style.json` unter `styles/style.json` im Repo ab. Beim Installieren
wird die Datei nach `/srv/tiles/<tileset-id>/styles/<style-id>/style.json`
kopiert (Standard: `tileset-id=osm`, `style-id=osm`). Beim Build der PMTiles
wird am Ende geprüft, ob die Datei vorhanden ist.

### ORS-Graphen optional neu bauen

Beim manuellen Start in der CLI fragt das Script nach, ob die ORS-Graphen
neu gebaut werden sollen. Für automatische Runs kann die Option mitgegeben
werden, z. B. einmal im Monat:

```bash
/srv/scripts/start.sh --rebuild-ors
```

Der Graphenbuild wird durch `/srv/scripts/rebuild_ors_graphs.sh` ausgeführt.
Dieses Script ruft standardmäßig `/srv/ors/rebuild_graphs.sh` auf (falls vorhanden)
oder führt den Befehl aus, der in `ORS_REBUILD_CMD` angegeben ist.

Logs werden standardmäßig in `/var/log/osm_update.log` geschrieben (oder nach
`/srv/scripts/osm_update.log`, falls das Standardziel nicht beschreibbar ist).

## Voraussetzungen

- Linux mit `apt`
- Docker-Daemon laufend

## Verzeichnisse

- Skripte: `/srv/scripts`
- OSM Daten: `/srv/build/osm/src` (Downloads), `/srv/build/osm/merged` (Merge)
- Tilesets: `/srv/tiles/<tileset-id>`
- Assets: `/srv/assets`
- Build: `/srv/build/<tileset-id>`

## Ordnerstruktur (empfohlen)

```
/srv/
├── tiles/
│   ├── osm/
│   │   ├── pmtiles/
│   │   │   ├── at.pmtiles
│   │   │   └── at-plus.pmtiles
│   │   ├── tilejson/
│   │   │   ├── at.json
│   │   │   └── at-plus.json
│   │   └── styles/
│   │       ├── at-plus/
│   │       │   └── style.json
│   │       └── at/
│   │           └── style.json
│   ├── basemap-at/
│   │   ├── pmtiles/
│   │   │   └── basemap-at.pmtiles
│   │   ├── tilejson/
│   │   │   └── basemap-at.json
│   │   └── styles/
│   │       └── basemap-at/
│   │           └── style.json
│   ├── basemap-at-contours/
│   │   ├── pmtiles/
│   │   │   └── basemap-at-contours.pmtiles
│   │   ├── tilejson/
│   │   │   └── basemap-at-contours.json
│   │   └── styles/
│   │       └── basemap-at-contours/
│   │           └── style.json
│   └── overlays/
│       ├── pmtiles/
│       │   └── overlay-xyz.pmtiles
│       ├── tilejson/
│       │   └── overlay-xyz.json
│       └── styles/
│           └── overlay-xyz/
│               └── style.json
├── assets/
│   ├── fonts/
│   └── sprites/
├── ors/
│   └── (wie bisher)
├── build/
│   ├── osm/
│   │   ├── merged/
│   │   ├── src/
│   │   └── tmp/
│   ├── basemap-at/
│   │   ├── src/
│   │   └── tmp/
│   ├── basemap-at-contours/
│   │   ├── src/
│   │   └── tmp/
│   └── overlays/
│       ├── src/
│       └── tmp/
└── scripts/
```
