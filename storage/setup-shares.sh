#!/usr/bin/env bash
set -euo pipefail

DATA_UUID="3b091420-5b11-41d1-817f-e2e74dc63e8c"
MOUNT_POINT="/mnt/NAS"

echo "=== Configuring Network Disk Mount ==="
mkdir -p "$MOUNT_POINT"

# Add persistent mount to /etc/fstab if not present
if ! grep -q "$DATA_UUID" /etc/fstab; then
  echo "UUID=$DATA_UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
  mount -a
fi

echo "=== Configuring Samba Network Share ==="
cat << 'EOF' > /etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   server string = Ghidorah File Server
   security = user
   map to guest = Bad User

[NAS]
   path = /mnt/NAS
   browseable = yes
   read only = no
   guest ok = no
   valid users = Serverkg
EOF

# Sync Samba user password with system user
(echo "rycloud"; echo "rycloud") | smbpasswd -s -a Serverkg
systemctl restart smbd
systemctl enable smbd nmbd

echo "=== Configuring NFS Kernel Server Export ==="
NFS_EXPORT_LINE="$MOUNT_POINT *(rw,sync,no_subtree_check,no_root_squash)"

if ! grep -q "$MOUNT_POINT" /etc/exports; then
  echo "$NFS_EXPORT_LINE" >> /etc/exports
  exportfs -a
  systemctl restart nfs-kernel-server
  systemctl enable nfs-server
fi

echo "=== Storage & Shares Fully Configured ==="
