#!/bin/bash
set -e

echo "=== Starting Post-Install Setup for HP Elite 8300 SFF ==="

# 1. Configure Intel CPU Power Governor (Intel P-State)
echo "Configuring CPU governor to powersave..."
echo 'GOVERNOR="powersave"' > /etc/default/cpufrequtils
systemctl restart cpufrequtils || true

# 2. Enable TLP Power Management
echo "Enabling TLP..."
systemctl enable tlp
systemctl start tlp

# 3. Create PowerTOP Auto-Tune Systemd Service
echo "Setting up PowerTOP auto-tune..."
cat << 'EOF' > /etc/systemd/system/powertop.service
[Unit]
Description=PowerTOP auto tune
After=syslog.target network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/powertop --auto-tune
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable powertop.service
systemctl start powertop.service

# 4. Force PCIe Active State Power Management (ASPM) in GRUB
echo "Enabling PCIe ASPM in GRUB..."
if ! grep -q "pcie_aspm=force" /etc/default/grub; then
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="pcie_aspm=force /' /etc/default/grub
    update-grub
fi

# 5. Configure Hard Drive Spindown (15-min idle) in /etc/hdparm.conf
echo "Configuring disk spindown timeouts..."
if ! grep -q "spindown_time = 180" /etc/hdparm.conf; then
cat << 'EOF' >> /etc/hdparm.conf

# Storage drive spindown settings (15 mins = 180)
/dev/disk/by-label/STORAGE {
    spindown_time = 180
    apm = 127
}
EOF
fi

# 6. Enable Wake-on-LAN (WoL) on Primary Ethernet
NIC=$(ip -o link show | awk -F': ' '$2 !~ "^lo|^veth|^docker" {print $2; exit}')
if [ -n "$NIC" ]; then
    echo "Enabling Wake-on-LAN on $NIC..."
    ethtool -s "$NIC" wol g || true
fi

# 7. Set Low Swappiness for 16GB RAM
echo "Optimizing memory swappiness..."
echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
sysctl -p /etc/sysctl.d/99-swappiness.conf

echo "=== Setup Complete! Please reboot the server. ==="
