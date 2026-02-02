
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

- **Ziel:** `/srv/build/overlays/contours/src/bmapvhl_vtpk_3857.vtpk`



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
