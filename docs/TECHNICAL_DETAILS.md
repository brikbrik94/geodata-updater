# Technische Referenz (Geodata Updater)

## 1. Plugin-Konzept (External Repos)

Der Geodata-Updater fungiert als Orchestrator. Die eigentliche Datenverarbeitung (Download, Merge, Konvertierung) findet in eigenständigen Repositories ("Plugins") statt.

- **Konfiguration:** `conf/external_repos.txt` enthält die absoluten Pfade zu den Plugins auf dem Server (z.B. `/mnt/geodata/geodata-osm`).
- **Update-Hook:** Die Pipeline ruft in jedem Plugin die `update.sh` auf (falls vorhanden und ausführbar).
- **Deployment-Standard:** Plugins stellen ihre Artefakte im Ordner `dist/` bereit und beschreiben diese in der `manifest.json`. Details siehe [📄 Plugin-Standard](EXTERNAL_PLUGINS.md).

## 2. Deployment-Prozess (Workflow)

Die Pipeline (`start.sh`) führt folgende Schritte nach dem Bau der Plugin-Daten aus:

### A. Deployment-Phasen (`run_deploy.sh`)
1. **Externes Deployment:** `deploy_external.py` scannt alle Plugins, kopiert PMTiles, Styles und Assets in den Map-Root.
2. **Inventar-Erstellung:** `run_inventory.py` orchestriert die Erstellung der Inventare:
   - `inventory/tiles.py`: Scannt `/srv/tiles` nach PMTiles und Styles.
   - `inventory/sprites.py`: Scannt `/srv/assets/sprites`.
   - `inventory/fonts.sh`: Scannt `/srv/assets/fonts`.
   - `inventory/aggregate.py`: Aggregiert alles zur `endpoints_info.json`.
3. **Stylesheet-Update:** `update_stylesheets.py` patcht alle `style.json` Dateien mit absoluten URLs basierend auf den Inventar-Daten.

### B. Asset-Management (`run_assets.sh`)
- **Fonts:** Werden durch `install_fonts.sh` aus dem OpenMapTiles Repository generiert.
- **Sprites:** `build_sprites.sh` nutzt Docker (`spreet`), um die globalen Maki- und Temaki-Sets zu bauen.

## 3. Spezial-Komponenten

### OpenRouteService (ORS)
- **Skript:** `scripts/ors/rebuild_ors_graphs.sh` (Manueller Aufruf empfohlen).
- **Funktion:** Kopiert eine fertige PBF-Datei aus einem Plugin (z.B. OSM) in den ORS-Datenordner und triggert den Neubau der Graphen.

### Wartung (Cleanup)
- **Skript:** `scripts/tools/cleanup_tiles.py`
- **Funktion:** Vergleicht den Stand in `/srv/tiles` mit den aktuell konfigurierten Plugins und bietet an, verwaiste Dateien (von alten oder gelöschten Plugins) zu entfernen.

## 4. Administrations-Befehle

| Befehl | Zweck |
| :--- | :--- |
| `/srv/scripts/start.sh` | Standard-Lauf (Update Plugins + Deploy). |
| `/srv/scripts/run_assets.sh` | Initialer Bau oder Update von Fonts & Sprites. |
| `/srv/scripts/tools/deploy_scripts.sh` | Synchronisiert Skripte aus dem Git-Repo nach `/srv/scripts`. |
| `/srv/scripts/tools/cleanup_tiles.py` | Entfernt alte Kartenleichen. |
