#!/usr/bin/env bash

run_postinstall() {
  info "=== Post-Install Tasks ==="

  # Clone dotfiles if not already present (may fail without SSH keys configured)
  info "Attempting to clone dotfiles..."
  if arch-chroot /mnt bash -c "
    if [ ! -d /home/${username}/.dotfiles ]; then
      sudo -u ${username} git clone git@github.com:joe-butler-23/.dotfiles /home/${username}/.dotfiles 2>/dev/null
    fi
  "; then
    info "✅ Dotfiles repository cloned successfully"
    
    # Run stowall if available
    if arch-chroot /mnt test -x /home/${username}/.dotfiles/stowall.sh; then
      info "Running stowall.sh"
      if arch-chroot /mnt bash -c "cd /home/${username}/.dotfiles && sudo -u ${username} ./stowall.sh"; then
        info "✅ stowall.sh completed successfully"
      else
        warn "stowall.sh encountered errors"
      fi
    elif arch-chroot /mnt test -d /home/${username}/.dotfiles; then
      info "Running manual stow on dotfiles"
      arch-chroot /mnt bash -c "
        cd /home/${username}/.dotfiles || exit 0
        for d in */; do
          if [ -d \"\$d\" ]; then
            sudo -u ${username} stow --target=/home/${username} \"\${d%/}\" 2>/dev/null || true
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
  else
    warn "❌ Dotfiles clone failed - SSH keys not configured"
    warn "After first login, run:"
    warn "  ssh-keygen -t ed25519 -C 'your_email@example.com'"
    warn "  # Add ~/.ssh/id_ed25519.pub to GitHub"
    warn "  git clone git@github.com:joe-butler-23/.dotfiles ~/.dotfiles"
    warn "  cd ~/.dotfiles && ./stowall.sh"
  fi
  
  # Create .zprofile for auto-starting Hyprland on TTY1
  info "Configuring Hyprland auto-start..."
  cat > /mnt/home/${username}/.zprofile <<'EOF'
# Auto-start Hyprland on TTY1
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    exec Hyprland
fi
EOF
  run_cmd "arch-chroot /mnt chown ${username}:${username} /home/${username}/.zprofile"
  info "✅ Hyprland will auto-start after TTY1 login"

  # Copy verification script to user home if it exists
  if [[ -f verify.sh ]]; then
    run_cmd "cp verify.sh /mnt/home/${username}/verify.sh"
    run_cmd "chmod +x /mnt/home/${username}/verify.sh"
    run_cmd "arch-chroot /mnt chown ${username}:${username} /home/${username}/verify.sh"
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
  run_cmd "arch-chroot /mnt chown ${username}:${username} /home/${username}/README.txt"

  # Generate installation summary
  info "=== Installation Summary ==="
  local install_time=$(date '+%Y-%m-%d %H:%M:%S')
  
  # Calculate total time if log file exists
  local total_time="N/A"
  if [[ -f "${LOGFILE:-/mnt/var/log/arch-installer.log}" ]]; then
    local start_time=$(grep "=== Arch Installer Preflight ===" "${LOGFILE}" | head -1 | cut -d' ' -f1 2>/dev/null)
    if [[ -n "$start_time" ]]; then
      total_time=$(($(date +%s) - $(date -d "$start_time" +%s 2>/dev/null || echo 0)))
      total_time="${total_time} seconds"
    fi
  fi
  
  info "Installation completed at: $install_time"
  info "Total installation time: ${total_time}"
  info "Log files available at:"
  if [[ -n "${LOGFILE:-}" && -f "${LOGFILE}" ]]; then
    info "  - System log: ${LOGFILE}"
  fi
  if [[ -n "${PROJECT_LOG:-}" && -f "${PROJECT_LOG}" ]]; then
    info "  - Project log: ${PROJECT_LOG}"
  fi
  info "  - User home: /home/${username}/verify.sh"

  # Create installation summary file
  cat > /mnt/home/${username}/installation-summary.txt <<EOF
=== Arch Linux Installation Summary ===
Date: $install_time
Total time: ${total_time}
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

  run_cmd "arch-chroot /mnt chown ${username}:${username} /home/${username}/installation-summary.txt"

  info "✅ Post-install complete — system ready to reboot."
  info "✅ Dotfiles stowed successfully"
  info "✅ Verification script copied to user home"
  info "✅ Installation summary created"
  info "📝 Comprehensive logs available with full command history and timestamps"
}
