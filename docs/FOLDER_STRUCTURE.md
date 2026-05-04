# Detaillierte Ordnerstruktur (Server /srv)

Dies ist die aktuelle Struktur auf dem Map-Server, basierend auf der Plugin-Architektur (Stand 2026-04-17).

```text
/srv
├── assets
│   ├── fonts/             # Installierte Schriften (Noto Sans, etc.)
│   └── sprites/           # Standard-Icons (Maki, Temaki) und Plugin-Icons
├── scripts
│   ├── start.sh           # Einstieg (Update Plugins -> Deploy)
│   ├── setup.sh           # Initiales System-Setup
│   ├── run_external_updates.sh
│   ├── run_deploy.sh
│   ├── run_inventory.py   # Orchestrator für Inventarlisten
│   ├── run_assets.sh      # Baut Fonts und Sprites
│   ├── inventory/         # Skripte für tiles, sprites, fonts
│   ├── tools/             # Admin-Tools (cleanup, deploy_scripts)
│   ├── ors/               # OpenRouteService Logik
│   ├── archive/           # Obsolete interne Skripte
│   └── venv/              # Python Virtual Environment
├── tiles
│   ├── basemaps           # Struktur: pmtiles/, styles/, tilejson/
│   ├── overlays           # Struktur: pmtiles/, styles/, tilejson/
│   └── elevation          # Struktur: pmtiles/, tilejson/
├── info
│   ├── endpoints_info.json # Master-JSON für Web-Anwendungen
│   ├── tiles_inventory.json
│   ├── sprite_inventory.json
│   └── font_inventory.json
├── ors
│   ├── graphs/            # Gebaute Routing-Graphen
│   └── osm_file.pbf       # Eingabe für ORS (von Plugin geliefert)
├── conf
│   ├── external_repos.txt # Pfade zu den Plugins
│   └── sprite_mapping.json
└── styles                 # Master-Templates für Stylesheets
```

## Hauptverzeichnisse

- **scripts/**: Orchestriert den gesamten Ablauf. Skripte werden via `deploy_scripts.sh` aus dem Git-Repo synchronisiert.
- **tiles/**: Enthält die finalen PMTiles und Stylesheets, organisiert nach fachlichen Kategorien.
- **assets/**: Zentrale Bereitstellung von Schriften und Symbolen.
- **info/**: Metadaten und Inventare für APIs und Dashboards.
- **ors/**: Dediziertes Verzeichnis für den OpenRouteService (Routing-Daten).
