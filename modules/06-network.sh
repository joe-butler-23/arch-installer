#!/usr/bin/env bash

run_network() {
  info "=== Network Configuration ==="

  mkdir -p /mnt/etc/systemd/network

  cat > /mnt/etc/systemd/network/20-wired.network <<'EOF'
[Match]
Name=en*

[Network]
DHCP=yes
DNS=1.1.1.1
DNS=1.0.0.1
EOF

  cat > /mnt/etc/systemd/network/25-wireless.network <<'EOF'
[Match]
Name=wl*

[Network]
DHCP=yes
DNS=1.1.1.1
DNS=1.0.0.1
EOF

  ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

  run_cmd "arch-chroot /mnt systemctl enable systemd-networkd systemd-resolved iwd"

  info "Network configuration complete"
}
