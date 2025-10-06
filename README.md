# 🧱 Arch Installer

A modular, reproducible Arch Linux installation system.

---

## Overview

This project automates a complete Arch install with modern, secure defaults:

- **LUKS2** full-disk encryption  
- **Btrfs** with subvolumes & compression  
- **systemd-boot + UKI** (Unified Kernel Images)  
- **Automatic snapshots** via Snapper  
- **AppArmor**, **UFW**, and **Fail2ban**  
- **Post-install dotfile stow**  
- **Logging**, **dry-run**, and **YAML preseed support**  

---

## 🧩 Project Structure

```
arch-installer/
├── install.sh                  # Main entry point (logging, dry-run, hybrid YAML loader)
├── config/
│   ├── install.yaml            # Main configuration file (comprehensive)
│   ├── example.yaml            # Minimal example configuration
│   ├── laptop.yaml             # Laptop-optimized configuration
│   ├── desktop.yaml            # Desktop-optimized configuration
│   └── vm.yaml                 # VM-optimized configuration
├── bootstrap.sh                # Minimal setup script run from live ISO via SSH
├── logs/
│   └── arch-installer.log      # Generated installation log
├── modules/
│   ├── 00-preflight.sh         # Logging, environment checks, argument parsing
│   ├── 01-config.sh            # YAML loading & interactive input
│   ├── 02-partition.sh         # Disk, LUKS, Btrfs subvolumes
│   ├── 03-base-install.sh      # pacstrap, locale, fstab
│   ├── 04-chroot-setup.sh      # mkinitcpio, UKI, systemd-boot
│   ├── 05-users.sh             # User + root creation
│   ├── 06-network.sh           # networkd, iwd, ufw, tailscale
│   ├── 07-services.sh          # Enable system services, timers, zram, etc.
│   ├── 08-postinstall.sh       # stowall, README, verification scripts
│   └── utils.sh                # Shared helper functions
├── packages.txt                # Additional packages (one per line, alphabetical)
├── verify.sh                   # System verification script
└── README.md                   # This file
```

---

## 💻 Installation Workflow

### 1️⃣ Boot from the Arch ISO

On the target machine:
```bash
iwctl
```

Then inside iwctl:
```bash
device list
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "<YourWifiName>"
exit
```

Confirm connectivity:
```bash
ping -c3 archlinux.org
```

### 2️⃣ Enable SSH
```bash
systemctl start sshd
passwd
ip a
```

Take note of your IP (e.g. 192.168.0.190).

### 3️⃣ SSH from your laptop
```bash
ssh root@192.168.0.190
```

### 4️⃣ Bootstrap
```bash
curl -sL https://raw.githubusercontent.com/joe-butler-23/arch-installer/main/bootstrap.sh -o bootstrap.sh
bash bootstrap.sh
```

This script:
- Sets up SSH for GitHub access
- Clones arch-installer and .dotfiles

### 5️⃣ Run the installer
```bash
bash ~/arch-installer/install.sh
```

For a dry-run preview:
```bash
bash ~/arch-installer/install.sh --dry-run
```

---

## ⚙️ Configuration via YAML

The installer uses comprehensive YAML configuration files in the `config/` directory with support for different machine types:

### Available Configurations
- **`config/install.yaml`** - Complete configuration with all options
- **`config/example.yaml`** - Minimal example for quick setup
- **`config/laptop.yaml`** - Optimized for laptops (power management)
- **`config/desktop.yaml`** - Optimized for desktops (performance)
- **`config/vm.yaml`** - Optimized for virtual machines

### Usage

#### Option 1: Use a predefined configuration
```bash
# For desktop installation
bash ~/arch-installer/install.sh --config config/desktop.yaml

# For laptop installation
bash ~/arch-installer/install.sh --config config/laptop.yaml

# For VM installation
bash ~/arch-installer/install.sh --config config/vm.yaml
```

#### Option 2: Create custom configuration
1. Copy `config/example.yaml` to `config/install.yaml`
2. Customize the configuration as needed
3. Run with default config:

```bash
bash ~/arch-installer/install.sh --preseed
```

### Configuration Features
- **YAML parsing** with automatic type conversion
- **Interactive fallback** for missing values
- **Configuration validation** with error checking
- **Multiple machine profiles** for different use cases
- **Security-first** - passwords never stored in files

### Security Note
**Passwords are intentionally excluded** from YAML files for security. The installer will prompt for:
- Encryption password (if LUKS enabled)
- Root password
- User password

### Key Configuration Options
```yaml
# Basic system
disk: /dev/nvme0n1
hostname: my-arch
username: myuser
kernel: linux-zen

# Security
encryption: true
secure_boot: true

# Performance
enable_zram: true
cpu_governor: performance

# Services
enable_tailscale: true
enable_syncthing: true
```

### Machine-Specific Optimizations

#### Laptop (`config/laptop.yaml`)
- Power-saving CPU governor
- TLP power management
- Battery optimization
- Laptop-specific packages

#### Desktop (`config/desktop.yaml`)
- Performance CPU governor
- Gaming support
- Development tools
- Virtualization support

#### VM (`config/vm.yaml`)
- Minimal security overhead
- Guest agent tools
- Optimized for virtual environments
- Development-focused packages

Any missing values will be prompted interactively, ensuring a flexible installation process.

---

## 🧠 Features

| Feature | Description |
|---------|-------------|
| Logging | All output piped through tee to `/var/log/arch-installer.log` |
| Dry-run | Prints commands without executing them |
| Hybrid Config | YAML preseed + interactive fallback |
| Modular design | 8 logical stages for clarity & maintainability |
| SSH install ready | Designed for headless deployment |
| Post-install automation | Runs stowall for dotfiles, system verification, etc. |

---

## 🔧 Developer Notes

You can rerun a single module for debugging, e.g.:

```bash
source modules/03-base-install.sh
run_base_install
```

Future extensions can include:
- `config/laptop.yaml` and `config/desktop.yaml`
- A recovery/uninstall module
- Remote logging to a web dashboard
