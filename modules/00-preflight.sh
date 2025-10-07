#!/usr/bin/env bash

run_preflight() {
  # Create logs directory in project structure
  mkdir -p logs
  PROJECT_LOG="logs/arch-installer-$(date +%Y%m%d_%H%M%S).log"
  
  # Ensure we're running in the right environment
  if [[ ! -d /var/log && -d /mnt/var/log ]]; then
    mkdir -p /mnt/var/log
    LOGFILE="/mnt/var/log/arch-installer.log"
  elif [[ ! -d /var/log ]]; then
    mkdir -p /var/log
    LOGFILE="/var/log/arch-installer.log"
  else
    LOGFILE="/var/log/arch-installer.log"
  fi

  # Enhanced logging function with timestamps
  log_with_timestamp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$PROJECT_LOG"
    if [[ -w "$LOGFILE" ]]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOGFILE"
    fi
  }

  # Override info, warn, error functions to include logging
  info() { 
    local msg="$(date '+%Y-%m-%d %H:%M:%S') - [INFO] $*"
    echo -e "${GREEN}[ • ]${RESET} $*"
    echo "$msg" >> "$PROJECT_LOG"
    if [[ -w "$LOGFILE" ]]; then
      echo "$msg" >> "$LOGFILE"
    fi
  }
  
  warn() { 
    local msg="$(date '+%Y-%m-%d %H:%M:%S') - [WARN] $*"
    echo -e "${YELLOW}[ ! ]${RESET} $*"
    echo "$msg" >> "$PROJECT_LOG"
    if [[ -w "$LOGFILE" ]]; then
      echo "$msg" >> "$LOGFILE"
    fi
  }
  
  error() { 
    local msg="$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] $*"
    echo -e "${RED}[ ✗ ]${RESET} $*" >&2
    echo "$msg" >> "$PROJECT_LOG"
    if [[ -w "$LOGFILE" ]]; then
      echo "$msg" >> "$LOGFILE"
    fi
  }

  # Start logging (only to project log, system log is optional)
  exec > >(tee -a "$PROJECT_LOG") 2>&1

  DRYRUN=false
  PRESEEDED=false
  for arg in "$@"; do
    case "$arg" in
      --dry-run) DRYRUN=true ;;
      --preseed) PRESEEDED=true ;;
    esac
  done

  info "=== Arch Installer Preflight ==="
  info "Dry-run mode:  $DRYRUN"
  info "Preseed mode:  $PRESEEDED"
  info "Log files: $LOGFILE and $PROJECT_LOG"

  [[ $EUID -eq 0 ]] || die "Run as root."

  # System information for logging
  info "=== System Information ==="
  info "Hostname: $(hostname 2>/dev/null || echo 'unknown')"
  info "Kernel: $(uname -r)"
  info "Architecture: $(uname -m)"
  info "Date: $(date)"
  info "Installer version: $(git -C "$(dirname "$0")" describe --tags 2>/dev/null || echo 'unknown')"

  # Disk information
  info "=== Disk Information ==="
  lsblk -d -o NAME,SIZE,MODEL | while read line; do
    info "Disk: $line"
  done

  ping -c1 -W1 archlinux.org &>/dev/null || warn "No internet connectivity."

  # Required tools
  info "=== Tool Verification ==="
  for pkg in sgdisk parted cryptsetup btrfs; do
    if command -v "$pkg" &>/dev/null; then
      info "Tool available: $pkg"
    else
      die "Missing required tool: $pkg"
    fi
  done
}
