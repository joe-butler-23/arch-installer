#!/usr/bin/env bash

run_uwsm_setup() {
  info "=== UWSM + app2unit Configuration ==="
  
  # Install app2unit from GitHub
  info "Installing app2unit..."
  run_cmd "arch-chroot /mnt git clone https://github.com/Vladimir-csp/app2unit.git /tmp/app2unit"
  run_cmd "arch-chroot /mnt bash -c 'cd /tmp/app2unit && make install'"
  run_cmd "arch-chroot /mnt rm -rf /tmp/app2unit"
  info "✅ app2unit installed to /usr/local/bin/"
  
  # Create UWSM configuration directory
  info "Creating UWSM configuration..."
  run_cmd "mkdir -p /mnt/home/${username}/.config/uwsm/env"
  run_cmd "mkdir -p /mnt/home/${username}/.config/uwsm/projects"
  
  # Create UWSM environment configuration
  cat > /mnt/home/${username}/.config/uwsm/env/default <<'EOF'
# GNOME Keyring environment for UWSM
export GNOME_KEYRING_CONTROL
export GNOME_KEYRING_PID
export GPG_AGENT_INFO
export SSH_AUTH_SOCK

# Start keyring daemon if not already running
if [ -z "$GNOME_KEYRING_PID" ]; then
    eval $(/usr/bin/gnome-keyring-daemon --start --components=gpg,pkcs11,secrets,ssh)
fi

# app2unit integration with UWSM custom slices
export APP2UNIT_SLICES='a=app-graphical.slice b=background-graphical.slice s=session-graphical.slice'
export APP2UNIT_TYPE=scope
EOF
  
  run_cmd "arch-chroot /mnt chown -R ${username}:${username} /home/${username}/.config/uwsm"
  info "✅ UWSM environment configured"
  
  # Create default hyprland desktop entry if needed
  info "Creating Hyprland desktop entry..."
  cat > /mnt/usr/share/applications/hyprland.desktop <<'EOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
Keywords=tiling;wayland;compositor;
EOF
  info "✅ Hyprland desktop entry created"
  
  # PAM configuration for keyring unlock
  info "Configuring PAM for automatic keyring unlock..."
  if ! grep -q "pam_gnome_keyring.so" /mnt/etc/pam.d/login; then
    sed -i '/auth.*include.*system-local-login/i auth       optional     pam_gnome_keyring.so' /mnt/etc/pam.d/login
    sed -i '/session.*include.*system-local-login/i session    optional     pam_gnome_keyring.so    auto_start' /mnt/etc/pam.d/login
    info "✅ PAM configured for keyring unlock"
  else
    info "PAM already configured for keyring"
  fi
  
  info "✅ UWSM + app2unit setup complete"
}

