# Arch Installer Project Context

## Project Overview
Clean, replicable Arch Linux installation script with LUKS, Btrfs, Hyprland, Secure Boot.
- **Location**: `~/Documents/computer/`
- **GitHub**: https://github.com/joe-butler-23/arch-installer
- **Installation Method**: SSH-driven
- **Profiles**: Desktop, Laptop, VM configurations

## Git Workflow (CRITICAL)

**Session Start**:
```bash
cd ~/Documents/computer/
git pull
```
Always pull latest changes before starting work to avoid conflicts.

**Session End**:
```bash
git add .
git commit -m "Descriptive commit message"
git push
```
Always push changes before ending session to ensure work is saved and synchronized.

## File Structure & Key Scripts

### Main Scripts
- `install.sh` - Main installation entry point
- `continue-install.sh` - Resume installation from specific module
- `verify.sh` - Post-installation verification script
- `bootstrap.sh` - Initial setup

### Modules (`modules/`)
- `00-preflight.sh` - Environment and tool verification
- `01-config.sh` - Configuration loading
- `02-partition.sh` - Disk partitioning
- `03-base-install.sh` - Base system installation
- `04-chroot-setup.sh` - Bootloader, system, users, SSH setup
- `06-network.sh` - Network configuration
- `07-services.sh` - Service setup
- `08-postinstall.sh` - Post-installation tasks
- `utils.sh` - Shared utility functions

### Configuration (`config/`)
- `desktop.yaml` - Desktop profile
- `laptop.yaml` - Laptop profile
- `vm.yaml` - VM profile
- `example.yaml` - Template configuration
- `install.yaml` - Active configuration

### Other Files
- `packages.txt` - Package definitions (one per line, alphabetically sorted)
- `out/` - Output directory (ISO files, etc.)

## Technologies & Concepts

### Core Technologies
- **LUKS**: Full-disk encryption
- **Btrfs**: Filesystem with subvolumes and snapshots
- **Hyprland**: Wayland compositor for desktop environment
- **UWSM**: Universal Wayland Session Manager for systemd integration
- **app2unit**: Fast shell-based launcher for desktop entries as systemd units (~0.06s overhead)
- **Secure Boot**: UEFI Secure Boot with sbctl
- **AppArmor**: Mandatory access control
- **Fail2ban**: Intrusion prevention

### System Components
- **Snapper**: Btrfs snapshot management
- **ZRAM**: Compressed swap in RAM
- **Tailscale**: VPN mesh network
- **Syncthing**: File synchronization
- **linux-zen**: Performance-optimized kernel

## Known Issues (P0 - Critical/Blocking)

### SSH Config Rendering
**Problem**: `${username}` rendered literally in SSH config due to single-quoted heredocs in module 04-chroot-setup.sh
**Location**: `modules/04-chroot-setup.sh` (run_chroot_setup and run_users functions)
**Solution**: Use unquoted heredocs or explicit variable substitution
**Verification**: Test SSH connection after fix

### Verification Script Directory Checks
**Problem**: `verify.sh` uses `-f` flag for directories, causing false negatives for Snapper directories
**Location**: `verify.sh`
**Solution**: Add directory checks with `-d` flag for appropriate paths
**Verification**: Run `./verify.sh` and check for false positives

### Service Expectations Mismatch
**Problem**: Verifier expects `snapper-timeline.timer` and `ufw.service` enabled, but installer doesn't install/enable them
**Location**: Installer modules vs `verify.sh`
**Solution**: Align installer to install/enable expected services OR update verifier expectations
**Verification**: Run `systemctl status snapper-timeline.timer ufw.service`

### GRUB LUKS UUID Reference
**Problem**: GRUB cmdline must reference current LUKS UUID dynamically
**Location**: GRUB configuration module
**Solution**: Replace one-shot sed with robust write each run:
```bash
luks_uuid=$(blkid -s UUID -o value "$CRYPTROOT")
cat > /mnt/etc/default/grub <<EOF
GRUB_DEFAULT=0
GRUB_TIMEOUT=3
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX="rd.luks.name=${luks_uuid}=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet loglevel=3 apparmor=1 lsm=landlock,lockdown,yama,apparmor,bpf"
EOF
```

### Boot Order - Initramfs Before GRUB Config
**Problem**: Always rebuild initramfs after writing /etc/default/grub
**Location**: Boot configuration module
**Solution**: Order: mkinitcpio -P → grub-mkconfig
**Verification**: Boot system successfully

### EFI Boot Entry Creation
**Problem**: Add check that EFI boot entry exists
**Location**: Boot configuration module
**Solution**: Fail loudly if missing:
```bash
efibootmgr | grep -q "GRUB" || { echo "ERROR: No EFI boot entry created"; exit 1; }
```

### Fail2ban for Arch
**Problem**: Current config uses Debian-style /var/log/auth.log, switch to systemd backend
**Location**: Fail2ban configuration
**Solution**: Replace with:
```bash
[sshd]
enabled = true
backend = systemd
maxretry = 3
bantime = 3600
```

## Research Questions (P1 - High Priority)

1. **Is UKI in use?** - Unified Kernel Image status unclear
2. **Post-install script shape?** - Current structure and improvements needed
3. **Btrfs zstd compression enabled?** - Compression status verification
4. **What is snappac?** - Definition and whether to include it

## Common Task Types

### Bug Fixes
- Shell script syntax and logic errors
- Variable substitution issues
- Service configuration mismatches
- Verification script accuracy

### Configuration Updates
- YAML profile modifications
- Package list updates (`packages.txt`)
- Module parameter adjustments
- Service enablement/configuration

### Documentation
- README updates
- Comment improvements
- Installation guide refinements
- Verification checklist updates

### Research Tasks
- Technology assessment (UKI, snappac, etc.)
- Best practices review
- Compression and optimization status
- Service and tool evaluation

## Tools & Commands

### Installation
```bash
# Run full installation
sudo bash install.sh

# Run with specific config
sudo bash install.sh --config config/desktop.yaml

# Continue from specific module
sudo bash continue-install.sh --start 07
```

### Verification
```bash
# Run full verification
./verify.sh

# Check Secure Boot status
sudo sbctl status
sudo sbctl verify

# Check service status
systemctl status <service-name>
systemctl --user status <service-name>
```

### Package Management
```bash
# Update package list (packages.txt)
# Format: one package per line, alphabetically sorted, comments with #

# Install additional packages
pacman -S <package-name>
```

### Git Workflow
```bash
# Session start
cd ~/Documents/computer/
git pull

# Session end
git add .
git commit -m "Description of changes"
git push
```

## Success Patterns

### SSH Config Fixes
1. Identify heredoc location in `modules/04-chroot-setup.sh`
2. Change single-quoted to unquoted heredoc OR use explicit substitution
3. Test changes in installation environment
4. Verify SSH connection works after installation
5. Commit with descriptive message

### Service Alignment
1. Identify mismatch between installer and verifier
2. Decide: add to installer OR remove from verifier
3. Update appropriate file(s)
4. Test installation process
5. Run `./verify.sh` to confirm alignment
6. Commit changes

### Verification Script Fixes
1. Locate issue in `verify.sh`
2. Determine correct test flag (-f, -d, -e, etc.)
3. Update verification logic
4. Test against known-good installation
5. Verify no false positives/negatives
6. Commit fix

### Boot Configuration
1. Ensure GRUB references correct LUKS UUID
2. Rebuild initramfs before GRUB config
3. Verify EFI boot entry creation
4. Test boot process end-to-end
5. Add safety checks before completion

## File Paths Reference

- **Project root**: `~/Documents/computer/`
- **GitHub repo**: `https://github.com/joe-butler-23/arch-installer`
- **Main scripts**: `~/Documents/computer/{install.sh,continue-install.sh,verify.sh}`
- **Modules**: `~/Documents/computer/modules/*.sh`
- **Configs**: `~/Documents/computer/config/*.yaml`
- **Packages**: `~/Documents/computer/packages.txt`
- **Task file**: `~/Documents/computer/arch-installer-tasks.md`
