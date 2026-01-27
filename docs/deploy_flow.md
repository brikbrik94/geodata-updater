# Deployment Script Ablauf

```mermaid
flowchart TD
  start[start.sh] --> run_download[run_download.sh]
  start --> run_merge[run_merge.sh]
  start --> run_pmtiles[run_pmtiles.sh]
  start --> run_ors[run_ors.sh (optional)]

  run_download --> download_osm[download_osm.sh]
  run_merge --> merge_osm[merge_osm.sh]

  run_pmtiles --> convert_osm[convert_osm_pmtiles.sh]
  run_pmtiles --> convert_basemap[convert_basemap_at_pmtiles.sh]
  run_pmtiles --> convert_contours[convert_basemap_contours_pmtiles.sh]

  deploy_all[deploy_all.sh] --> deploy_pmtiles[deploy_pmtiles.sh]
  deploy_all --> deploy_stylesheets[deploy_stylesheets.sh]
  deploy_all --> generate_info[Info-Datei erzeugen\n(deploy_info.json)]
  deploy_pmtiles --> tiles_dir[/srv/tiles/<tileset>/pmtiles/*.pmtiles]
  deploy_stylesheets --> styles_dir[/srv/tiles/<tileset>/styles/<style-id>/style.json]
```

Die Info-Datei wird nach den beiden Deployments generiert und listet je Tileset
alle gefundenen PMTiles sowie Stylesheets inklusive Pfad und optionaler URL.



# Deployment Script Ablauf

```mermaid
flowchart TD
  start[start.sh] --> run_download[run_download.sh]
  start --> run_merge[run_merge.sh]
  start --> run_pmtiles[run_pmtiles.sh]
  start --> run_ors[run_ors.sh (optional)]

  subgraph "Multi-Map Loop"
    run_download --> download_loop{Für jede .txt Quelle}
    download_loop --> download_osm[download_osm.sh]
    
    run_merge --> merge_loop{Für jede .list}
    merge_loop --> merge_osm[merge_osm.sh]

    run_pmtiles --> planetiler_loop{Für jedes .pbf}
    planetiler_loop --> convert_osm[convert_osm_pmtiles.sh]
  end

  run_download --> download_basemap[Basemap.at Downloads]

  run_pmtiles --> convert_basemap[convert_basemap_at_pmtiles.sh]

  deploy_all[deploy_all.sh] --> deploy_pmtiles[deploy_pmtiles.sh]
  deploy_all --> deploy_stylesheets[deploy_stylesheets.sh]
  
  deploy_stylesheets --> style_logic[Auto-Generate Style Folders]
  style_logic --> update_urls[update_stylesheets.sh]
```

Die `deploy_all.sh` sorgt am Ende dafür, dass PMTiles und Styles synchronisiert und die Info-JSONs für das Frontend generiert werden.
