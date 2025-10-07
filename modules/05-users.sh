#!/usr/bin/env bash

run_users() {
  info "=== User Configuration ==="

  # Root password
  echo -n "Enter root password: "
  read -rs ROOTPASS; echo
  run_cmd "echo 'root:${ROOTPASS}' | arch-chroot /mnt chpasswd"

  # User creation with zsh as default shell
  info "Creating user ${username} with zsh shell"
  run_cmd "arch-chroot /mnt useradd -m -G wheel -s /bin/zsh ${username}"
  echo -n "Enter password for ${username}: "
  read -rs USERPASS; echo
  run_cmd "echo '${username}:${USERPASS}' | arch-chroot /mnt chpasswd"

  # sudo + doas
  info "Configuring sudo and doas"
  run_cmd "echo 'permit persist :wheel' > /mnt/etc/doas.conf"
  run_cmd "chmod 0400 /mnt/etc/doas.conf"
  run_cmd "mkdir -p /mnt/etc/sudoers.d"
  run_cmd "echo '%wheel ALL=(ALL:ALL) ALL' > /mnt/etc/sudoers.d/wheel"

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
}
