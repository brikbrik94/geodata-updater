# TODO

## `legend_scale_id`/`legend_sections` (Plugin-Standard §5.5/§5.6) noch nicht in `layers_info.json`

Beim Fix von GitHub-Issue #96 (`version`-Passthrough) aufgefallen: `scripts/inventory/layers.py`
gibt pro Group nur `type`/`color`/`opacity`/`legend_items` weiter (aus PR f60eaf0). Die in
`geodata-plugin-standard` §5.3/§5.5/§5.6 spezifizierten Felder `legend_scale_id` auf Group-Ebene
und der Top-Level-Block `legend_sections` (geteilte Farbskalen, z.B. Ski-Schwierigkeitsgrade)
fehlen komplett. Referenz-Implementierung dafür liegt laut Standard-§5.8 im Repo `overlays`
(`scripts/layer_metadata_extractor.py`/`generate_layer_list.py`) — hier in `layers.py` fehlt nur
die Aggregations-Seite. Nicht im Scope von #96 mitgefixt, siehe Mandat 2 in
`oe5ith-coding-rules/AGENT_INSTRUCTIONS.md`.

## Anpassung an `oe5ith-coding-rules`-Standard (Submodul seit 2026-08-12 eingebunden)

Dieses Repo wurde bisher unabhängig von den generischen Agenten-Regeln in
`oe5ith-coding-rules/AGENT_INSTRUCTIONS.md` gepflegt. Folgende Punkte bringen es auf den dort
vorgeschriebenen Stand:

- **TODO.md/ROADMAP.md gehören unter `docs/`, nicht an den Repo-Root** (§3): `TODO.md` liegt
  aktuell am Root. Migration: `docs/TODO.md` + `docs/TODO_ARCHIVE.md` (aktueller Scope) und
  `docs/ROADMAP.md` + `docs/ROADMAP_ARCHIVE.md` (neue Features) anlegen, bestehenden Inhalt
  dieser Datei nach `docs/TODO.md` übertragen.
- **`CHANGELOG.md` fehlt komplett** (§4, Keep a Changelog): Repo hat keine Datei dieses Namens.
  Anlegen nach Keep-a-Changelog-Schema mit datierten `[Unreleased]`-Journal-Blöcken.
- **Keine zentrale Versionskonstante** (§4, SemVer): kein `VERSION`-File o.ä. vorhanden. Klären,
  was hier als Single-Source-of-Truth für eine Versionsnummer dienen soll (kein `package.json`
  in diesem Repo).
- **Kein dokumentierter Release-Prozess**: Deployment läuft direkt per `rsync` aus dem Repo
  (`scripts/tools/deploy_scripts.sh`) ohne Build-Artefakt oder Tags. Klären, ob/wie SemVer-Tags +
  Release-Checkliste (§4) hier sinnvoll anzuwenden sind, bevor `CHANGELOG.md`/Versionierung
  final ausgerollt werden.
- **`.editorconfig` fehlt** am Repo-Root (Standards-Tabelle, EditorConfig-Zeile).
- **Versehentlich committete Scratch-Artefakte** (§4 „Scratch/Hygiene"): `wget-log` (Root, ~1.1 MB
  Download-Log) und `bak/convert_basemap_contours_pmtiles.sh.27-01-2026.bak` sind im Git-Index.
  Aus dem Repo entfernen und ggf. `.gitignore`/`scratch/`-Konvention ergänzen.
- **`docs/proposals/` (+ `docs/proposals/archive/`) fehlt** (§5): nötig, sobald das erste Mal
  inhaltlich an `CLAUDE.md` oder den Mandaten selbst etwas geändert werden soll — der
  Draft-Review-Merge-Zyklus greift erst mit dieser Struktur.
- **`CLAUDE.md`-Architekturabschnitt verweist noch nicht auf das `geodata-plugin-standard`-
  Submodul** als kanonische Quelle für Manifest-/`layer-list.json`-Spezifikation (aktuell nur
  `docs/EXTERNAL_PLUGINS.md` referenziert, `CLAUDE.md:56`). Nach den Standards-Referenzen-Regeln
  (Fall „generischer Standard mit projekteigenem Anwendungsartefakt") muss der Einstiegspunkt
  explizit auf das Submodul verweisen, nicht nur auf die eigene Doku.

## ~~Inkrementelle Deployment Logik (Stylesheets)~~ (gelöst 2026-07-20)

**Problem war:**
Die inkrementelle Update-Logik in `scripts/update_stylesheets.py` (bzw. das Setzen der Flags durch `deploy_external.py` und `run_inventory.py`) übersprang das Anpassen der `style.json`-Dateien, wenn sich die zugrunde liegenden PMTiles-Dateien oder Styles der Plugins (Datum/Größe) nicht geändert hatten (`updated_tiles` oder `updated_master` Flag fehlten).

**Folge war:**
Wenn sich Umgebungsvariablen wie z.B. die `TILES_BASE_URL` in der Konfiguration (`config.env`) änderten oder Logik-Fehler in `update_stylesheets.py` behoben wurden, griffen diese Anpassungen nicht auf bereits deployte Styles. Konkret aufgefallen, als nach Reduktion der OSM-Datasets (`geodata-osm`) auf `at`/`at+nbl` die zugehörigen `style.json` weiterhin auf einen veralteten Platzhalter-Pfad (`at-plus.pmtiles`) zeigten und die Karten dadurch über die öffentlichen URLs nicht erreichbar waren — die Flags fehlten, da `deploy_external.py` die unveränderten PMTiles als "skipped" wertete und das manuelle `cleanup_tiles.py` gar keine Flags setzt.

**Lösung (Ansatz 1 aus dem ursprünglichen Vorschlag umgesetzt):**
`scripts/update_stylesheets.py` prüft jetzt bei jedem Lauf unconditional alle deployten `style.json`-Dateien gegen den Soll-Zustand und schreibt nur, wenn es tatsächlich Abweichungen gibt (die Pro-Datei-Logik war bereits idempotent). Das Flag-Gate (`updated_tiles`/`updated_master`) wurde entfernt, `--force` ist dadurch für dieses Skript nicht mehr nötig. Zusätzlicher I/O-Aufwand ist vernachlässigbar (nur JSON-Lesen/Diff pro Style, kein Neukopieren von PMTiles).
