#!/usr/bin/env bash

run_base_install() {
  info "=== Base System Installation ==="

  microcode="intel-ucode"
  grep -q AuthenticAMD /proc/cpuinfo && microcode="amd-ucode"

  PKGS="base $KERNEL $microcode linux-firmware btrfs-progs systemd-boot-pacman-hook efibootmgr"
  info "Installing base packages: $PKGS"
  run_cmd "pacstrap -K /mnt $PKGS"

  info "Generating fstab"
  run_cmd "genfstab -U /mnt >> /mnt/etc/fstab"

  info "Setting hostname and locale"
  echo "$HOSTNAME" > /mnt/etc/hostname
  echo "LANG=$LOCALE" > /mnt/etc/locale.conf
  echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
  run_cmd "sed -i 's/^#${LOCALE}/${LOCALE}/' /mnt/etc/locale.gen || echo '${LOCALE} UTF-8' >> /mnt/etc/locale.gen"
  run_cmd "arch-chroot /mnt locale-gen"

  info "Linking timezone"
  run_cmd "arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime"
  run_cmd "arch-chroot /mnt hwclock --systohc"

  info "Base installation completed successfully."
}
