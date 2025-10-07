#!/usr/bin/env bash

run_services() {
  info "=== Services & Hardening ==="

  # Base security + power + bluetooth + zram + secure boot + additional tools
  PKGS="ufw apparmor fail2ban tlp tlp-rdw bluez bluez-utils zram-generator sbctl cpupower reflector"
  run_cmd "arch-chroot /mnt pacman -S --needed --noconfirm ${PKGS}"

  # Enable essential services
  SERVICES=(
    systemd-networkd.service systemd-resolved.service iwd.service
    ufw.service apparmor.service fail2ban.service tlp.service bluetooth.service
  )
  for s in "${SERVICES[@]}"; do
    run_cmd "arch-chroot /mnt systemctl enable $s || true"
  done

  info "Configuring UFW"
  # Note: UFW commands may fail in chroot due to missing kernel modules
  # They will work properly after booting into the installed system
  arch-chroot /mnt ufw --force default deny incoming || warn "UFW config will be applied after first boot"
  arch-chroot /mnt ufw --force default allow outgoing || true
  arch-chroot /mnt ufw limit ssh/tcp || true
  arch-chroot /mnt ufw --force enable || true

  info "Configuring AppArmor"
  run_cmd "arch-chroot /mnt systemctl enable apparmor"

  # Configure ZRAM
  info "Configuring ZRAM for compressed swap"
  cat > /mnt/etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = (RAM * 0.75)
compression-algorithm = zstd
fs-type = swap
EOF

  # Enable automatic update timers
  info "Configuring automatic update timers"
  
  # Create pacman update timer
  cat > /mnt/etc/systemd/system/pacman-update.service <<'EOF'
[Unit]
Description=Update system packages
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/pacman -Syu --noconfirm
EOF

  cat > /mnt/etc/systemd/system/pacman-update.timer <<'EOF'
[Unit]
Description=Run pacman update daily
Requires=pacman-update.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

  # Create snapshot cleanup timer for Snapper
  cat > /mnt/etc/systemd/system/snapper-cleanup.service <<'EOF'
[Unit]
Description=Cleanup old Snapper snapshots
Wants=local-fs.target
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/snapper cleanup
EOF

  cat > /mnt/etc/systemd/system/snapper-cleanup.timer <<'EOF'
[Unit]
Description=Run Snapper cleanup weekly
Requires=snapper-cleanup.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

  # Enable the timers
  run_cmd "arch-chroot /mnt systemctl enable pacman-update.timer"
  run_cmd "arch-chroot /mnt systemctl enable snapper-cleanup.timer"

  # Configure Secure Boot with sbctl
  info "Configuring Secure Boot with sbctl"
  
  # Create Secure Boot keys
  run_cmd "arch-chroot /mnt sbctl create-keys"
  
  # Enroll keys in UEFI firmware
  run_cmd "arch-chroot /mnt sbctl enroll-keys -m"
  
  # Sign all existing boot files
  run_cmd "arch-chroot /mnt sbctl sign -s /boot/EFI/Linux/arch-${kernel}.efi"
  run_cmd "arch-chroot /mnt sbctl sign -s /boot/EFI/Linux/arch-${kernel}-fallback.efi"
  
  # Create sbctl verification service
  cat > /mnt/etc/systemd/system/sbctl-verify.service <<'EOF'
[Unit]
Description=Verify Secure Boot signatures
Wants=local-fs.target
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/sbctl verify
EOF

  cat > /mnt/etc/systemd/system/sbctl-verify.timer <<'EOF'
[Unit]
Description=Run sbctl verification daily
Requires=sbctl-verify.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

  run_cmd "arch-chroot /mnt systemctl enable sbctl-verify.timer"

  # Configure CPU power management
  info "Configuring CPU power management"
  run_cmd "arch-chroot /mnt systemctl enable cpupower.service"
  
  # Create cpupower configuration
  cat > /mnt/etc/default/cpupower <<'EOF'
# CPUFREQ governor to use
governor="performance"

# Maximum and minimum CPU frequencies
max_freq="min"
min_freq="min"
EOF

  # Configure DNS-over-TLS and DNSSEC in resolved
  info "Configuring DNS-over-TLS and DNSSEC"
  cat > /mnt/etc/systemd/resolved.conf <<'EOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com
FallbackDNS=8.8.8.8 8.8.4.4
#DNSSEC=no
DNSSEC=yes
DNSOverTLS=yes
Cache=yes
EOF

  # Configure I/O schedulers
  info "Configuring I/O schedulers"
  cat > /mnt/etc/udev/rules.d/60-io-schedulers.rules <<'EOF'
# Set bfq scheduler for SSDs and NVMe
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
# Set deadline scheduler for HDDs
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="deadline"
EOF

  # Configure reflector timer for mirror updates
  info "Configuring reflector for automatic mirror updates"
  cat > /mnt/etc/systemd/system/reflector.service <<'EOF'
[Unit]
Description=Update pacman mirror list
Before=pacman-update.service
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/reflector --country 'United Kingdom' --latest 20 --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
EOF

  cat > /mnt/etc/systemd/system/reflector.timer <<'EOF'
[Unit]
Description=Run reflector weekly
Requires=reflector.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

  run_cmd "arch-chroot /mnt systemctl enable reflector.timer"

  # Configure Btrfs scrub timer
  info "Configuring Btrfs scrub timer"
  cat > /mnt/etc/systemd/system/btrfs-scrub.service <<'EOF'
[Unit]
Description=Btrfs scrub data integrity check
Wants=local-fs.target
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs scrub start /
EOF

  cat > /mnt/etc/systemd/system/btrfs-scrub.timer <<'EOF'
[Unit]
Description=Run Btrfs scrub monthly
Requires=btrfs-scrub.service

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
EOF

  run_cmd "arch-chroot /mnt systemctl enable btrfs-scrub.timer"

  # Configure pacman candy and other tweaks
  info "Configuring pacman improvements"
  cat >> /mnt/etc/pacman.conf <<'EOF'

# Color output
Color
# Verbose package lists
VerbosePkgLists
# Download progress bar
ILoveCandy

# Parallel downloads
ParallelDownloads = 5
EOF

  # Enable additional services
  ADDITIONAL_SERVICES=(
    syncthing@${username}.service
    tailscaled.service
  )
  for s in "${ADDITIONAL_SERVICES[@]}"; do
    run_cmd "arch-chroot /mnt systemctl enable $s || true"
  done

  info "✅ Secure Boot keys created and enrolled"
  info "✅ ZRAM configured for compressed swap"
  info "✅ Automatic update timers configured"
  info "✅ CPU power management configured"
  info "✅ DNS-over-TLS and DNSSEC configured"
  info "✅ I/O schedulers configured"
  info "✅ Reflector timer configured"
  info "✅ Btrfs scrub timer configured"
  info "✅ Pacman improvements configured"
  info "✅ Base services configured"
}
