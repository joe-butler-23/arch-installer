#!/usr/bin/env bash

run_chroot_setup() {
  info "=== Chroot Configuration ==="

  # User and SSH Configuration
  info "=== User and SSH Configuration ==="
  
  # Set root password from config (already collected in step 1)
  if [[ -n "${root_password:-}" ]]; then
    run_cmd "echo 'root:${root_password}' | arch-chroot /mnt chpasswd"
    info "✅ Root password set"
  fi

  if arch-chroot /mnt id "${username}" &>/dev/null; then
    info "User ${username} already exists, updating settings"
    run_cmd "arch-chroot /mnt usermod -s /bin/zsh -G wheel ${username}"
  else
    info "Creating user ${username} with zsh shell"
    run_cmd "arch-chroot /mnt useradd -m -G wheel -s /bin/zsh ${username}"
  fi
  
  # Set user password from config
  if [[ -n "${user_password:-}" ]]; then
    run_cmd "echo '${username}:${user_password}' | arch-chroot /mnt chpasswd"
    info "✅ User password set"
  fi
  
  # sudo + doas configuration
  info "Configuring sudo and doas"
  run_cmd "echo 'permit persist :wheel' > /mnt/etc/doas.conf"
  run_cmd "chmod 0400 /mnt/etc/doas.conf"
  run_cmd "mkdir -p /mnt/etc/sudoers.d"
  run_cmd "echo '%wheel ALL=(ALL:ALL) ALL' > /mnt/etc/sudoers.d/wheel"

  # SSH hardening
  info "Configuring SSH hardening"
  cat > /mnt/etc/ssh/sshd_config <<EOF
# SSH hardening configuration
Port 22
Protocol 2

# Authentication
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Security
X11Forwarding no
AllowTcpForwarding no
GatewayPorts no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 2

# Logging
SyslogFacility AUTH
LogLevel INFO

# User restrictions
AllowUsers ${username}
EOF

  # Restart SSH service to apply changes
  run_cmd "arch-chroot /mnt systemctl restart sshd.service"
  info "✅ User and SSH configuration completed"

  # Get LUKS UUID
  local cryptroot_partition="${disk}p2"
  luks_uuid=$(blkid -s UUID -o value "$cryptroot_partition")
  
  if [[ -z "$luks_uuid" ]]; then
    die "Failed to get LUKS UUID from $cryptroot_partition"
  fi

  # mkinitcpio hooks for systemd-init + sd-encrypt
  info "Configuring mkinitcpio for UKI"
  cat > /mnt/etc/mkinitcpio.conf <<'EOF'
HOOKS=(systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems fsck)
EOF

  # Create kernel cmdline for unified image
  mkdir -p /mnt/etc/kernel
  cat > /mnt/etc/kernel/cmdline <<EOF
rd.luks.name=${luks_uuid}=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet loglevel=3 apparmor=1 lsm=landlock,lockdown,yama,apparmor,bpf
EOF

  # Create crypttab for LUKS management
  info "Creating /etc/crypttab for LUKS management"
  echo "cryptroot UUID=${luks_uuid} none luks,discard" > /mnt/etc/crypttab

  # Configure UKI presets
  cat > /mnt/etc/mkinitcpio.d/${kernel}.preset <<EOF
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-${kernel}"
ALL_microcode=(/boot/*-ucode.img)

PRESETS=('default' 'fallback')

default_uki="/boot/EFI/Linux/arch-${kernel}.efi"
fallback_uki="/boot/EFI/Linux/arch-${kernel}-fallback.efi"
fallback_options="-S autodetect"
EOF

  # Create boot directory structure for UKI
  mkdir -p /mnt/boot/EFI/Linux

  info "Installing systemd-boot"
  run_cmd "arch-chroot /mnt bootctl install"

  cat > /mnt/boot/loader/loader.conf <<EOF
default arch-${kernel}.efi
timeout 3
console-mode max
editor no
EOF

  info "Building unified kernel images"
  run_cmd "arch-chroot /mnt mkinitcpio -P"

  # Configure Snapper for root and home subvolumes
  info "Configuring Snapper for @root and @home subvolumes"
  
  # Create Snapper configs
  cat > /mnt/etc/snapper/configs/root <<'EOF'
# Subvolume to snapshot
SUBVOLUME="/"

# Filesystem type
FSTYPE="btrfs"

# Users and groups allowed to work with snapshots
ALLOW_USERS=""
ALLOW_GROUPS=""

# Sync users and groups from OS to snapper
SYNC_ACL="no"

# Start timeline cleanup
TIMELINE_CREATE="yes"

# Timeline cleanup limits
TIMELINE_LIMIT_HOURLY="10"
TIMELINE_LIMIT_DAILY="10"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="10"
TIMELINE_LIMIT_YEARLY="0"

# Background cleanup limits
BACKGROUND_LIMIT_HOURLY="0"
BACKGROUND_LIMIT_DAILY="0"
BACKGROUND_LIMIT_WEEKLY="0"
BACKGROUND_LIMIT_MONTHLY="0"
BACKGROUND_LIMIT_YEARLY="0"

# Free space limits
FREE_LIMIT="5"

# Number cleanup limits
NUMBER_LIMIT="10"
NUMBER_MIN_AGE="1800"

# Empty pre/post snapshot cleanup limits
EMPTY_PRE_POST_MIN_AGE="1800"
EMPTY_PRE_POST_LIMIT="3"

# Timeline cleanup algorithm
TIMELINE_CLEANUP_ALGORITHM="number"

EOF

  cat > /mnt/etc/snapper/configs/home <<'EOF'
# Subvolume to snapshot
SUBVOLUME="/home"

# Filesystem type
FSTYPE="btrfs"

# Users and groups allowed to work with snapshots
ALLOW_USERS=""
ALLOW_GROUPS=""

# Sync users and groups from OS to snapper
SYNC_ACL="no"

# Start timeline cleanup
TIMELINE_CREATE="yes"

# Timeline cleanup limits
TIMELINE_LIMIT_HOURLY="10"
TIMELINE_LIMIT_DAILY="10"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="10"
TIMELINE_LIMIT_YEARLY="0"

# Background cleanup limits
BACKGROUND_LIMIT_HOURLY="0"
BACKGROUND_LIMIT_DAILY="0"
BACKGROUND_LIMIT_WEEKLY="0"
BACKGROUND_LIMIT_MONTHLY="0"
BACKGROUND_LIMIT_YEARLY="0"

# Free space limits
FREE_LIMIT="5"

# Number cleanup limits
NUMBER_LIMIT="10"
NUMBER_MIN_AGE="1800"

# Empty pre/post snapshot cleanup limits
EMPTY_PRE_POST_MIN_AGE="1800"
EMPTY_PRE_POST_LIMIT="3"

# Timeline cleanup algorithm
TIMELINE_CLEANUP_ALGORITHM="number"

EOF

  # Create snapper config directories
  run_cmd "mkdir -p /mnt/etc/snapper/configs"
  run_cmd "mkdir -p /mnt/.snapshots"
  run_cmd "mkdir -p /mnt/home/.snapshots"
  
  # Set proper permissions
  run_cmd "chmod 750 /mnt/.snapshots"
  run_cmd "chmod 750 /mnt/home/.snapshots"
  
  # Note: Snapper's create-config requires DBus which isn't available in chroot
  # The configuration files will be used when snapper runs after boot
  
  info "✅ Snapper configuration files created"
  info "   Note: Snapper will initialize on first boot"
  info "✅ UKI and systemd-boot configured"

  # Install additional packages from packages.txt
  info "=== Installing Additional Packages ==="
  
  if [[ -f packages.txt ]]; then
    info "Loading packages from packages.txt"
    # Read packages.txt, skip comments and empty lines
    pacman_packages=$(grep -v '^#' packages.txt | grep -v '^$' | tr '\n' ' ')
    info "Found $(echo $pacman_packages | wc -w) packages to install"
    
    # Install packages with error handling
    failed_packages=""
    for pkg in $pacman_packages; do
      info "Installing $pkg..."
      if ! arch-chroot /mnt pacman -S --needed --noconfirm "$pkg"; then
        warn "Failed to install $pkg via pacman"
        failed_packages="$failed_packages $pkg"
      else
        info "✅ $pkg installed successfully"
      fi
    done
    
    # Report any failures
    if [[ -n "$failed_packages" ]]; then
      warn "These packages failed to install via pacman: $failed_packages"
      warn "These may need to be installed via AUR or checked for correct names"
    fi
    
    info "✅ Package installation completed"
  else
    warn "packages.txt not found, skipping additional package installation"
  fi

  # AUR package installation removed for stability
  info "Skipping AUR package installation"

  # AUR package installation removed for stability

  # Verify critical packages are installed
  info "=== Verifying Critical Packages ==="
  critical_packages="mousepad localsend"
  missing_packages=""
  
  for pkg in $critical_packages; do
    if arch-chroot /mnt pacman -Q "$pkg" >/dev/null 2>&1; then
      info "✅ $pkg is installed"
    else
      warn "❌ $pkg is missing"
      missing_packages="$missing_packages $pkg"
    fi
  done
  
  if [[ -n "$missing_packages" ]]; then
    warn "Critical packages missing: $missing_packages"
    warn "These may need manual installation after boot"
  else
    info "✅ All critical packages verified"
  fi

  # Clone and setup dotfiles
  info "=== Setting up Dotfiles ==="
  
  # Remove any conflicting auto-generated configs
  info "Removing potential conflicting configurations..."
  run_cmd "rm -rf /mnt/home/${username}/.config/hyprland.conf"
  run_cmd "rm -rf /mnt/home/${username}/.config/hypr/"
  
  # Clone dotfiles with force
  info "Cloning dotfiles repository..."
  if arch-chroot /mnt bash -c "
    if [ -d /home/${username}/.dotfiles ]; then
      rm -rf /home/${username}/.dotfiles
    fi
    sudo -u ${username} git clone https://github.com/joe-butler-23/.dotfiles /home/${username}/.dotfiles
  "; then
    info "✅ Dotfiles cloned successfully"
    
    # Run stowall if available, otherwise manual stow
    if arch-chroot /mnt test -x /home/${username}/.dotfiles/stowall.sh; then
      info "Running stowall.sh"
      if arch-chroot /mnt bash -c "cd /home/${username}/.dotfiles && sudo -u ${username} ./stowall.sh"; then
        info "✅ stowall.sh completed successfully"
      else
        warn "stowall.sh encountered errors, trying manual stow"
        arch-chroot /mnt bash -c "
          cd /home/${username}/.dotfiles || exit 0
          for d in */; do
            if [ -d \"\$d\" ]; then
              sudo -u ${username} stow --target=/home/${username} --adopt -R \"\${d%/}\" 2>/dev/null || true
            fi
          done
        " && info "✅ Manual stow completed" || warn "Manual stow encountered errors"
      fi
    else
      info "Running manual stow on dotfiles"
      arch-chroot /mnt bash -c "
        cd /home/${username}/.dotfiles || exit 0
        for d in */; do
          if [ -d \"\$d\" ]; then
            sudo -u ${username} stow --target=/home/${username} --adopt -R \"\${d%/}\" 2>/dev/null || true
          fi
        done
      " && info "✅ Manual stow completed" || warn "Manual stow encountered errors"
    fi
    
    # Verify key dotfiles were created
    info "Verifying dotfiles installation..."
    local dotfiles_ok=true
    for dotfile in .zshrc .config/hypr/hyprland.conf; do
      if arch-chroot /mnt test -f /home/${username}/$dotfile; then
        info "  ✅ $dotfile present"
      else
        warn "  ❌ $dotfile missing"
        dotfiles_ok=false
      fi
    done
    
    if $dotfiles_ok; then
      info "✅ Dotfiles verification passed"
    else
      warn "⚠️  Some dotfiles are missing - manual setup may be needed"
    fi
    
  # Fix ownership
  run_cmd "arch-chroot /mnt chown -R ${username}:${username} /home/${username}/.dotfiles"
  run_cmd "arch-chroot /mnt chown -R ${username}:${username} /home/${username}/.config"
  
else
  warn "❌ Dotfiles clone failed"
  warn "After first login, run:"
  warn "  git clone https://github.com/joe-butler-23/.dotfiles ~/.dotfiles"
  warn "  cd ~/.dotfiles && ./stowall.sh"
fi

  # Install app2unit for fast UWSM application launching
  info "=== Installing app2unit ==="
  
  # Clone and install app2unit
  info "Cloning app2unit repository..."
  if arch-chroot /mnt bash -c "
    cd /tmp
    git clone https://github.com/waycrate/app2unit.git
    cd app2unit
    make install
    cd /
    rm -rf /tmp/app2unit
  "; then
    info "✅ app2unit installed successfully"
  else
    warn "❌ app2unit installation failed"
    warn "This may cause issues with UWSM application launching"
  fi
  
  # Verify app2unit installation
  if arch-chroot /mnt which app2unit >/dev/null 2>&1; then
    info "✅ app2unit verified and available"
  else
    warn "❌ app2unit not found in PATH"
  fi

info "✅ All package installation and dotfiles setup completed"
}
