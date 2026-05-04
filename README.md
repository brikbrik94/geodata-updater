
# Geodata Updater

Eine automatisierte Pipeline für selbstgehostete Vektorkarten (PMTiles).
Das System fungiert als Orchestrator für externe Daten-Stacks (Plugins) und verwaltet das Deployment sowie die Bereitstellung von Styles, Fonts und Sprites.

## Features

- **Plugin-Architektur:** Datenverarbeitung (OSM, Basemap, OpenSkiMap) erfolgt in eigenständigen Repositories.
- **Zentrales Deployment:** Automatisches Kopieren von PMTiles, Styles und Assets aus den Plugins in den Web-Root.
- **Dynamisches Styling:** Automatisches Patching von Stylesheets mit korrekten URLs für PMTiles, Fonts und Sprites.
- **Inventar-Management:** Automatische Generierung einer Master-JSON (`endpoints_info.json`) für Web-Frontends.
- **Routing-Integration:** Unterstützung für OpenRouteService (ORS) Graph-Builds.

## Schnellstart

### 1. Installation
Initialisiere das System auf einem Debian/Ubuntu Server:

```bash
./install.sh
```

### 2. Externe Plugins konfigurieren
Füge die Pfade zu deinen Geodata-Repositories in `conf/external_repos.txt` hinzu. Jedes Plugin muss eine `dist/manifest.json` enthalten.

**Beispiel `conf/external_repos.txt`:**
```text
/mnt/geodata/geodata-osm
/mnt/geodata/geodata-basemap-at
```

### 3. Pipeline starten
Aktualisiert alle konfigurierten Plugins und führt das Deployment durch:

```bash
/srv/scripts/start.sh
```

## Dokumentation

Detaillierte technische Informationen:

- [📄 Technische Referenz](docs/TECHNICAL_DETAILS.md): Details zum Deployment-Prozess, Manifest-Standard und Asset-Management.
- [📂 Ordnerstruktur](docs/FOLDER_STRUCTURE.md): Detaillierte Übersicht der Verzeichnisse auf dem Server.
- [🔌 Plugin-Standard](docs/EXTERNAL_PLUGINS.md): Definition der `manifest.json` und der Sprite-Konventionen.

## Zentrale Komponenten (/srv/scripts/)

| Komponente | Beschreibung |
| :--- | :--- |
| `start.sh` | Haupt-Einstiegspunkt der Pipeline. |
| `run_external_updates.sh` | Triggert die `update.sh` in allen Plugins. |
| `run_deploy.sh` | Orchestriert das Deployment und die Inventar-Erstellung. |
| `run_inventory.py` | Generiert alle Inventar-Listen (Tiles, Sprites, Fonts). |
| `run_assets.sh` | Baut Fonts und Standard-Sprites (Maki/Temaki). |

## Voraussetzungen
- Linux (Debian/Ubuntu)
- Docker & Docker CLI
- Python 3, Node.js
