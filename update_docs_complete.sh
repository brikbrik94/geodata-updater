#!/bin/bash



mkdir -p docs



echo "1. Schreibe README.md (Fokus: Nutzung)..."

cat <<'EOF' > README.md

# Geodata Updater



Eine automatisierte Pipeline für selbstgehostete Vektorkarten (PMTiles).

Das System verarbeitet OpenStreetMap-Daten und basemap.at (Österreich) vollautomatisch.



## Features



- **Multi-Map Support:** Konfiguration beliebig vieler Regionen via Textdateien (`conf/sources/*.txt`).

- **Automatisierung:** Ein Befehl für Download, Merge, Konvertierung (Planetiler) und Deployment.

- **Dynamisches Styling:** Stylesheets werden automatisch für jede generierte Karte erstellt.

- **Österreich-Integration:** Spezielle Downloader für `basemap.at` (Vektorkarten & Höhenlinien).

- **Routing:** Optionaler Trigger für OpenRouteService (ORS) Updates.



## Schnellstart



### 1. Installation

Führe das Setup-Skript auf einem Debian/Ubuntu Server aus:



```bash

./install.sh

```



### 2. Karten konfigurieren

Lege für jede gewünschte Karte eine `.txt` Datei in `conf/sources/` an.

Der Dateiname bestimmt den Namen der Karte (z.B. `tirol.txt` -> `tirol.pmtiles`).



**Beispiel `conf/sources/at-plus.txt`:**

```text

[https://download.geofabrik.de/europe/austria-latest.osm.pbf](https://download.geofabrik.de/europe/austria-latest.osm.pbf)

[https://download.geofabrik.de/europe/germany/bayern/oberbayern-latest.osm.pbf](https://download.geofabrik.de/europe/germany/bayern/oberbayern-latest.osm.pbf)

```



### 3. Pipeline starten

Aktualisiert alle konfigurierten Karten:



```bash

/srv/scripts/start.sh

```



## Dokumentation



Detaillierte technische Informationen wurden in separate Dokumente ausgelagert:



- [📄 Technische Referenz](docs/TECHNICAL_DETAILS.md): Details zu Basemap-URLs, ORS-Befehlen und Script-Parametern.

- [📂 Ordnerstruktur](docs/FOLDER_STRUCTURE.md): Detaillierte Übersicht aller Verzeichnisse auf dem Server.

- [🔄 Ablaufdiagramm](docs/deploy_flow.md): Visuelle Darstellung der Pipeline.



## Deployment Befehle



| Befehl | Beschreibung |

| :--- | :--- |

| `/srv/scripts/deploy_pmtiles.sh` | Kopiert fertige PMTiles in den öffentlichen Ordner. |

| `/srv/scripts/deploy_stylesheets.sh` | Generiert Style-Ordner und passt URLs an. |

| `/srv/scripts/deploy_all.sh` | Führt beides aus + generiert Info-JSONs. |



## Voraussetzungen

- Linux (Debian/Ubuntu)

- Docker & Docker CLI

- Python 3, Node.js

EOF



echo "2. Schreibe docs/TECHNICAL_DETAILS.md (Fokus: Details & URLs)..."

cat <<'EOF' > docs/TECHNICAL_DETAILS.md

# Technische Referenz



## 1. Basemap.at Module



Das System enthält spezielle Logik für österreichische Regierungsdaten.



### Vektorkarten (VTPK)

- **Skript:** `scripts/download_basemap.sh`

- **Quelle:** `https://cdn.basemap.at/offline/bmapv_vtpk_3857.vtpk`

- **Logik:** Die Datei wird nur heruntergeladen, wenn die lokale Datei älter als **2 Jahre** ist (um Bandbreite zu sparen).

- **Ziel:** `/srv/build/basemap-at/src/bmapv_vtpk_3857.vtpk`

- **Konvertierung:** Erfolgt durch `scripts/convert_basemap_at_pmtiles.sh` (entpackt VTPK -> konvertiert zu PMTiles).



### Höhenlinien (Contours)

- **Skript:** `scripts/download_basemap_contours.sh`

- **Quelle:** `https://cdn.basemap.at/offline/bmapvhl_vtpk_3857.vtpk`

- **Logik:** Download erfolgt nur, wenn die Datei gar nicht existiert.

- **Force Download:** Kann mit `FORCE_DOWNLOAD=1` erzwungen werden.

- **Ziel:** `/srv/build/basemap-at-contours/src/bmapvhl_vtpk_3857.vtpk`



## 2. OpenRouteService (ORS) Integration



Das System kann nach dem Karten-Update einen Neubau der Routing-Graphen anstoßen.



**Manueller Trigger:**

```bash

/srv/scripts/start.sh --rebuild-ors

```



**Interne Logik:**

Das Skript `scripts/rebuild_ors_graphs.sh` prüft:

1. Existiert `/srv/ors/rebuild_graphs.sh`? -> Ausführen.

2. Wenn nicht: Führt den in `ORS_REBUILD_CMD` definierten Fallback-Befehl aus.



**Verzeichnisse:**

Logs für ORS landen in `/srv/ors/logs` oder `/var/log/osm_update.log`.



## 3. Styling System (Details)



Das System nutzt eine "Convention over Configuration" Logik.



**Der Prozess:**

1. **Vorlage:** `styles/style.json` (im Repo) ist das Master-Template.

2. **Generierung:** `scripts/deploy_stylesheets.sh` scannt alle generierten PMTiles (`*.pmtiles`).

3. **Erstellung:**

   - Für `osm:tirol.pmtiles` wird der Ordner `styles/tirol/` erstellt.

   - Die `style.json` wird hineinkopiert.

4. **Anpassung:** `scripts/update_stylesheets.sh` ersetzt Platzhalter in der JSON mit echten Server-URLs:

   - `sources` -> zeigt auf lokale PMTiles.

   - `glyphs` -> zeigt auf `/srv/assets/fonts`.

   - `sprite` -> zeigt auf `/srv/assets/sprites`.



## 4. Manuelle Skript-Ausführung



Die Pipeline besteht aus modularen Skripten, die einzeln nutzbar sind:



- **`run_download.sh`**:

  - Liest `conf/sources/*.txt`.

  - Lädt OSM PBFs (nur wenn neuer: `wget -N`).

  - Lädt Basemap.at Daten (nach Zeit-Regeln).

  - Erstellt `.list` Dateien für den Merge.



- **`run_merge.sh`**:

  - Nutzt `osmium-tool`.

  - Merged alle Dateien aus einer `.list` zu einer `.osm.pbf`.



- **`run_pmtiles.sh`**:

  - Startet Docker (`onthegomap/planetiler`).

  - Konvertiert `.osm.pbf` -> `.pmtiles`.

  - Generiert Metadaten-JSON.

EOF



echo "3. Schreibe docs/FOLDER_STRUCTURE.md (Fokus: Übersicht)..."

cat <<'EOF' > docs/FOLDER_STRUCTURE.md

# Detaillierte Ordnerstruktur



Dies ist die vollständige Struktur auf dem Zielserver (`/srv/`) nach der Installation und dem ersten Lauf.



```

/srv/

├── scripts/                # Logik & Programmcode

│   ├── sources/            # Konfiguration der Karten (z.B. at-plus.txt)

│   ├── stats/              # Logs & Status-Dateien der Builds

│   └── venv/               # Python Virtual Environment

│

├── conf/                   # (Optional) Backup der Config

│

├── assets/                 # Statische Web-Ressourcen

│   ├── fonts/              # PBF Fonts für MapLibre

│   └── sprites/            # Icons & Symbole

│

├── tiles/                  # ÖFFENTLICHER Web-Ordner (Nginx Root)

│   ├── deploy_info.json    # Übersicht aller Karten für das Frontend

│   ├── index.html          # Automatisch generierte Info-Seite

│   │

│   ├── osm/

│   │   ├── pmtiles/

│   │   │   ├── at.pmtiles

│   │   │   └── at-plus.pmtiles

│   │   └── styles/

│   │       ├── at/         # Automatisch generierter Style für 'at'

│   │       │   └── style.json

│   │       └── at-plus/    # Automatisch generierter Style für 'at-plus'

│   │           └── style.json

│   │

│   ├── basemap-at/

│   │   ├── pmtiles/

│   │   └── styles/

│   │

│   └── overlays/

│

├── build/                  # Arbeitsverzeichnis (Temporär & Cache)

│   ├── osm/

│   │   ├── src/            # Rohdaten (Downloads)

│   │   ├── merged/         # Zusammengefügte PBFs

│   │   └── tmp/            # Planetiler Output

│   │

│   ├── basemap-at/

│   │   ├── src/            # VTPK Datei

│   │   └── tmp/            # Entpackte Tiles

│   └── ...

│

└── ors/                    # OpenRouteService Daten (falls installiert)

    ├── graphs/

    └── logs/

```

EOF



echo "✅ Dokumentation erfolgreich aufgeteilt und erstellt."
