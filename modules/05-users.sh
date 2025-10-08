#!/usr/bin/env bash

run_users() {
  info "=== Final User Configuration ==="

  # Root password (already collected in step 1)
  if [[ -n "${root_password:-}" ]]; then
    run_cmd "echo 'root:${root_password}' | arch-chroot /mnt chpasswd"
    info "✅ Root password set"
  fi

  # SSH hardening
  info "Configuring SSH hardening"
  cat > /mnt/etc/ssh/sshd_config <<'EOF'
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
  info "✅ SSH configuration completed"
}
