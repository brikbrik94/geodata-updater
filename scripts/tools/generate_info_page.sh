#!/bin/bash
# scripts/generate_info_page.sh
# Generiert eine index.html im OE5ITH-Cloud Design basierend auf den vorhandenen PMTiles.

WEB_ROOT="/srv/www/tiles"
OUTPUT_FILE="$WEB_ROOT/index.html"
PMTILES_DIR="$WEB_ROOT/pmtiles"

# Stelle sicher, dass das Verzeichnis existiert
mkdir -p "$WEB_ROOT"

# --- HTML HEADER & CSS ---
# Wir binden das style.css ein, das wir im Ordner assets/ erwarten.
# Fallback: FontAwesome via CDN.

cat << 'EOF' > "$OUTPUT_FILE"
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OE5ITH Tileserver</title>
    <link rel="stylesheet" href="assets/style.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        /* Zusätzliche Styles für die Dateiliste */
        .file-meta { font-family: monospace; font-size: 12px; color: var(--muted); margin-top: 4px; }
        .copy-btn { 
            background: transparent; border: 1px solid var(--border); color: var(--muted);
            cursor: pointer; padding: 2px 6px; border-radius: 4px; font-size: 11px; margin-left: 8px;
        }
        .copy-btn:hover { color: var(--accent); border-color: var(--accent); }
    </style>
    <script>
        function copyToClipboard(text) {
            navigator.clipboard.writeText(text).then(() => {
                alert('URL kopiert: ' + text);
            });
        }
    </script>
</head>
<body>
    <div class="topbar">
        <div style="display:flex; align-items:center">
            <div class="brand">OE5ITH.AT</div>
            <div class="page-title">Tileserver Registry</div>
        </div>
        <div>
             <span style="font-size:12px; color:var(--muted); margin-right:10px">
                <i class="fa-solid fa-clock"></i> Aktualisiert: DATE_PLACEHOLDER
            </span>
        </div>
    </div>

    <div class="layout">
        <div class="sidebar">
            <div style="margin-bottom:12px; font-weight:600; font-size:12px; color:var(--muted)">NAVIGATION</div>
            <a href="https://cloud.oe5ith.at" class="nav-link"><i class="fa-solid fa-arrow-left"></i> Zurück zur Cloud</a>
            <div style="height:1px; background:var(--border); margin:10px 0"></div>
            <a href="#" class="nav-link active"><i class="fa-solid fa-layer-group"></i> Verfügbare Maps</a>
            <a href="/styles/basic.json" target="_blank" class="nav-link"><i class="fa-solid fa-paint-roller"></i> Style JSON</a>
            <a href="/fonts/" target="_blank" class="nav-link"><i class="fa-solid fa-font"></i> Fonts</a>
        </div>

        <div id="app-main">
            <h1>Verfügbare Vektorkarten</h1>
            <p>Diese Dateien liegen als PMTiles (Cloud Native Maps) vor und können direkt eingebunden werden.</p>

            <div class="cards">
EOF

# --- AKTUALISIERUNGSDATUM EINFÜGEN ---
CURRENT_DATE=$(date "+%d.%m.%Y %H:%M")
sed -i "s/DATE_PLACEHOLDER/$CURRENT_DATE/g" "$OUTPUT_FILE"

# --- LOOP ÜBER PMTILES ---
# Wir suchen alle .pmtiles Dateien und erstellen pro Datei eine "Card"
if [ -d "$PMTILES_DIR" ]; then
    for file in "$PMTILES_DIR"/*.pmtiles; do
        if [ -f "$file" ]; then
            FILENAME=$(basename "$file")
            SIZE=$(du -h "$file" | cut -f1)
            DATE=$(date -r "$file" "+%d.%m.%Y")
            
            # URL konstruieren
            FILE_URL="https://tiles.oe5ith.at/pmtiles/$FILENAME"

            cat << EOCARD >> "$OUTPUT_FILE"
                <div class="card">
                    <h3><i class="fa-solid fa-map" style="color:var(--accent); margin-right:6px"></i> $FILENAME</h3>
                    <div class="file-meta">
                        <i class="fa-solid fa-hard-drive"></i> $SIZE &bull; <i class="fa-solid fa-calendar"></i> $DATE
                    </div>
                    <p style="margin-top:10px; font-size:13px; word-break:break-all;">
                        <span style="color:var(--muted)">URL:</span><br>
                        <code style="background:#000; padding:2px 4px; border-radius:4px; color:var(--text)">$FILE_URL</code>
                        <button class="copy-btn" onclick="copyToClipboard('$FILE_URL')"><i class="fa-solid fa-copy"></i></button>
                    </p>
                    <div style="margin-top:12px">
                        <a href="https://cloud.oe5ith.at/viewer?map=$FILE_URL" class="btn small" target="_blank">
                            <i class="fa-solid fa-eye"></i> Vorschau
                        </a>
                    </div>
                </div>
EOCARD
        fi
    done
else
    # Fallback, falls kein Ordner da ist
    cat << EOCARD >> "$OUTPUT_FILE"
    <div class="card">
        <h3>Keine Karten gefunden</h3>
        <p>Der Ordner /pmtiles ist leer oder existiert nicht.</p>
    </div>
EOCARD
fi

# --- HTML FOOTER ---
cat << 'EOF' >> "$OUTPUT_FILE"
            </div> <h2 style="margin-top:40px; font-size:18px">Technische Endpoints</h2>
            <div class="cards">
                <div class="card">
                    <h3><i class="fa-solid fa-code"></i> Styles & Fonts</h3>
                    <p>Ressourcen für MapLibre / Mapbox GL.</p>
                    <ul style="padding-left:20px; color:var(--muted); line-height:1.8">
                        <li><b>Style:</b> <a href="/styles/basic.json" style="color:var(--accent)">/styles/basic.json</a></li>
                        <li><b>Fonts:</b> /fonts/{fontstack}/{range}.pbf</li>
                        <li><b>Sprites:</b> /sprites/sprite@2x.png</li>
                    </ul>
                </div>
            </div>

        </div> </div> </body>
</html>
EOF

echo "✅ Info-Page generiert: $OUTPUT_FILE"
