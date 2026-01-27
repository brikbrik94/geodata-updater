
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

