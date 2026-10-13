#!/usr/bin/env bash
set -euo pipefail

echo "=== 1. Executing Storage & Network Share Setup ==="
/opt/homelab-migration/storage/setup-shares.sh

echo "=== 2. Installing Official Docker Engine ==="
if ! command -v docker &> /dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  usermod -aG docker Serverkg
fi

echo "=== 3. Restoring Docker Appdata Bind Mounts ==="
if [ -f /mnt/NAS/Backup/appdata.tar.gz ]; then
  mkdir -p "${HOME}/appdata"
  tar -xvzf /mnt/NAS/Backup/appdata.tar.gz -C "${HOME}"
  chown -R Serverkg:Serverkg "${HOME}/appdata"
fi

echo "=== 4. Launching Portainer ==="
docker volume create portainer_data || true
docker run -d \
  -p 8000:8000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

echo "=== 5. Deploying Container Stacks from GitHub Repo ==="
if [ -f /opt/homelab-migration/docker/docker-compose.yml ]; then
  docker compose -f /opt/homelab-migration/docker/docker-compose.yml up -d
fi

echo "=== Ghidorah Provisioning Complete ==="
