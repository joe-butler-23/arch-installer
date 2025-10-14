# Arch Installer Tasks

- **Path**: ~/Documents/computer/
- **GitHub**: https://github.com/joe-butler-23/arch-installer
- **Description**: Clean, replicable Arch Linux installation script with LUKS, Btrfs, Hyprland, Secure Boot
- **Status**: Active - has known issues and improvements needed
- **Features**: LUKS full-disk, Btrfs subvols, Hyprland, Secure Boot, AppArmor, Fail2ban; SSH-driven; profiles (desktop/laptop/VM)

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

## P0 - Critical/Blocking (6 tasks)

### ID 1: Fix SSH Config Rendering
- **Description**: Fix SSH config rendering `${username}` literally due to single-quoted heredocs in run_chroot_setup/run_users
- **Location**: `modules/04-chroot-setup.sh` (run_chroot_setup and run_users functions)
- **Solution**: Fix with unquoted heredoc or explicit substitution
- **Dependencies**: None
- **Tags**: P0, bug, ssh-config
- **Verification**: Test SSH connection after fix

### ID 2: Fix Verification Script Directory Checks
- **Description**: Fix verification script treating directories as files (-f); Snapper dirs flagged missing
- **Location**: `verify.sh`
- **Solution**: Add directory checks (-d) for those paths
- **Dependencies**: None
- **Tags**: P0, bug, verification
- **Verification**: Run `./verify.sh` and confirm no false positives

### ID 3: Fix Service Expectations Mismatch
- **Description**: Verifier expects snapper-timeline.timer and ufw.service enabled; installer doesn't install/enable them
- **Location**: Installer modules vs `verify.sh`
- **Solution**: Align installer and verifier (either add to installer OR remove from verifier)
- **Dependencies**: None
- **Tags**: P0, bug, services
- **Verification**: Run `systemctl status snapper-timeline.timer ufw.service`

### ID 29: Fix GRUB LUKS UUID Reference
- **Description**: GRUB cmdline must reference current LUKS UUID dynamically
- **Location**: GRUB configuration module
- **Solution**: Replace one-shot sed with robust write each run:
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
- **Dependencies**: None
- **Tags**: P0, boot, grub
- **Verification**: Check GRUB config has correct UUID

### ID 30: Fix Boot Order - Initramfs Before GRUB Config
- **Description**: Always rebuild initramfs after writing /etc/default/grub
- **Location**: Boot configuration module
- **Solution**: Order: mkinitcpio -P → grub-mkconfig
- **Dependencies**: ID 29
- **Tags**: P0, boot, initramfs
- **Verification**: Boot system successfully

### ID 31: Verify EFI Boot Entry Creation
- **Description**: Add check that EFI boot entry exists
- **Location**: Boot configuration module
- **Solution**: Fail loudly if missing:
```bash
efibootmgr | grep -q "GRUB" || { echo "ERROR: No EFI boot entry created"; exit 1; }
```
- **Dependencies**: ID 30
- **Tags**: P0, boot, efi
- **Verification**: EFI boot entry exists

### ID 35: Fix Fail2ban for Arch
- **Description**: Current config uses Debian-style /var/log/auth.log, switch to systemd backend
- **Location**: Fail2ban configuration
- **Solution**: Replace with:
```bash
[sshd]
enabled = true
backend = systemd
maxretry = 3
bantime = 3600
```
- **Dependencies**: None
- **Tags**: P0, security, fail2ban
- **Verification**: Fail2ban works with systemd journal

### ID 38: Add Safety Checks Before Completion
- **Description**: Verify grub.cfg exists and EFI boot entry before completion
- **Location**: End of installation script
- **Solution**: Add verification block:
```bash
set -e
arch-chroot /mnt grub-probe /boot >/dev/null
[ -f /mnt/boot/grub/grub.cfg ] || { echo "ERROR: Missing grub.cfg"; exit 1; }
efibootmgr | grep -q GRUB || { echo "ERROR: No EFI boot entry"; exit 1; }
```
- **Dependencies**: ID 31
- **Tags**: P0, safety, verification
- **Verification**: Installation completes with all checks passing

## P1 - High Priority (12 tasks)

### ID 4: Handle AppArmor Gracefully
- **Description**: Handle AppArmor gracefully when aa-status absent
- **Location**: Module checking AppArmor status
- **Solution**: Check if `aa-status` exists before running
- **Dependencies**: None
- **Tags**: P1, improvement, apparmor
- **Verification**: Test on system without AppArmor

### ID 5: Address Unused Config Options
- **Description**: Address unused config options (e.g., dotfiles.repository, cpu_governor)
- **Location**: Config files and modules
- **Solution**: Either implement or remove unused options
- **Dependencies**: None
- **Tags**: P1, cleanup, config
- **Verification**: Check config options are all utilized

### ID 6: Make Pacman Snippet Insertion Idempotent
- **Description**: Make pacman snippet insertion idempotent
- **Location**: Module handling pacman configuration
- **Solution**: Check if snippet exists before inserting
- **Dependencies**: None
- **Tags**: P1, improvement, pacman
- **Verification**: Run installer twice, verify no duplicates

### ID 7: Prefer install -D Over cat >>
- **Description**: Prefer `install -D` drop-ins over `cat >>`
- **Location**: Multiple modules creating config files
- **Solution**: Replace `cat >>` with `install -D`
- **Dependencies**: None
- **Tags**: P1, improvement, best-practices
- **Verification**: Code review, test installations

### ID 8: Research Tasks (Combined)
- **Description**: Combined research task covering: UKI usage, post-install script shape, Btrfs zstd compression, snappac, Arch boot-time tips, CachyOS kernels
- **Location**: Various modules and documentation
- **Solution**: Comprehensive research and documentation of all outstanding questions
- **Dependencies**: None
- **Tags**: P3, research, documentation
- **Verification**: All research questions documented with findings and recommendations

### ID 32: Add /etc/crypttab
- **Description**: Optional but nice for LUKS management
- **Location**: LUKS configuration module
- **Solution**: Add crypttab entry:
```bash
echo "cryptroot UUID=${luks_uuid} none luks,discard"
```
- **Dependencies**: ID 29
- **Tags**: P1, improvement, luks
- **Verification**: crypttab exists and is correct

### ID 34: Fix Partitioning Race Conditions
- **Description**: Add udevadm settle + partprobe + sleep after parted
- **Location**: Partitioning module
- **Solution**: Add after parted:
```bash
udevadm settle
partprobe "$DISK"
sleep 2
```
- **Dependencies**: None
- **Tags**: P1, improvement, partitioning
- **Verification**: Partitioning works reliably

### ID 36: Add Robust sbctl Signing
- **Description**: Guard signing commands with file existence checks
- **Location**: Secure Boot module
- **Solution**: Add guards:
```bash
sbctl create-keys
sbctl enroll-keys -m
[ -f /boot/EFI/GRUB/grubx64.efi ] && sbctl sign -s /boot/EFI/GRUB/grubx64.efi || true
[ -f /boot/vmlinuz-${kernel} ] && sbctl sign -s /boot/vmlinuz-${kernel} || true
```
- **Dependencies**: None
- **Tags**: P1, improvement, secure-boot
- **Verification**: Signing works without errors

### ID 37: Add locale.gen Guard
- **Description**: Prevent failures if locale line doesn't exist
- **Location**: Locale configuration module
- **Solution**: Add guard:
```bash
grep -q "^${locale} " /etc/locale.gen || echo "${locale} UTF-8" >> /etc/locale.gen
sed -i "s/^#\(${locale} .*\)/\1/" /etc/locale.gen
```
- **Dependencies**: None
- **Tags**: P1, improvement, locale
- **Verification**: Locale setup works reliably

## P2 - Medium Priority (12 tasks)

### ID 12: Improve Secure Boot Flow
- **Description**: Move "setup mode" to pre-install; remove from post-install - need to put machine into setup mode BEFORE starting installation
- **Location**: Documentation and Secure Boot module
- **Solution**: Restructure Secure Boot setup process - put machine in setup mode before installation starts
- **Dependencies**: None
- **Tags**: P2, improvement, secure-boot
- **Verification**: Test new flow, update docs

### ID 13: Capture Bluetooth Configs
- **Description**: Config preservation: capture Bluetooth configs
- **Location**: Config preservation module
- **Solution**: Add Bluetooth config to preservation list
- **Dependencies**: None
- **Tags**: P2, improvement, config-preservation
- **Verification**: Test config restoration

### ID 14: Compare Docs with arch-maintain.sh
- **Description**: Compare documentation with arch-maintain.sh
- **Location**: README.md and arch-maintain.sh
- **Solution**: Align documentation and maintenance script
- **Dependencies**: None
- **Tags**: P2, documentation, maintenance
- **Verification**: Documentation accuracy

### ID 15: Include AUR Bootstrap
- **Description**: Post-install: include AUR bootstrap
- **Location**: Post-installation module
- **Solution**: Add AUR helper setup (yay/paru)
- **Dependencies**: None
- **Tags**: P2, improvement, post-install
- **Verification**: Test AUR access after install

### ID 16: Install 1Password (AUR)
- **Description**: Post-install: install 1Password from AUR
- **Location**: Post-installation or packages
- **Solution**: Add 1Password installation
- **Dependencies**: ID 15 (AUR bootstrap)
- **Tags**: P2, improvement, post-install
- **Verification**: 1Password installed and functional

### ID 17: Document Manual Steps
- **Description**: Document manual steps for packages/dotfiles
- **Location**: Documentation
- **Solution**: Create comprehensive manual steps guide
- **Dependencies**: None
- **Tags**: P2, documentation
- **Verification**: Documentation completeness

### ID 18: Replicate /etc/hosts for DNS
- **Description**: Replicate /etc/hosts for DNS config
- **Location**: Network configuration module
- **Solution**: Add /etc/hosts management
- **Dependencies**: None
- **Tags**: P2, improvement, network
- **Verification**: Test DNS resolution

### ID 19: Back Up and Sync Systemd Services
- **Description**: Back up and sync my systemd services
- **Location**: Config preservation or post-install
- **Solution**: Add systemd service backup/restore
- **Dependencies**: None
- **Tags**: P2, improvement, config-preservation
- **Verification**: Test service restoration

### ID 20: Get uwsm Working on Laptop (BLOCKER)
- **Description**: Get uwsm working on laptop and sync uwsm config to installation scripts - BLOCKER for other work
- **Location**: Desktop environment module
- **Solution**: Configure uwsm on laptop first, then sync config to installer for desktop installation
- **Dependencies**: None
- **Tags**: P0, blocker, desktop
- **Verification**: uwsm functional on laptop, config ready for desktop sync

### ID 33: Add UKI Path Toggle
- **Description**: Offer UKI as optional feature flag
- **Location**: Boot configuration
- **Solution**: Add UKI toggle option, keep GRUB as default
- **Dependencies**: ID 8 (UKI research)
- **Tags**: P2, feature, boot
- **Verification**: UKI option works when enabled

### ID 39: Deal with Hyprland.conf Auto-Update
- **Description**: Hyprland.conf automatically updates itself, need to handle this
- **Location**: Hyprland configuration module
- **Solution**: Check AI logs for required amendments, test on desktop
- **Dependencies**: None
- **Tags**: P2, improvement, hyprland
- **Verification**: Hyprland config stable

### ID 40: Add app2unit for Fast UWSM Application Launching
- **Description**: Install and configure app2unit for ~0.06s overhead instead of Python startup
- **Location**: Post-installation or package management
- **Solution**: Clone from GitHub, install to /usr/local/bin/, configure UWSM env vars
- **Dependencies**: ID 20 (UWSM setup)
- **Tags**: P2, improvement, uwsm, performance
- **Verification**: Test app launch speed, verify systemd units created

## P3 - Low Priority (9 tasks)

### ID 21: Add Shell Checker in CI
- **Description**: Shell checker in CI
- **Location**: CI/CD configuration
- **Solution**: Add ShellCheck to CI pipeline
- **Dependencies**: None
- **Tags**: P3, ci, quality
- **Verification**: CI pipeline runs ShellCheck

### ID 22: Document zshenv Usage
- **Description**: Document zshenv usage
- **Location**: Documentation
- **Solution**: Add zshenv documentation
- **Dependencies**: None
- **Tags**: P3, documentation
- **Verification**: Documentation complete

### ID 23: Switch to zsnap for Zsh Perf
- **Description**: Switch to zsnap for zsh performance
- **Location**: Shell configuration
- **Solution**: Implement zsnap
- **Dependencies**: None
- **Tags**: P3, performance, shell
- **Verification**: Zsh startup time improved

### ID 25: SSH Config Cleanup
- **Description**: SSH config cleanup
- **Location**: SSH configuration module
- **Solution**: Review and clean up SSH config generation
- **Dependencies**: ID 1 (Fix SSH config rendering)
- **Tags**: P3, cleanup, ssh
- **Verification**: Cleaner SSH config

### ID 26: Purge Stale Git Repos
- **Description**: Purge stale Git repos
- **Location**: Project cleanup
- **Solution**: Identify and remove unused repos
- **Dependencies**: None
- **Tags**: P3, cleanup
- **Verification**: Reduced repo clutter

### ID 28: NAS/Pi-hole and Unbound Setup
- **Description**: NAS/Pi-hole and unbound setup
- **Location**: Network services
- **Solution**: Add optional NAS and DNS server setup
- **Dependencies**: None
- **Tags**: P3, feature, network
- **Verification**: NAS/DNS functional

## Task Summary

- **Total Tasks**: 36 (consolidated research tasks)
- **P0 (Critical/Blocking)**: 7 tasks (including UWSM blocker)
- **P1 (High Priority)**: 8 tasks
- **P2 (Medium Priority)**: 13 tasks
- **P3 (Low Priority)**: 8 tasks

## Next Steps

1. Start with P0 tasks (critical/blocking)
2. Focus on one task at a time
3. Test each fix thoroughly
4. Use git workflow (pull at start, push at end)
5. Update task status as work progresses
