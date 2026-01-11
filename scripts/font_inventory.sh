#!/bin/bash
set -euo pipefail

DELETE_THRESHOLD="${DELETE_THRESHOLD:-100}"
FONTS_DIR="/srv/assets/fonts"
INFO_DIR="/srv/info"
OUTPUT_FILE="${OUTPUT_FILE:-font_inventory.json}"

echo "-------------------------------------------------------------"
echo "🧹  Font Cleaner & Inventory (Bash Version)"
echo "-------------------------------------------------------------"

if [ ! -d "$FONTS_DIR" ]; then
    echo "❌ Fehler: Der Pfad '$FONTS_DIR' existiert nicht."
    exit 1
fi

echo -e "\n⚙️  Starte Analyse in: $FONTS_DIR"
echo -e "   (Lösch-Limit: < $DELETE_THRESHOLD Bytes)\n"

mkdir -p "$INFO_DIR"
TMP_INVENTORY="$(mktemp)"
echo "{" > "$TMP_INVENTORY"

TOTAL_DELETED=0
TOTAL_KEPT=0
FIRST_ENTRY=true

for font_dir_path in "$FONTS_DIR"/*/; do
    [ -d "$font_dir_path" ] || continue

    font_name_raw=$(basename "$font_dir_path")
    font_name="${font_name_raw// /-}"
    if [ "$font_name_raw" != "$font_name" ]; then
        new_dir_path="${font_dir_path%/}"
        new_dir_path="${new_dir_path%/*}/$font_name/"
        if [ ! -d "$new_dir_path" ]; then
            mv "$font_dir_path" "$new_dir_path"
            font_dir_path="$new_dir_path"
        fi
    fi

    count_to_delete=$(find "$font_dir_path" -maxdepth 1 -name "*.pbf" -size -"${DELETE_THRESHOLD}"c | wc -l)
    if [ "$count_to_delete" -gt 0 ]; then
        find "$font_dir_path" -maxdepth 1 -name "*.pbf" -size -"${DELETE_THRESHOLD}"c -delete
        echo -e "✔️  $(printf '%-30s' "$font_name"): $count_to_delete gelöscht"
    else
        echo -e "ℹ️  $(printf '%-30s' "$font_name"): 0 gelöscht (Noto?)"
    fi

    TOTAL_DELETED=$((TOTAL_DELETED + count_to_delete))

    files=$(ls "$font_dir_path"*.pbf 2>/dev/null | xargs -n 1 basename | sort -n || true)
    count_kept=$(echo "$files" | grep -c ".pbf" || true)
    TOTAL_KEPT=$((TOTAL_KEPT + count_kept))

    if [ "$count_kept" -gt 0 ]; then
        json_array=$(echo "$files" | sed 's/^/"/;s/$/"/' | paste -sd, -)
    else
        json_array=""
    fi

    if [ "$FIRST_ENTRY" = true ]; then
        FIRST_ENTRY=false
    else
        echo "," >> "$TMP_INVENTORY"
    fi

    echo -n "  \"$font_name\": [$json_array]" >> "$TMP_INVENTORY"
done

echo "" >> "$TMP_INVENTORY"
echo "}" >> "$TMP_INVENTORY"

mv "$TMP_INVENTORY" "$INFO_DIR/$OUTPUT_FILE"

echo "-------------------------------------------------------------"
echo "🎉 FERTIG!"
echo "🗑️  Gesamt gelöscht: $TOTAL_DELETED"
echo "💾 Verbleibende Ranges: $TOTAL_KEPT"
echo "📄 JSON erstellt: $INFO_DIR/$OUTPUT_FILE"
