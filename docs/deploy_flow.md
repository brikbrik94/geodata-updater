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
