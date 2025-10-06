#!/bin/bash

# Arch Linux Installation Verification Script
# Verifies system configuration and security settings

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_service() {
    local service=$1
    local description=$2
    
    if systemctl is-enabled "$service" &>/dev/null; then
        success "$description is enabled"
        return 0
    else
        error "$description is not enabled"
        return 1
    fi
}

check_file_exists() {
    local file=$1
    local description=$2
    
    if [[ -f "$file" ]]; then
        success "$description exists"
        return 0
    else
        error "$description is missing"
        return 1
    fi
}

verify_disk_layout() {
    info "=== Verifying Disk Layout ==="
    
    # Check for Btrfs subvolumes
    if findmnt -t btrfs / &>/dev/null; then
        success "Root filesystem is Btrfs"
        
        # Check for @ subvolume
        if findmnt -t btrfs -o SOURCE,TARGET / | grep -q "\[@\]"; then
            success "Root @ subvolume is mounted"
        else
            error "Root @ subvolume is not mounted"
        fi
        
        # Check for @home subvolume
        if findmnt -t btrfs -o SOURCE,TARGET /home &>/dev/null; then
            success "Home @home subvolume is mounted"
        else
            warning "Home @home subvolume is not mounted or doesn't exist"
        fi
    else
        error "Root filesystem is not Btrfs"
    fi
    
    # Check for LUKS encryption
    if [[ -b /dev/mapper/cryptroot ]]; then
        success "LUKS encrypted root is available"
    else
        error "LUKS encrypted root is not available"
    fi
}

verify_snapper() {
    info "=== Verifying Snapper Configuration ==="
    
    check_file_exists "/etc/snapper/configs/root" "Snapper root configuration"
    check_file_exists "/etc/snapper/configs/home" "Snapper home configuration"
    check_file_exists "/.snapshots" "Root snapshots directory"
    check_file_exists "/home/.snapshots" "Home snapshots directory"
    
    # Check Snapper services
    check_service "snapper-timeline.timer" "Snapper timeline timer"
    check_service "snapper-cleanup.timer" "Snapper cleanup timer"
    
    # Check if snapshots exist
    if snapper list &>/dev/null; then
        success "Snapper is functional"
    else
        error "Snapper is not functional"
    fi
}

verify_zram() {
    info "=== Verifying ZRAM Configuration ==="
    
    check_file_exists "/etc/systemd/zram-generator.conf" "ZRAM configuration"
    
    if [[ -b /dev/zram0 ]]; then
        success "ZRAM device is available"
        
        # Check if ZRAM is being used as swap
        if swapon --show | grep -q zram0; then
            success "ZRAM is active as swap"
        else
            error "ZRAM is not active as swap"
        fi
    else
        error "ZRAM device is not available"
    fi
}

verify_secure_boot() {
    info "=== Verifying Secure Boot Configuration ==="
    
    # Check if Secure Boot is enabled in firmware
    if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
        success "Secure Boot is enabled in firmware"
    else
        warning "Secure Boot is not enabled in firmware"
    fi
    
    # Check sbctl keys
    if command -v sbctl &>/dev/null; then
        check_file_exists "/usr/share/secureboot/keys/DB/db.key" "Secure Boot database key"
        check_file_exists "/usr/share/secureboot/keys/KEK/kek.key" "Secure Boot KEK key"
        check_file_exists "/usr/share/secureboot/keys/PK/pk.key" "Secure Boot PK key"
        
        # Verify signed files
        if sbctl verify &>/dev/null; then
            success "All boot files are properly signed"
        else
            error "Some boot files are not properly signed"
        fi
    else
        error "sbctl is not installed"
    fi
}

verify_services() {
    info "=== Verifying System Services ==="
    
    check_service "systemd-networkd.service" "Systemd networkd"
    check_service "systemd-resolved.service" "Systemd resolved"
    check_service "iwd.service" "iwd wireless service"
    check_service "ufw.service" "UFW firewall"
    check_service "apparmor.service" "AppArmor security framework"
    check_service "fail2ban.service" "Fail2ban intrusion prevention"
    check_service "tlp.service" "TLP power management"
    check_service "bluetooth.service" "Bluetooth service"
    check_service "pacman-update.timer" "Pacman update timer"
    check_service "sbctl-verify.timer" "sbctl verification timer"
}

verify_network_security() {
    info "=== Verifying Network Security ==="
    
    # Check UFW status
    if ufw status | grep -q "Status: active"; then
        success "UFW firewall is active"
    else
        error "UFW firewall is not active"
    fi
    
    # Check AppArmor status
    if aa-status 2>/dev/null | grep -q "profiles are loaded"; then
        success "AppArmor profiles are loaded"
    else
        error "AppArmor profiles are not loaded"
    fi
}

verify_system_integrity() {
    info "=== Verifying System Integrity ==="
    
    # Check for failed services
    local failed_services
    failed_services=$(systemctl --failed --no-legend | wc -l)
    if [[ $failed_services -eq 0 ]]; then
        success "No failed services"
    else
        warning "$failed_services failed services found"
        systemctl --failed --no-legend
    fi
    
    # Check for package verification
    if pacman -Qk 2>/dev/null | grep -q "0 missing files"; then
        success "All packages have complete files"
    else
        warning "Some packages have missing files"
    fi
}

main() {
    info "Starting Arch Linux system verification..."
    echo
    
    verify_disk_layout
    echo
    verify_snapper
    echo
    verify_zram
    echo
    verify_secure_boot
    echo
    verify_services
    echo
    verify_network_security
    echo
    verify_system_integrity
    
    echo
    info "System verification completed"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
    exit 1
fi

main "$@"
