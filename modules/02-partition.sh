#!/usr/bin/env bash

run_partition() {
  info "=== Disk Partitioning & Encryption ==="
  [[ -b "$disk" ]] || die "Disk $disk not found."

  # Wipe & create GPT
  run_cmd "wipefs -af $disk"
  run_cmd "sgdisk -Zo $disk"
  run_cmd "parted -s $disk mklabel gpt \
    mkpart ESP fat32 1MiB 1GiB set 1 esp on \
    mkpart CRYPTROOT 1GiB 100%"

  sleep 2
  ESP="${disk}p1"
  CRYPTROOT="${disk}p2"

  run_cmd "mkfs.fat -F32 -n EFI $ESP"

  info "Creating LUKS container on $CRYPTROOT"
  echo -n "$encryption_password" | run_cmd "cryptsetup luksFormat $CRYPTROOT --type luks2 --cipher aes-xts-plain64 --key-size 512 --pbkdf argon2id -q"
  echo -n "$encryption_password" | run_cmd "cryptsetup open $CRYPTROOT cryptroot -d -"
  BTRFS_DEV="/dev/mapper/cryptroot"

  info "Formatting Btrfs filesystem"
  run_cmd "mkfs.btrfs -L archroot -f $BTRFS_DEV"

  run_cmd "mount $BTRFS_DEV /mnt"
  info "Creating subvolumes"
  for s in @ @home @root @srv @snapshots @var_log @var_pkgs; do
    run_cmd "btrfs subvolume create /mnt/$s"
  done
  run_cmd "umount /mnt"

  MNTOPTS="ssd,noatime,compress-force=zstd:3,discard=async,space_cache=v2,commit=120"
  run_cmd "mount -o $MNTOPTS,subvol=@ $BTRFS_DEV /mnt"
  mkdir -p /mnt/{home,root,srv,.snapshots,var/{log,cache/pacman/pkg},boot}
  run_cmd "mount -o $MNTOPTS,subvol=@home $BTRFS_DEV /mnt/home"
  run_cmd "mount -o $MNTOPTS,subvol=@root $BTRFS_DEV /mnt/root"
  run_cmd "mount -o $MNTOPTS,subvol=@srv $BTRFS_DEV /mnt/srv"
  run_cmd "mount -o $MNTOPTS,subvol=@snapshots $BTRFS_DEV /mnt/.snapshots"
  run_cmd "mount -o $MNTOPTS,subvol=@var_log $BTRFS_DEV /mnt/var/log"
  run_cmd "mount -o $MNTOPTS,subvol=@var_pkgs $BTRFS_DEV /mnt/var/cache/pacman/pkg"
  run_cmd "mount $ESP /mnt/boot"

  info "Partitioning complete"
}
