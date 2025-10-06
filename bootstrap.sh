#!/usr/bin/env bash
set -euo pipefail

echo "[ • ] Setting up SSH for GitHub access"
mkdir -p ~/.ssh && chmod 700 ~/.ssh

if [ ! -f ~/.ssh/id_ed25519 ]; then
  echo "[ • ] Generating new SSH key"
  ssh-keygen -t ed25519 -C "arch-bootstrap"
fi

ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null

echo "[ • ] Cloning repositories"
cd ~
git clone git@github.com:joe-butler-23/arch-installer.git || true
git clone git@github.com:joe-butler-23/.dotfiles.git || true

echo "[ ✓ ] All ready — run:"
echo "bash ~/arch-installer/install.sh"
