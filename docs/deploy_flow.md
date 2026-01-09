# Deployment Script Ablauf

```mermaid
flowchart TD
  deploy_all[deploy_all.sh] --> deploy_pmtiles[deploy_pmtiles.sh]
  deploy_all --> deploy_stylesheets[deploy_stylesheets.sh]
  deploy_all --> generate_info[Info-Datei erzeugen\n(deploy_info.json)]
  deploy_pmtiles --> tiles_dir[/srv/tiles/<tileset>/pmtiles/*.pmtiles]
  deploy_stylesheets --> styles_dir[/srv/tiles/<tileset>/styles/<style-id>/style.json]
```

Die Info-Datei wird nach den beiden Deployments generiert und listet je Tileset
alle gefundenen PMTiles sowie Stylesheets inklusive Pfad und optionaler URL.
