
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

