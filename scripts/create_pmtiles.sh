#!/bin/bash

# --- KONFIGURATION ---
INPUT_PBF="/srv/osm/merged/complete_map.osm.pbf"
INPUT_FILENAME="complete_map.osm.pbf"
BUILD_DIR="/srv/pmtiles/build/out"
SOURCES_DIR="/srv/pmtiles/build/sources"
SERVE_DIR="/srv/pmtiles/serve"
STATS_DIR="/srv/scripts/stats"
INFO_JSON="$SERVE_DIR/info.json"
FILENAME="at-plus.pmtiles"
DOCKER_IMAGE="ghcr.io/onthegomap/planetiler:latest"
DEBUG_LOG="/srv/scripts/planetiler_raw_debug.log"

# --- PYTHON FOLLOWER SCRIPT ---
read -d '' BEAUTIFIER_SCRIPT << 'EOF'
import sys, re, shutil, json, os, time, warnings
from datetime import datetime

warnings.filterwarnings("ignore")

# Argumente vom Bash-Script
log_file_path = sys.argv[1]
docker_pid = int(sys.argv[2])

cols = shutil.get_terminal_size().columns
bar_width = 25
stats_dir = os.environ.get("STATS_DIR", "/tmp")
current_date = datetime.now().strftime("%Y-%m-%d")
json_path = os.path.join(stats_dir, f"stats_{current_date}.json")
report_path = os.path.join(stats_dir, f"report_{current_date}.txt")

data = {"date": current_date, "timestamp": datetime.now().isoformat(), "duration": "N/A", "cpu_time": "N/A", "file_size": "N/A", "max_tile_size": "N/A", "avg_tile_size": "N/A", "biggest_tiles": []}
capture_mode = None
ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
ESC=chr(27); RED=f"{ESC}[91m"; GREEN=f"{ESC}[1;32m"; YELLOW=f"{ESC}[1;33m"; CYAN=f"{ESC}[1;36m"; MAGENTA=f"{ESC}[1;35m"; WHITE=f"{ESC}[1;37m"; RESET=f"{ESC}[0m"

def clean_line(line): return ansi_escape.sub('', line)
def is_process_running(pid):
    try:
        os.kill(pid, 0) # Signal 0 prüft nur Existenz
        return True
    except OSError:
        return False

def print_status(phase, details, percent=None):
    status = f" >> {CYAN}{phase}{RESET}: "
    if "osm_bounds" in phase:
        status = f" >> {MAGENTA}KARTEN-SCAN{RESET}: "
        details = "Suche Koordinaten... (Geduld...)"
    if percent is not None:
        try:
            p = int(percent)
            filled = int(bar_width * p / 100)
            bar = "█" * filled + "░" * (bar_width - filled)
            status += f"[{bar}] {YELLOW}{p}%{RESET} "
        except: pass
    sys.stdout.write(chr(13) + (status + details)[:cols+10].ljust(cols+10))
    sys.stdout.flush()

print(f"{'--- OSM PLANETILER RUNNER (FOLLOWER MODE) ---'.center(cols)}")
print(f"Log: {log_file_path}")
print(f"{YELLOW}[INFO] Warte auf Log-Daten...{RESET}")

# Warten bis Logfile existiert
while not os.path.exists(log_file_path):
    time.sleep(0.1)

try:
    with open(log_file_path, "r", encoding="utf-8", errors="ignore") as f:
        while True:
            line = f.readline()
            if not line:
                # Keine neue Zeile? Prüfen ob Docker noch läuft
                if not is_process_running(docker_pid):
                    break # Docker fertig, Loop beenden
                time.sleep(0.1) # Warten auf neue Daten
                continue

            line_clean = line.strip()
            line_no_color = clean_line(line_clean)

            # --- PARSING ---
            if "Biggest tiles" in line_no_color: capture_mode = "biggest"; continue
            if capture_mode == "biggest":
                if not re.match(r'^\d+\.', line_no_color) and ("DEB" in line_no_color or "INF" in line_no_color): capture_mode = None
                else:
                    m = re.match(r'^\d+\.\s+(\S+)\s+\((.*?)\)\s+(.*?)\s+\((.*?)\)', line_no_color)
                    if m: data["biggest_tiles"].append({"coord": m.group(1), "size": m.group(2), "url": m.group(3), "reason": m.group(4)})

            if "Max tile:" in line_no_color:
                m = re.search(r'Max tile:.*?\(gzipped:\s+(.*?)\)', line_no_color); 
                if m: data["max_tile_size"] = m.group(1)
            if "Avg tile:" in line_no_color:
                m = re.search(r'Avg tile:.*?\(gzipped:\s+(.*?)\)', line_no_color); 
                if m: data["avg_tile_size"] = m.group(1)
            if "Finished in" in line_no_color and "cpu:" in line_no_color:
                m = re.search(r'Finished in\s+(.*?)\s+cpu:(.*?)\s', line_no_color)
                if m: data["duration"] = m.group(1); data["cpu_time"] = m.group(2)
            if "archive" in line_no_color and "features:" in line_no_color and "tiles:" in line_no_color:
                m = re.search(r'tiles:.*?\]\s+(\S+)', line_no_color); 
                if m: data["file_size"] = m.group(1)

            # --- ANZEIGE ---
            if "Exception" in line_clean or "Error" in line_clean or "❌" in line_clean:
                sys.stdout.write("\n"); print(f"{RED}{line_clean}{RESET}"); continue
            
            if "Bounds not found" in line_no_color or "osm_bounds" in line_no_color:
                 print_status("osm_bounds", "Start...")

            match = re.search(r"INF \[(.*?)\] - (.*)", line_no_color)
            if match:
                phase = match.group(1); details = match.group(2)
                perc_match = re.search(r"(\d+)%", details)
                percent = perc_match.group(1) if perc_match else None
                clean_details = details.replace("[", "").replace("]", "").strip()
                print_status(phase, clean_details, percent)
            elif "INF" in line_no_color and "bracket" not in line_no_color:
                parts = line_no_color.split("INF - ")
                if len(parts) > 1: print_status("INIT", parts[1].strip()[:50])

except KeyboardInterrupt: pass
except Exception as e: print(f"\nERROR: {e}")

# Stats speichern
with open(json_path, 'w') as f: json.dump(data, f, indent=2)
with open(report_path, 'w') as f: f.write(f"REPORT {data['date']}\nDuration: {data['duration']}\nSize: {data['file_size']}\n")

print("\n" + "="*cols)
print(f" {GREEN}✅ FERTIG!{RESET}   (Dauer: {data['duration']})")
print(f" 📂 Datei:     {WHITE}{data['file_size']}{RESET}")
print(f" 📊 Kacheln:   Ø {data['avg_tile_size']} (Max: {RED}{data['max_tile_size']}{RESET})")
print("="*cols)
EOF

# --- VORBEREITUNG ---
set -o pipefail
export STATS_DIR="$STATS_DIR"

if ! systemctl is-active --quiet docker; then echo "❌ FEHLER: Docker läuft nicht."; exit 1; fi
if [ ! -f "$INPUT_PBF" ]; then echo "❌ FEHLER: Input-Datei $INPUT_PBF nicht gefunden."; exit 1; fi

mkdir -p "$BUILD_DIR" "$SOURCES_DIR" "$SERVE_DIR" "$STATS_DIR"
# Logfile leeren
> "$DEBUG_LOG"

# --- RUN PLANETILER (HINTERGRUND) ---
echo "Starte Docker im Hintergrund..."

# WICHTIG: Docker läuft im Hintergrund (&) und schreibt in die Datei.
# Python läuft im Vordergrund und liest die Datei. Keine Pipe, kein Deadlock.
sudo docker run --rm \
  -v /srv/osm/merged:/in:ro \
  -v "$BUILD_DIR":/out \
  -v "$SOURCES_DIR":/data/sources \
  "$DOCKER_IMAGE" \
  --download=true \
  --osm-path="/in/$INPUT_FILENAME" \
  --output="/out/$FILENAME" \
  --force \
  --color=true \
  > "$DEBUG_LOG" 2>&1 &

DOCKER_PID=$!

# --- PYTHON FOLLOWER STARTEN ---
# Wir übergeben den Pfad zum Log und die PID von Docker
python3 -u -c "$BEAUTIFIER_SCRIPT" "$DEBUG_LOG" "$DOCKER_PID"

# Warten bis Docker wirklich fertig ist (für den Exit Code)
wait $DOCKER_PID
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ FEHLER: Planetiler ist fehlgeschlagen (Exit Code: $EXIT_CODE)."
    echo "Details im Log: $DEBUG_LOG"
    exit 1
fi

# --- DEPLOYMENT ---
mv "$BUILD_DIR/$FILENAME" "$SERVE_DIR/$FILENAME"
chmod 644 "$SERVE_DIR/$FILENAME"

# --- INFO.JSON UPDATE ---
CURRENT_DATE=$(date +%Y-%m-%d)
FILE_SIZE=$(stat -c%s "$SERVE_DIR/$FILENAME")
HOST_NAME=$(hostname)

cat <<EOF > "$INFO_JSON"
{
  "name": "AT+ OpenMapTiles (PMTiles)",
  "source_pbf": "$INPUT_FILENAME",
  "dataset_date": "$CURRENT_DATE",
  "maxzoom": 14,
  "pmtiles_file": "$FILENAME",
  "pmtiles_size_bytes": $FILE_SIZE,
  "built_from_host": "$HOST_NAME",
  "attribution": "© OpenMapTiles © OpenStreetMap contributors"
}
EOF
chmod 644 "$INFO_JSON"
