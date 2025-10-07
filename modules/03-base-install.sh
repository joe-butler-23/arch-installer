#!/usr/bin/env bash

run_base_install() {
  info "=== Base System Installation ==="

  microcode="intel-ucode"
  grep -q AuthenticAMD /proc/cpuinfo && microcode="amd-ucode"

  PKGS="base ${kernel:-linux} $microcode linux-firmware btrfs-progs efibootmgr snapper zsh sudo opendoas openssh iwd git tailscale syncthing stow"
  info "Installing base packages: $PKGS"
  run_cmd "pacstrap -K /mnt $PKGS"

  info "Generating fstab"
  run_cmd "genfstab -U /mnt >> /mnt/etc/fstab"

  info "Setting hostname and locale"
  echo "${hostname:-archlinux}" > /mnt/etc/hostname
  echo "LANG=${locale:-en_GB.UTF-8}" > /mnt/etc/locale.conf
  echo "KEYMAP=${keyboard_layout:-uk}" > /mnt/etc/vconsole.conf
  run_cmd "sed -i 's/^#${locale}/${locale}/' /mnt/etc/locale.gen || echo '${locale:-en_GB.UTF-8} UTF-8' >> /mnt/etc/locale.gen"
  run_cmd "arch-chroot /mnt locale-gen"

  info "Linking timezone"
  run_cmd "arch-chroot /mnt ln -sf /usr/share/zoneinfo/${timezone:-Europe/London} /etc/localtime"
  run_cmd "arch-chroot /mnt hwclock --systohc"

  info "Base installation completed successfully."
}
