# Refactoring nach Auslagerung der Stacks (ERLEDIGT)

Dieses Dokument listete die technischen Anpassungen auf, die nach der Migration auf die Plugin-Architektur durchgeführt werden sollten. Alle Punkte wurden erfolgreich umgesetzt.

## 1. Vereinheitlichung der Verzeichnisstruktur (ERLEDIGT)
- Alle Tilesets werden nun in die funktionalen Kategorien `/srv/tiles/basemaps/`, `/srv/tiles/overlays/` und `/srv/tiles/elevation/` deployed.
- Sonderlogik für spezifische Datenquellen wurde durch den Plugin-Standard (`manifest.json`) ersetzt.

## 2. Bereinigung der Deployment-Skripte (ERLEDIGT)
- `deploy_pmtiles.sh` und `deploy_stylesheets.sh` wurden archiviert.
- Das Deployment erfolgt nun ausschließlich über `deploy_external.py` (basierend auf Manifesten).
- `update_stylesheets.py` wurde modernisiert und bezieht alle Informationen (Sprites, Fonts, Datasets) direkt aus den Plugin-Manifesten.

## 3. Entfernung veralteter Konfigurations-Variablen (ERLEDIGT)
- Die `config.env` wurde bereinigt. Interne Build-Pfade für OSM, Basemap und Overlays wurden entfernt.
- `OSM_BUILD_DIR` zeigt nun direkt auf das externe Repository (für ORS-Zwecke).

## 4. Deaktivierung interner Pipeline-Phasen (ERLEDIGT)
- `scripts/start.sh` wurde bereinigt und triggert nur noch die Plugin-Updates und das Deployment.
- Die internen Download-, Merge- und Konvertierungsskripte wurden archiviert.

## 5. Zentralisierung von Kern-Assets (Fonts & Basis-Sprites) (ERLEDIGT)
- `run_assets.sh` orchestriert den Bau der globalen Ressourcen (Maki, Temaki, Fonts).
- Ein neuer Orchestrator `run_inventory.py` verwaltet die Erstellung aller Inventarlisten und der Master-JSON.
- Die Skripte wurden in thematische Unterordner (`inventory/`, `tools/`, `ors/`) strukturiert.

---
*Status: Alle Punkte umgesetzt am 17. April 2026*
