#!/usr/bin/env bash

run_partition() {
  info "=== Disk Partitioning & Encryption ==="
  [[ -b "$disk" ]] || die "Disk $disk not found."

  # Cleanup any existing mounts and LUKS volumes
  info "Cleaning up existing mounts and LUKS volumes"
  
  # Unmount /mnt and all submounts first
  if mountpoint -q /mnt; then
    info "Unmounting /mnt"
    umount -R /mnt 2>/dev/null || true
  fi
  
  # Unmount all partitions from the target disk
  if mount | grep -q "$disk"; then
    info "Unmounting partitions from $disk"
    mount | grep "$disk" | awk '{print $1}' | sort -r | xargs -r umount -R 2>/dev/null || true
  fi
  
  # Close all LUKS/dm-crypt containers
  if [[ -e /dev/mapper/cryptroot ]]; then
    info "Closing cryptroot LUKS container"
    cryptsetup close cryptroot 2>/dev/null || true
  fi
  
  # Remove any other device-mapper devices related to this disk
  for dm in $(dmsetup ls | grep -i crypt | awk '{print $1}'); do
    info "Removing device-mapper device: $dm"
    dmsetup remove "$dm" 2>/dev/null || true
  done
  
  # Swapoff any swap on the disk
  swapoff -a 2>/dev/null || true
  
  # Kill any processes using the disk
  fuser -km "$disk"* 2>/dev/null || true
  
  # Wait for the kernel to release resources
  sleep 3

  # Wipe disk
  info "Wiping disk"
  run_cmd "wipefs -af $disk"
  run_cmd "sgdisk -Zo $disk"
  sleep 2
  
  # Create new partition table and partitions
  info "Creating new partition table"
  run_cmd "parted -s $disk mklabel gpt \
    mkpart ESP fat32 1MiB 1GiB set 1 esp on \
    mkpart CRYPTROOT 1GiB 100%"

  # Wait for udev to settle and force kernel to reread partition table
  info "Refreshing partition table"
  run_cmd "udevadm settle"
  run_cmd "partprobe $disk"
  run_cmd "sleep 2"
  
  # Wait for partition devices to appear
  sleep 2
  for i in {1..10}; do
    if [[ -b "${disk}p1" && -b "${disk}p2" ]]; then
      break
    fi
    sleep 1
  done
  
  ESP="${disk}p1"
  CRYPTROOT="${disk}p2"

  run_cmd "mkfs.fat -F32 -n EFI $ESP"

  info "Creating LUKS container on $CRYPTROOT"
  # Note: cryptsetup commands need stdin, so we can't use run_cmd wrapper
  echo -n "$encryption_password" | cryptsetup luksFormat "$CRYPTROOT" --type luks2 --cipher aes-xts-plain64 --key-size 512 --pbkdf argon2id -q || die "Failed to format LUKS container"
  echo -n "$encryption_password" | cryptsetup open "$CRYPTROOT" cryptroot -d - || die "Failed to open LUKS container"
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
