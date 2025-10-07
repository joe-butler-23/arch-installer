# 🚀 Arch Linux Installer

A complete, modular Arch Linux installation system with full-disk encryption, Btrfs, Hyprland desktop, and modern security features.

---

## ✨ What Gets Installed

### Core System

*   🔐 **LUKS2 full-disk encryption** with Argon2id
*   📦 **Btrfs filesystem** with optimised subvolumes and compression
*   🥾 **systemd-boot** bootloader with Unified Kernel Images (UKI)
*   🔒 **Secure Boot** ready (sbctl)
*   📸 **Snapper** automatic snapshots for root and home

### Desktop Environment

*   🪟 **Hyprland** Wayland compositor
*   📊 **Waybar** status bar
*   🚀 **Kitty** terminal emulator
*   🎨 **Wofi** application launcher
*   🔔 **Dunst** notification daemon
*   🖼️ **Grim + Slurp** screenshots

### Security & Hardening

*   🛡️ **UFW** firewall (default deny incoming)
*   🔐 **AppArmor** mandatory access control
*   🚫 **Fail2ban** intrusion prevention
*   🔑 **SSH hardening** (key-based auth recommended)

### Services & Utilities

*   🗜️ **ZRAM** compressed swap
*   🌐 **Tailscale** VPN
*   🔄 **Syncthing** file synchronisation
*   📡 **DNS-over-TLS** and DNSSEC
*   ⚡ **CPU power management**
*   🔄 **Automatic updates** (daily)
*   🧹 **Automatic snapshots cleanup** (weekly)
*   🪞 **Mirror updates** via reflector (weekly)
*   🔍 **Btrfs scrub** for data integrity (monthly)

---

## 📋 Pre-Installation Steps

### Requirements

*   Target machine with UEFI firmware
*   Arch Linux installation ISO
*   Internet connection (Wi-Fi or Ethernet)
*   Another computer for SSH access

### Boot the Arch ISO

1.  Download the latest Arch Linux ISO from https://archlinux.org/download/
2.  Create a bootable USB drive
3.  Boot the target machine from the USB
4.  Select "Arch Linux install medium" from the boot menu

---

## 🌐 Step 1: Connect to Wi-Fi (if needed)

If using Wi-Fi, connect using iwctl:

```
iwctl
```

Inside iwctl:

```
device list                           # List wireless devices
station wlan0 scan                    # Scan for networks
station wlan0 get-networks           # Show available networks
station wlan0 connect "YourWifiName" # Connect (will prompt for password)
exit
```

Verify connectivity:

```
ping -c3 archlinux.org
```

---

## 🔌 Step 2: Enable SSH Access

On the **target machine** (Arch ISO):

```
# Start SSH daemon
systemctl start sshd

# Set a temporary root password
passwd

# Find your IP address
ip a
```

Look for your IP address (e.g., `192.168.0.190` under `wlan0` or `eth0`).

---

## 💻 Step 3: SSH from Another Computer

From your **laptop/another computer**:

```
ssh root@192.168.x.xxx
```

Replace `192.168.x.xxx` with the target machine's IP.

---

---

## ⚙️ Step 4: Configure Installation

The installer uses a YAML configuration file. For a desktop installation with Hyprland:

```
# Review the desktop configuration
cat config/desktop.yaml
```

The configuration includes:

*   Hostname and username
*   Locale, keyboard, timezone
*   Kernel choice (linux-zen)
*   All features enabled (encryption, Secure Boot, etc.)
*   Dotfiles repository

---

## 🚀 Step 5: Run the Installation

```
# Run the bootstrap
sudo bash bootstrap.sh
```
```
# Run the installer
sudo bash install.sh --config config/desktop.yaml
```

### What Happens During Installation

1.  **Preflight checks** - Verifies environment and tools
2.  **Configuration loading** - Loads settings from YAML
3.  **Password prompts** - You'll be asked for:
    *   Encryption password (twice for confirmation)
    *   Root password (twice for confirmation)
    *   User password (twice for confirmation)
4.  **Disk partitioning** - Creates ESP and encrypted root partition
5.  **LUKS encryption** - Sets up encrypted container
6.  **Btrfs setup** - Creates filesystem with subvolumes
7.  **Base system install** - Installs packages (including GUI)
8.  **Chroot configuration** - Sets up bootloader and system
9.  **User creation** - Creates your user account
10.  **Network setup** - Configures networking
11.  **Services** - Enables all system services and timers
12.  **Post-install** - Attempts to clone dotfiles and configure auto-start

### Progress Indication

*   Green `[ • ]` - Information messages
*   Yellow `[ ! ]` - Warnings (non-fatal)
*   Red `[ ✗ ]` - Errors (fatal)

---

## 📝 Step 7: Review Installation Results

After installation completes, check the logs:

```
# View the installation log
less logs/arch-installer-*.log

# Check for any errors or warnings
grep -i "error\|warn" logs/arch-installer-*.log
```

---

## 🔄 Step 8: Reboot

```
# Unmount everything
umount -R /mnt

# Reboot into your new system
reboot
```

---

## 🎯 Post-Installation Setup

### First Login

1.  **Boot the system** - It will boot to a TTY login screen
2.  **Log in** with your username and password
3.  **Hyprland will auto-start** - You'll be taken directly to the desktop

### If Dotfiles Clone Failed During Installation

If you see the zsh configuration wizard, your dotfiles weren't cloned (SSH keys not configured). Do this:

```
# Press 'q' to quit the zsh wizard

# Generate SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Display public key
cat ~/.ssh/id_ed25519.pub
# Copy this and add it to your GitHub account (Settings → SSH Keys)

# Clone your dotfiles
git clone git@github.com:joe-butler-23/.dotfiles ~/.dotfiles
cd ~/.dotfiles
./stowall.sh

# Create auto-start for Hyprland
cat > ~/.zprofile << 'EOF'
# Auto-start Hyprland on TTY1
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    exec Hyprland
fi
EOF

# Start Hyprland now or reboot
Hyprland
```

### Configure Secure Boot (Optional but Recommended)

Secure Boot keys were created during installation but need to be enrolled:

1.  **Reboot** and enter UEFI/BIOS (usually Del, F2, or F12 during boot)
2.  **Navigate to Secure Boot settings**
3.  **Delete/Clear all Secure Boot keys** - This puts the system in "Setup Mode"
4.  **Save and exit** UEFI
5.  **Boot into Arch Linux**
6.  **Enroll the keys**:
7.  **Reboot** and enter UEFI again
8.  **Enable Secure Boot**
9.  **Boot into Arch** - System will boot with Secure Boot enabled

### Verify Secure Boot Status

```
# Check if Secure Boot is enabled
sudo sbctl status

# Verify all boot files are signed
sudo sbctl verify
```

### Configure UFW Firewall

The firewall was partially configured during installation but needs finalisation after first boot:

```
# Enable UFW if not already running
sudo systemctl start ufw
sudo systemctl enable ufw

# Verify firewall rules
sudo ufw status verbose

# Should show:
# - Default: deny incoming
# - Default: allow outgoing
# - SSH port rate-limited
```

### Configure Services

#### Tailscale VPN

```
# Start and enable Tailscale
sudo systemctl start tailscaled
sudo systemctl enable tailscaled

# Connect to your Tailscale network
sudo tailscale up
```

#### Syncthing File Sync

```
# Start Syncthing (already enabled for your user)
systemctl --user start syncthing

# Access web interface
# Open browser to: http://localhost:8384
```

### Verify Installation

Run the verification script:

```
./verify.sh
```

This checks:

*   Encryption status
*   Btrfs subvolumes
*   Boot configuration
*   Services status
*   Security settings

---

## 🔧 Continuation Script

If installation was interrupted, you can continue from a specific module:

```
# Continue from where it left off (module 04)
sudo bash continue-install.sh --config config/desktop.yaml

# Start from a specific module (e.g., module 07)
sudo bash continue-install.sh --start 07 --config config/desktop.yaml
```

Available starting points: 04, 05, 06, 07, 08

---

## 📦 Package Management

### packages.txt

The installer uses `packages.txt` to define additional packages. Edit this file to customise your installation:

```
# packages.txt format:
# - One package per line
# - Comments start with #
# - Alphabetically sorted for easy management
```

Current packages include:

*   All GUI packages (Hyprland, Waybar, Wofi, etc.)
*   Security tools (AppArmor, UFW, Fail2ban)
*   System utilities (Snapper, ZRAM, Tailscale, Syncthing)
*   Development tools

### Adding More Packages

After installation, install additional packages with:

```
sudo pacman -S package-name
```

Or add them to `packages.txt` and reinstall.

---

## 🔌 SSH Connection Troubleshooting

### SSH Authentication Failures

If you encounter "Too many authentication failures" when connecting:

```
# Clear old SSH host keys
ssh-keygen -R <IP_ADDRESS>

# Connect with password-only authentication
ssh -o IdentitiesOnly=yes -o PreferredAuthentications=password user@<IP_ADDRESS>

# If SSH is on non-standard port
ssh -p <PORT> -o IdentitiesOnly=yes user@<IP_ADDRESS>
```

### SSH Service Not Running

After reboot, SSH may not be enabled:

```
# On the target machine (via direct console access)
sudo systemctl enable sshd
sudo systemctl start sshd

# Allow SSH through firewall
sudo ufw allow ssh

# Check SSH status
sudo systemctl status sshd
```

### SSH Port Configuration

If SSH is configured on a non-standard port (e.g., port 24):

```
# Connect with specific port
ssh -p 24 user@<IP_ADDRESS>

# Copy files with specific port
scp -P 24 file.txt user@<IP_ADDRESS>:~/
```

---

## 📦 Manual Post-Install Steps

If the automatic package installation or dotfiles cloning failed during the main installation, complete these steps manually:

### Install Missing Packages

```
# Download packages.txt to the target machine
curl -O https://raw.githubusercontent.com/joe-butler-23/arch-installer/main/packages.txt

# Install all packages
sudo pacman -S --needed $(grep -v '^#' packages.txt | grep -v '^$' | tr '\n' ' ')
```

### Copy Dotfiles from Another Machine

```
# From your laptop/another computer
scp -r ~/.dotfiles user@<IP_ADDRESS>:~/

# Or clone from GitHub (if public or SSH keys configured)
git clone https://github.com/joe-butler-23/.dotfiles ~/.dotfiles
cd ~/.dotfiles
./stowall.sh
```

### Configure Desktop Environment

```
# Ensure Hyprland starts on TTY1
cat > ~/.zprofile << 'EOF'
# Auto-start Hyprland on TTY1
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    exec Hyprland
fi
EOF

# Start Hyprland immediately or reboot
Hyprland
```

---

## 🐛 Troubleshooting

### Hyprland Doesn't Start

```
# Check if Hyprland is installed
pacman -Q hyprland

# Check logs
journalctl -xe

# Try starting manually
Hyprland
```

### Dotfiles Missing

```
# Check if dotfiles exist
ls -la ~/.dotfiles

# If not, clone them
git clone git@github.com/joe-butler-23/.dotfiles ~/.dotfiles
cd ~/.dotfiles
./stowall.sh
```

### Network Not Working

```
# Check network services
sudo systemctl status systemd-networkd
sudo systemctl status systemd-resolved
sudo systemctl status iwd

# Restart if needed
sudo systemctl restart systemd-networkd
```

### Can't Connect to Wi-Fi

```
# Use iwctl
iwctl

# In iwctl:
station wlan0 connect "YourWifiName"
```

---

## 📚 Additional Resources

*   [Arch Wiki](https://wiki.archlinux.org/)
*   [Hyprland Documentation](https://wiki.hyprland.org/)
*   [systemd-boot](https://wiki.archlinux.org/title/Systemd-boot)
*   [LUKS](https://wiki.archlinux.org/title/Dm-crypt)
*   [Btrfs](https://wiki.archlinux.org/title/Btrfs)

---

## 📄 Licence

This project is provided as-is for personal use. Modify as needed.

---

## 🤝 Contributing

This is a personal installation system, but suggestions are welcome via issues or pull requests.

```
sudo sbctl enroll-keys -m
```
