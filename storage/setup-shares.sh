#!/usr/bin/env bash
set -euo pipefail

# Drive 1: Primary NAS Drive (ext4 - Shared over network)
DATA_UUID="3b091420-5b11-41d1-817f-e2e74dc63e8c"
MOUNT_POINT="/mnt/NAS"

# Drive 2: Second Drive (NTFS - Local use only)
DATA_UUID_2="F2B46C4FB46C187D"
MOUNT_POINT_2="/mnt/NAS2"

echo "=== Configuring Network Disk Mounts ==="
mkdir -p "$MOUNT_POINT" "$MOUNT_POINT_2"

# 1. Mount Primary Drive (ext4)
if ! grep -q "$DATA_UUID" /etc/fstab; then
  echo "UUID=$DATA_UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
fi

# 2. Mount Second Drive (NTFS with your custom flags)
if ! grep -q "$DATA_UUID_2" /etc/fstab; then
  echo "UUID=$DATA_UUID_2 $MOUNT_POINT_2 ntfs-3g defaults,nolearn,uid=1000,gid=1000,umask=0000,utf8 0 0" >> /etc/fstab
fi

# Apply all fstab mounts
mount -a

echo "=== Configuring Samba Network Share (Primary Only) ==="
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

echo "=== Configuring NFS Kernel Server Export (Primary Only) ==="
NFS_EXPORT_1="$MOUNT_POINT *(rw,sync,no_subtree_check,no_root_squash)"

if ! grep -q "$MOUNT_POINT" /etc/exports; then
  echo "$NFS_EXPORT_1" >> /etc/exports
fi

exportfs -a
systemctl restart nfs-kernel-server
systemctl enable nfs-server

echo "=== Storage & Primary Share Fully Configured (NAS2 is local-only) ==="
