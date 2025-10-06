#!/usr/bin/env bash
set -euo pipefail

# Load helper modules in order
for m in modules/utils.sh modules/00-*.sh modules/01-*.sh; do
  source "$m"
done
for m in modules/0[2-9]-*.sh; do
  source "$m"
done

main() {
  run_preflight "$@"
  run_config
  run_partition
  run_base_install
  echo
  info "✅ Base installation complete — ready for chroot configuration."
  info "Next: reboot or continue with module 04-chroot-setup.sh."
}

main "$@"
