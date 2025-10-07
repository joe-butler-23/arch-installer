#!/usr/bin/env bash

run_chroot_setup() {
  info "=== Chroot Configuration ==="

  # Get LUKS UUID
  local cryptroot_partition="${disk}p2"
  luks_uuid=$(blkid -s UUID -o value "$cryptroot_partition")
  
  if [[ -z "$luks_uuid" ]]; then
    die "Failed to get LUKS UUID from $cryptroot_partition"
  fi

  # mkinitcpio hooks for systemd-init + sd-encrypt
  info "Configuring mkinitcpio for UKI"
  cat > /mnt/etc/mkinitcpio.conf <<'EOF'
HOOKS=(systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems fsck)
EOF

  # Create kernel cmdline for unified image
  mkdir -p /mnt/etc/kernel
  cat > /mnt/etc/kernel/cmdline <<EOF
rd.luks.name=${luks_uuid}=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet loglevel=3 apparmor=1 lsm=landlock,lockdown,yama,apparmor,bpf
EOF

  # Configure UKI presets
  cat > /mnt/etc/mkinitcpio.d/${kernel}.preset <<EOF
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-${kernel}"
ALL_microcode=(/boot/*-ucode.img)

PRESETS=('default' 'fallback')

default_uki="/boot/EFI/Linux/arch-${kernel}.efi"
fallback_uki="/boot/EFI/Linux/arch-${kernel}-fallback.efi"
fallback_options="-S autodetect"
EOF

  # Create boot directory structure for UKI
  mkdir -p /mnt/boot/EFI/Linux

  info "Installing systemd-boot"
  run_cmd "arch-chroot /mnt bootctl install"

  cat > /mnt/boot/loader/loader.conf <<EOF
default arch-${kernel}.efi
timeout 3
console-mode max
editor no
EOF

  info "Building unified kernel images"
  run_cmd "arch-chroot /mnt mkinitcpio -P"

  # Configure Snapper for root and home subvolumes
  info "Configuring Snapper for @root and @home subvolumes"
  
  # Create Snapper configs
  cat > /mnt/etc/snapper/configs/root <<'EOF'
# Subvolume to snapshot
SUBVOLUME="/"

# Filesystem type
FSTYPE="btrfs"

# Users and groups allowed to work with snapshots
ALLOW_USERS=""
ALLOW_GROUPS=""

# Sync users and groups from OS to snapper
SYNC_ACL="no"

# Start timeline cleanup
TIMELINE_CREATE="yes"

# Timeline cleanup limits
TIMELINE_LIMIT_HOURLY="10"
TIMELINE_LIMIT_DAILY="10"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="10"
TIMELINE_LIMIT_YEARLY="0"

# Background cleanup limits
BACKGROUND_LIMIT_HOURLY="0"
BACKGROUND_LIMIT_DAILY="0"
BACKGROUND_LIMIT_WEEKLY="0"
BACKGROUND_LIMIT_MONTHLY="0"
BACKGROUND_LIMIT_YEARLY="0"

# Free space limits
FREE_LIMIT="5"

# Number cleanup limits
NUMBER_LIMIT="10"
NUMBER_MIN_AGE="1800"

# Empty pre/post snapshot cleanup limits
EMPTY_PRE_POST_MIN_AGE="1800"
EMPTY_PRE_POST_LIMIT="3"

# Timeline cleanup algorithm
TIMELINE_CLEANUP_ALGORITHM="number"

EOF

  cat > /mnt/etc/snapper/configs/home <<'EOF'
# Subvolume to snapshot
SUBVOLUME="/home"

# Filesystem type
FSTYPE="btrfs"

# Users and groups allowed to work with snapshots
ALLOW_USERS=""
ALLOW_GROUPS=""

# Sync users and groups from OS to snapper
SYNC_ACL="no"

# Start timeline cleanup
TIMELINE_CREATE="yes"

# Timeline cleanup limits
TIMELINE_LIMIT_HOURLY="10"
TIMELINE_LIMIT_DAILY="10"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="10"
TIMELINE_LIMIT_YEARLY="0"

# Background cleanup limits
BACKGROUND_LIMIT_HOURLY="0"
BACKGROUND_LIMIT_DAILY="0"
BACKGROUND_LIMIT_WEEKLY="0"
BACKGROUND_LIMIT_MONTHLY="0"
BACKGROUND_LIMIT_YEARLY="0"

# Free space limits
FREE_LIMIT="5"

# Number cleanup limits
NUMBER_LIMIT="10"
NUMBER_MIN_AGE="1800"

# Empty pre/post snapshot cleanup limits
EMPTY_PRE_POST_MIN_AGE="1800"
EMPTY_PRE_POST_LIMIT="3"

# Timeline cleanup algorithm
TIMELINE_CLEANUP_ALGORITHM="number"

EOF

  # Create .snapshots directories
  run_cmd "mkdir -p /mnt/.snapshots"
  run_cmd "mkdir -p /mnt/home/.snapshots"

  # Create initial snapshots
  run_cmd "arch-chroot /mnt snapper -c root create-config /"
  run_cmd "arch-chroot /mnt snapper -c home create-config /home"
  run_cmd "arch-chroot /mnt snapper -c root create --description 'First snapshot'"
  run_cmd "arch-chroot /mnt snapper -c home create --description 'First snapshot'"

  info "✅ Snapper configured for @root and @home subvolumes"
  info "✅ UKI and systemd-boot configured"
}
