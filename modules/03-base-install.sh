#!/usr/bin/env bash

run_base_install() {
  info "=== Base System Installation ==="

  microcode="intel-ucode"
  grep -q AuthenticAMD /proc/cpuinfo && microcode="amd-ucode"

  # Core packages that must be installed
  CORE_PKGS="base ${kernel:-linux} $microcode linux-firmware efibootmgr sudo openssh git"
  
  PKGS="$CORE_PKGS"
  info "Installing packages..."
  run_cmd "pacstrap -K /mnt $PKGS"

  info "Generating fstab"
  run_cmd "genfstab -U /mnt >> /mnt/etc/fstab"

  info "Setting hostname and locale"
  echo "${hostname:-archlinux}" > /mnt/etc/hostname
  echo "LANG=${locale:-en_GB.UTF-8}" > /mnt/etc/locale.conf
  echo "KEYMAP=${keyboard_layout:-uk}" > /mnt/etc/vconsole.conf
  # Configure locale with proper guards
  local target_locale="${locale:-en_GB.UTF-8}"
  if ! grep -q "^${target_locale} " /mnt/etc/locale.gen; then
    run_cmd "echo '${target_locale} UTF-8' >> /mnt/etc/locale.gen"
  fi
  run_cmd "sed -i 's/^#${target_locale}/${target_locale}/' /mnt/etc/locale.gen"
  run_cmd "arch-chroot /mnt locale-gen"

  info "Linking timezone"
  run_cmd "arch-chroot /mnt ln -sf /usr/share/zoneinfo/${timezone:-Europe/London} /etc/localtime"
  run_cmd "arch-chroot /mnt hwclock --systohc"

  info "Base installation completed successfully."
}
