# Detaillierte Ordnerstruktur

Dies ist die aktuelle Struktur auf dem Server (/srv), automatisch generiert am 2026-01-27.

```
/srv
├── assets
│   ├── fonts  [57 entries exceeds filelimit, not opening dir]
│   └── sprites
│       ├── basemap-at
│       │   ├── sprite@2x.json
│       │   └── sprite.json
│       ├── basemap-at-contours
│       │   ├── sprite@2x.json
│       │   └── sprite.json
│       ├── maki
│       │   ├── maki-sprite@2x.json
│       │   ├── maki-sprite.json
│       │   ├── sprite@2x.json
│       │   └── sprite.json
│       ├── poi
│       │   ├── README.md
│       │   ├── sprite@2x.json
│       │   └── sprite.json
│       └── temaki
│           ├── sprite@2x.json
│           ├── sprite.json
│           ├── temaki-sprite@2x.json
│           └── temaki-sprite.json
├── authelia
│   └── config
├── build
│   ├── basemap-at
│   ├── basemap-at-contours
│   ├── osm
│   └── overlays
├── docs
│   ├── deploy_flow.md
│   ├── FOLDER_STRUCTURE.md
│   └── TECHNICAL_DETAILS.md
├── info
│   ├── attribution
│   │   ├── maki
│   │   │   ├── LICENSE.txt
│   │   │   └── README.md
│   │   ├── map-icons
│   │   ├── openmaptiles-fonts
│   │   │   └── README.md
│   │   └── temaki
│   │       └── README.md
│   ├── endpoints_info.json
│   ├── font_inventory.json
│   ├── info.html
│   └── sprite_inventory.json
├── nominatim-dach
├── ors
│   ├── elevation_cache
│   ├── emergency
│   │   └── logs
│   ├── graphs
│   │   ├── driving-car
│   │   │   └── stamp.txt
│   │   └── driving-emergency
│   │       └── stamp.txt
│   └── logs
├── osm
├── scripts  [35 entries exceeds filelimit, not opening dir]
├── styles
│   └── style.json
├── tiles
│   ├── basemap-at
│   │   ├── pmtiles
│   │   ├── styles
│   │   │   └── basemap-at
│   │   └── tilejson
│   ├── osm
│   │   ├── pmtiles
│   │   ├── styles
│   │   │   └── at-plus
│   │   └── tilejson
│   └── overlays
│       ├── pmtiles
│       ├── styles
│       └── tilejson
└── www
    └── tiles
        ├── assets
        ├── pmtiles
        │   ├── at-plus.pmtiles -> /srv/tiles/osm/pmtiles/at-plus.pmtiles
        │   ├── basemap-at-contours.pmtiles -> /srv/tiles/basemap-at-contours/pmtiles/basemap-at-contours.pmtiles
        │   └── basemap-at.pmtiles -> /srv/tiles/basemap-at/pmtiles/basemap-at.pmtiles
        ├── styles
        │   ├── basemap-at
        │   ├── basemap-at-contours
        │   ├── osm
        │   └── overlays
        └── inventory.json

59 directories, 33 files
```

## Legende

- **scripts/**: Enthält die Pipeline-Logik.
- **tiles/**: Der öffentliche Web-Ordner (Nginx Root).
- **build/**: Arbeitsverzeichnis (Downloads & Zwischenschritte).
- **assets/**: Fonts und Sprites.
- **conf/sources/**: Konfigurationen der einzelnen Karten.
