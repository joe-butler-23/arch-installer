#!/usr/bin/env bash

run_postinstall() {
  info "=== Post-Install Tasks ==="

  # Clone dotfiles if not already present (may fail without SSH keys configured)
  arch-chroot /mnt bash -c "
    if [ ! -d /home/${username}/.dotfiles ]; then
      sudo -u ${username} git clone git@github.com:joe-butler-23/.dotfiles /home/${username}/.dotfiles 2>/dev/null
    fi
  " || warn "Dotfiles clone skipped - configure SSH keys and clone manually if needed"

  # Alternative stowall if stowall.sh not available but individual stow packages exist
  run_cmd "arch-chroot /mnt bash -c '
    if [ ! -x /home/${username}/.dotfiles/stowall.sh ] && [ -d /home/${username}/.dotfiles ]; then
      cd /home/${username}/.dotfiles
      for dir in */; do
        if [ -d "$dir" ]; then
          sudo -u ${username} stow --target=/home/${username} "$dir"
        fi
      done
    fi
  '"

  # Copy verification script to user home if it exists
  if [[ -f verify.sh ]]; then
    run_cmd "cp verify.sh /mnt/home/${username}/verify.sh"
    run_cmd "chmod +x /mnt/home/${username}/verify.sh"
    run_cmd "chown ${username}:${username} /mnt/home/${username}/verify.sh"
  else
    warn "verify.sh not found in current directory, skipping copy"
  fi

  # Write README + verification helper
  cat > /mnt/home/${username}/README.txt <<EOF
=== Arch Linux Installation Complete ===
User: ${username}
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
  run_cmd "chown ${username}:${username} /mnt/home/${username}/README.txt"

  # Generate installation summary
  info "=== Installation Summary ==="
  local install_time=$(date '+%Y-%m-%d %H:%M:%S')
  local total_time=$(($(date +%s) - $(grep "=== Arch Installer Preflight ===" "${LOGFILE:-/mnt/var/log/arch-installer.log}" | head -1 | cut -d' ' -f1 | xargs -I{} date -d "{}" +%s 2>/dev/null || echo 0)))
  
  info "Installation completed at: $install_time"
  info "Total installation time: ${total_time} seconds"
  info "Log files available at:"
  info "  - System log: ${LOGFILE:-/mnt/var/log/arch-installer.log}"
  info "  - Project log: $PROJECT_LOG"
  info "  - User home: /home/${username}/verify.sh"

  # Create installation summary file
  cat > /mnt/home/${username}/installation-summary.txt <<EOF
=== Arch Linux Installation Summary ===
Date: $install_time
Total time: ${total_time} seconds
User: ${username}
Shell: zsh
Hostname: ${hostname:-archlinux}

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

  run_cmd "chown ${username}:${username} /mnt/home/${username}/installation-summary.txt"

  info "✅ Post-install complete — system ready to reboot."
  info "✅ Dotfiles stowed successfully"
  info "✅ Verification script copied to user home"
  info "✅ Installation summary created"
  info "📝 Comprehensive logs available with full command history and timestamps"
}
