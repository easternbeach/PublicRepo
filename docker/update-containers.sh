#!/usr/bin/env bash

# Stop if a command fails or an unset variable is used.
set -euo pipefail

# Pull the latest Plex image and recreate its container if the image changed.
# Compose reads the YAML file in ~/plex and keeps the existing configuration.
cd "$HOME/plex"
docker compose pull
docker compose up -d

# Pull the latest Emby image and recreate its container if the image changed.
# Existing volumes are preserved when Compose recreates the container.
cd "$HOME/emby"
docker compose pull
docker compose up -d
