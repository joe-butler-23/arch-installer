#!/usr/bin/env bash
set -euo pipefail

# Install git
pacman -Sy git

echo "[ • ] Cloning repositories"
cd ~
git clone https://github.com/joe-butler-23/arch-installer.git

echo "[ ✓ ] All ready — run:"
echo "bash ~/arch-installer/install.sh"
