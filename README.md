# Geodata Updater

Dieses Repository enthält Skripte für eine OSM-Geodata-Pipeline:

- Download von Geofabrik-PBFs
- Merge zu einer Gesamtdatei
- Generierung von PMTiles via Planetiler (Docker)

## Installation

```bash
./install.sh
```

Hinweis: Auf Debian 13.x ist das Docker-CLI in einem separaten Paket (`docker-cli`).
Das Installationsskript installiert daher sowohl `docker.io` als auch `docker-cli`.

## Nutzung

```bash
/srv/scripts/update_map.sh
```

Logs werden standardmäßig in `/var/log/osm_update.log` geschrieben (oder nach
`/srv/scripts/osm_update.log`, falls das Standardziel nicht beschreibbar ist).

## Voraussetzungen

- Linux mit `apt`
- Docker-Daemon laufend

## Verzeichnisse

- Skripte: `/srv/scripts`
- OSM Daten: `/srv/osm`
- PMTiles: `/srv/pmtiles`
