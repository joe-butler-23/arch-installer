#!/usr/bin/env bash
set -euo pipefail

# Continuation script for Arch installer - starts from chroot setup
# Use this if base installation (modules 00-03) has already completed

# Load helper modules
for m in modules/utils.sh modules/00-*.sh modules/01-*.sh; do
  source "$m"
done

# Load configuration from YAML (or use defaults)
CONFIG_FILE="${1:-config/desktop.yaml}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Configuration file not found: $CONFIG_FILE"
  echo "Usage: $0 [config-file]"
  exit 1
fi

# Source config module to load variables
source modules/01-config.sh
load_config "$CONFIG_FILE"

# Validate we're running as root
[[ $EUID -eq 0 ]] || die "Run as root."

# Validate /mnt is mounted
if ! mountpoint -q /mnt; then
  die "/mnt is not mounted. Cannot continue installation."
fi

echo "=== Continuing Arch Installation from Chroot Setup ==="
echo "Configuration: $CONFIG_FILE"
echo "Disk: ${disk}"
echo "Kernel: ${kernel}"
echo "Hostname: ${hostname}"
echo ""
read -p "Continue with installation? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Installation cancelled."
  exit 0
fi

# Install snapper if not already installed
if ! arch-chroot /mnt pacman -Q snapper &>/dev/null; then
  echo "Installing snapper..."
  arch-chroot /mnt pacman -S --noconfirm snapper
fi

# Load and run remaining modules
for m in modules/04-*.sh modules/05-*.sh modules/06-*.sh modules/07-*.sh modules/08-*.sh; do
  if [[ -f "$m" ]]; then
    source "$m"
  fi
done

# Run the installation phases
info "=== Starting from Module 04: Chroot Setup ==="
run_chroot_setup

info "=== Module 05: Users and Permissions ==="
run_users

info "=== Module 06: Network Configuration ==="
run_network

info "=== Module 07: Services ==="
run_services

info "=== Module 08: Post-Installation ==="
run_postinstall

info ""
info "✅ Installation continuation complete!"
info ""
info "Next steps:"
info "1. Review the installation log"
info "2. Reboot into your new system"
info "3. Check that all services are running"
