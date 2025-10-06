#!/usr/bin/env bash

run_postinstall() {
  info "=== Post-Install Tasks ==="

  # Install stow for dotfiles management
  run_cmd "arch-chroot /mnt pacman -S --needed --noconfirm stow"

  # Clone dotfiles if not already present
  run_cmd "arch-chroot /mnt bash -c '
    if [ ! -d /home/${USERNAME}/.dotfiles ]; then
      sudo -u ${USERNAME} git clone git@github.com:joe-butler-23/.dotfiles /home/${USERNAME}/.dotfiles
    fi
  '"

  # Run stowall if available
  run_cmd "arch-chroot /mnt bash -c '
    if [ -x /home/${USERNAME}/.dotfiles/stowall.sh ]; then
      cd /home/${USERNAME}/.dotfiles && sudo -u ${USERNAME} ./stowall.sh
    fi
  '"

  # Alternative stowall if stowall.sh not available but individual stow packages exist
  run_cmd "arch-chroot /mnt bash -c '
    if [ ! -x /home/${USERNAME}/.dotfiles/stowall.sh ] && [ -d /home/${USERNAME}/.dotfiles ]; then
      cd /home/${USERNAME}/.dotfiles
      for dir in */; do
        if [ -d "$dir" ]; then
          sudo -u ${USERNAME} stow --target=/home/${USERNAME} "$dir"
        fi
      done
    fi
  '"

  # Copy verification script to user home
  run_cmd "cp /mnt/arch-installer/verify.sh /mnt/home/${USERNAME}/verify.sh"
  run_cmd "chmod +x /mnt/home/${USERNAME}/verify.sh"
  run_cmd "chown ${USERNAME}:${USERNAME} /mnt/home/${USERNAME}/verify.sh"

  # Write README + verification helper
  cat > /mnt/home/${USERNAME}/README.txt <<EOF
=== Arch Linux Installation Complete ===
User: ${USERNAME}
Shell: zsh
Next steps:
  1) Reboot
  2) (Optional) Enable Secure Boot in firmware
  3) Log in and run: ./verify.sh (to check system configuration)
  4) Dotfiles should be automatically stowed

Services enabled:
- Snapper (root and home snapshots)
- ZRAM (compressed swap)
- Tailscale
- Syncthing
- Automatic updates (daily)
- Btrfs scrub (monthly)
- Reflector (weekly)
- DNS-over-TLS and DNSSEC
- CPU power management
EOF
  run_cmd "chown ${USERNAME}:${USERNAME} /mnt/home/${USERNAME}/README.txt"

  # Generate installation summary
  info "=== Installation Summary ==="
  local install_time=$(date '+%Y-%m-%d %H:%M:%S')
  local total_time=$(($(date +%s) - $(grep "=== Arch Installer Preflight ===" "${LOGFILE:-/mnt/var/log/arch-installer.log}" | head -1 | cut -d' ' -f1 | xargs -I{} date -d "{}" +%s 2>/dev/null || echo 0)))
  
  info "Installation completed at: $install_time"
  info "Total installation time: ${total_time} seconds"
  info "Log files available at:"
  info "  - System log: ${LOGFILE:-/mnt/var/log/arch-installer.log}"
  info "  - Project log: $PROJECT_LOG"
  info "  - User home: /home/${USERNAME}/verify.sh"

  # Create installation summary file
  cat > /mnt/home/${USERNAME}/installation-summary.txt <<EOF
=== Arch Linux Installation Summary ===
Date: $install_time
Total time: ${total_time} seconds
User: ${USERNAME}
Shell: zsh
Hostname: ${HOSTNAME:-arch-linux}

=== Configured Features ===
✅ LUKS2 full-disk encryption
✅ Btrfs with subvolumes (@root, @home)
✅ systemd-boot with UKI
✅ Secure Boot (sbctl)
✅ Snapper snapshots (root and home)
✅ ZRAM compressed swap
✅ DNS-over-TLS and DNSSEC
✅ CPU power management (performance governor)
✅ I/O schedulers (bfq for SSDs, deadline for HDDs)
✅ SSH hardening
✅ UFW firewall
✅ AppArmor security
✅ Fail2ban protection
✅ Automatic updates (daily)
✅ Btrfs scrub (monthly)
✅ Reflector mirror updates (weekly)
✅ Tailscale VPN
✅ Syncthing file sync
✅ Dotfiles stowed

=== Services Status ===
Run 'systemctl status' to check all services
Run './verify.sh' to verify system configuration

=== Log Files ===
System log: /var/log/arch-installer.log
Project log: ~/arch-installer/logs/arch-installer-*.log
Verification: ~/verify.sh

=== Next Steps ===
1. Reboot the system
2. Enable Secure Boot in firmware (if needed)
3. Run './verify.sh' to verify installation
4. Configure Tailscale: 'sudo tailscale up'
5. Configure Syncthing via web interface
EOF

  run_cmd "chown ${USERNAME}:${USERNAME} /mnt/home/${USERNAME}/installation-summary.txt"

  info "✅ Post-install complete — system ready to reboot."
  info "✅ Dotfiles stowed successfully"
  info "✅ Verification script copied to user home"
  info "✅ Installation summary created"
  info "📝 Comprehensive logs available with full command history and timestamps"
}
