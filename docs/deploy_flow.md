# Geodata Pipeline Ablauf (Mermaid Diagramm)

Die folgende Darstellung zeigt den aktuellen Ablauf der Pipeline basierend auf der Plugin-Architektur.

```mermaid
flowchart TD
  start[scripts/start.sh] --> run_ext[scripts/run_external_updates.sh]
  
  subgraph "Plugin Phase (Extern)"
    run_ext --> plugin_osm[geodata-osm / update.sh]
    run_ext --> plugin_base[geodata-basemap-at / update.sh]
    run_ext --> plugin_ski[geodata-openskimap / update.sh]
    
    plugin_osm --> dist_osm[dist/ folder]
    plugin_base --> dist_base[dist/ folder]
    plugin_ski --> dist_ski[dist/ folder]
  end

  start --> run_deploy[scripts/run_deploy.sh]

  subgraph "Deployment Phase"
    run_deploy --> deploy_ext[scripts/deploy_external.py]
    deploy_ext --> copy_data[Kopiere PMTiles, Styles & Assets\nnach /srv/tiles und /srv/assets]
    
    run_deploy --> run_inv[scripts/run_inventory.py]
    run_inv --> inv_tiles[inventory/tiles.py]
    run_inv --> inv_sprites[inventory/sprites.py]
    run_inv --> inv_fonts[inventory/fonts.sh]
    run_inv --> inv_agg[inventory/aggregate.py]
    
    inv_agg --> master_json[info/endpoints_info.json]
    
    run_deploy --> patch_styles[scripts/update_stylesheets.py]
    patch_styles --> final_styles[Finalisierte Styles mit\nabsoluten URLs]
  end

  master_json --> patch_styles
  copy_data --> run_inv
```

## Beschreibung des Ablaufs

1. **Orchestrierung:** `start.sh` triggert die Aktualisierung aller in `conf/external_repos.txt` definierten Plugins.
2. **Plugins:** Jedes Plugin baut seine Daten eigenständig und stellt sie im `dist/` Verzeichnis bereit.
3. **Deployment:** `deploy_external.py` sammelt alle Daten basierend auf den `manifest.json` Dateien ein.
4. **Inventarisierung:** Alle verfügbaren Daten auf dem Server werden neu erfasst und in einer zentralen Master-JSON zusammengefasst.
5. **Finalisierung:** Die Stylesheets werden dynamisch an die aktuelle Server-Konfiguration (URLs) angepasst.
