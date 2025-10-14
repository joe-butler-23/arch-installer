# Arch Linux Installer

A complete, modular Arch Linux installation system with full-disk encryption, Btrfs, Hyprland desktop, and modern security features. Guide is written for installing over SSH

---

## Pre-Installation Steps

### Requirements

*   Target machine with UEFI firmware
*   Arch Linux installation ISO
*   Internet connection (Wi-Fi or Ethernet)
*   Another computer for SSH access

### Secure Boot Setup (Required)

**IMPORTANT**: Before starting installation, you must put your machine in Secure Boot Setup Mode:

1. **Boot into UEFI/BIOS** (usually Del, F2, or F12 during boot)
2. **Navigate to Secure Boot settings**
3. **Delete/Clear all existing Secure Boot keys** - This puts the system in "Setup Mode"
4. **Save and exit** UEFI
5. **Boot the Arch ISO** and proceed with installation

The installer will automatically create and enroll new Secure Boot keys during installation.

### Boot the Arch ISO

1.  Download the latest Arch Linux ISO from https://archlinux.org/download/
2.  Create a bootable USB drive
3.  Boot the target machine from the USB
4.  Select "Arch Linux install medium" from the boot menu

---

## 🌐 Step 1: Connect to Wi-Fi

If using Wi-Fi, connect using iwctl:

```
iwctl
```

Inside iwctl:

```
device list                             # List wireless devices
station wlan0 scan                      # Scan for networks
station wlan0 get-networks              # Show available networks
station wlan0 connect "YourWifiName"    # Connect (will prompt for password)
exit
```

Verify connectivity:

```
ping -c3 archlinux.org
```
Then enable SSH access:

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

## 💻 Step 2: SSH from Another Computer

From your **laptop/another computer**:

```
ssh root@192.168.x.xxx
```

Replace `192.168.x.xxx` with the target machine's IP.

---

---

## ⚙️ Step 3: Clone Installer and Configure

```
# Install git
pacman -Sy git

# Clone repo
git clone https://github.com/joe-butler-23/arch-installer.git
cd arch-installer

```

The configuration includes:

*   Hostname and username
*   Locale, keyboard, timezone
*   Kernel choice (linux-zen)
*   All features enabled (encryption, Secure Boot, etc.)
*   Dotfiles repository

---

## 🚀 Step 4: Run the Installation

```
# Run the installer
sudo bash install.sh
```
Can be pre-configured:

```
# Run the installer with config 
sudo bash install.sh --config config/desktop.yaml
```

The configuration includes:

*   Hostname and username
*   Locale, keyboard, timezone
*   Kernel choice (linux-zen)
*   All features enabled (encryption, Secure Boot, etc.)
*   Dotfiles repository

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
8.  **Chroot configuration** - Sets up bootloader, system, users, SSH, and packages

---

## 🔧 Step 5: Continuation Script

After bases is installed, you can choose whether or not to continue with remaining modules: 

```
# Continue script
sudo bash continue-install.sh

```

And you can choose a specific module to start from:

```

# Start from a specific module (e.g., module 07)
sudo bash continue-install.sh --start 07

```

## 📝 Step 6: Review Installation Results

Post-installation, there are logs that can be reviewed:

```
# View the installation log
less logs/arch-installer-*.log

# Check for any errors or warnings
grep -i "error\|warn" logs/arch-installer-*.log
```

---

## 🔄 Step 7: Reboot

```
# Unmount everything
umount -R /mnt

# Reboot
reboot
```

---

## 🎯 Post-Installation Setup

### Verify Secure Boot Status

Secure Boot keys were automatically created and enrolled during installation:

```
# Check if Secure Boot is enabled
sudo sbctl status

# Verify all boot files are signed
sudo sbctl verify
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


## 📦 Package Management

### packages.txt

The installer uses `packages.txt` to define additional packages installable by pacman. This can be amended:

```
# packages.txt format:
# - One package per line
# - Comments start with #
# - Alphabetically sorted
```

Current packages include:

*   All GUI packages (Hyprland, Waybar, Wofi, etc.)
*   Security tools (AppArmor, Fail2ban)
*   System utilities (Snapper, ZRAM, Tailscale, Syncthing)
*   Development tools (base-devel, git)

---
