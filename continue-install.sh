#!/usr/bin/env bash
set -euo pipefail

# Continuation script for Arch installer - starts from chroot setup
# Use this if base installation (modules 00-03) has already completed

# Load helper modules
for m in modules/utils.sh modules/00-*.sh modules/01-*.sh; do
  source "$m"
done

# Parse arguments
CONFIG_FILE="config/desktop.yaml"
START_MODULE="04"

while [[ $# -gt 0 ]]; do
  case $1 in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --start)
      START_MODULE="$2"
      shift 2
      ;;
    *)
      CONFIG_FILE="$1"
      shift
      ;;
  esac
done

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Configuration file not found: $CONFIG_FILE"
  echo "Usage: $0 [--config <config-file>] [--start <module-number>]"
  echo "  --config: Path to configuration file (default: config/desktop.yaml)"
  echo "  --start:  Starting module number: 04-08 (default: 04)"
  exit 1
fi

# Initialize required variables
DRYRUN=false
export DRYRUN

# Source config module to load variables
source modules/01-config.sh
load_config "$CONFIG_FILE"

# Validate we're running as root
[[ $EUID -eq 0 ]] || die "Run as root."

# Validate /mnt is mounted
if ! mountpoint -q /mnt; then
  die "/mnt is not mounted. Cannot continue installation."
fi

echo "=== Continuing Arch Installation ==="
echo "Configuration: $CONFIG_FILE"
echo "Starting from module: $START_MODULE"
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
for m in modules/04-*.sh modules/05-*.sh modules/06-*.sh modules/07-*.sh modules/08-*.sh modules/09-*.sh; do
  if [[ -f "$m" ]]; then
    source "$m"
  fi
done

# Run the installation phases based on starting module
case "$START_MODULE" in
  04)
    info "=== Starting from Module 04: Chroot Setup ==="
    run_chroot_setup
    ;&  # Fall through to next case
  05)
    info "=== Module 05: Users and Permissions ==="
    # Note: Module 05 functionality has been integrated into Module 04
    ;&  # Fall through to next case
  06)
    info "=== Module 06: Network Configuration ==="
    run_network
    ;&  # Fall through to next case
  07)
    info "=== Module 07: Services ==="
    run_services
    ;&  # Fall through to next case
  08)
    info "=== Module 08: Post-Installation ==="
    run_postinstall
    ;&  # Fall through to next case
  09)
    info "=== Module 09: UWSM Setup ==="
    run_uwsm_setup
    ;;
  *)
    die "Invalid start module: $START_MODULE. Must be 04-09."
    ;;
esac

info ""
info "✅ Installation continuation complete!"
info ""
info "Next steps:"
info "1. Review the installation log"
info "2. Reboot into your new system"
info "3. Check that all services are running"
