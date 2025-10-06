#!/usr/bin/env bash

# Configuration loader with YAML support and interactive fallback

# Default configuration file
DEFAULT_CONFIG="config/install.yaml"

# Load configuration from YAML file
load_config() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        warn "Configuration file not found: $yaml_file"
        return 1
    fi
    
    info "Loading configuration from $yaml_file"
    
    # Check if yq is available
    if ! command -v yq &>/dev/null; then
        warn "yq not found - installing yq for YAML parsing"
        run_cmd "pacman -S --needed --noconfirm go-yq"
    fi
    
    # Load YAML configuration using yq (simple key-value pairs)
    local config_values
    config_values=$(yq eval '. | to_entries | .[] | select(.value | type != "!!map" and .value | type != "!!seq") | "\(.key)=\(.value)"' "$yaml_file" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        error "Failed to parse YAML configuration: $yaml_file"
        return 1
    fi
    
    # Export configuration values
    while IFS="=" read -r key value; do
        # Skip invalid keys
        if [[ -z "$key" || "$key" =~ [^a-zA-Z0-9_] ]]; then
            continue
        fi
        
        # Handle different value types
        if [[ "$value" == "true" ]]; then
            export "$key"=true
        elif [[ "$value" == "false" ]]; then
            export "$key"=false
        elif [[ "$value" =~ ^[0-9]+$ ]]; then
            export "$key"="$value"
        elif [[ "$value" =~ ^\".*\"$ ]]; then
            # Remove quotes from string values
            export "$key"="${value//\"/}"
        elif [[ "$value" == "null" || "$value" == "~" ]]; then
            export "$key"=""
        else
            export "$key"="$value"
        fi
    done <<< "$config_values"
    
    info "Configuration loaded successfully"
    return 0
}

# Interactive prompt for missing configuration
prompt_if_empty() {
    local var="$1"
    local prompt="$2"
    local default="${3:-}"
    local is_sensitive="${4:-false}"
    
    if [[ -z "${!var:-}" ]]; then
        if [[ "$is_sensitive" == "true" ]]; then
            read -rsp "$prompt [${default:-none}]: " input
            echo
        else
            read -rp "$prompt [${default:-none}]: " input
        fi
        export "$var"="${input:-$default}"
    fi
}

# Prompt for boolean values
prompt_boolean() {
    local var="$1"
    local prompt="$2"
    local default="${3:-false}"
    
    if [[ -z "${!var:-}" ]]; then
        while true; do
            read -rp "$prompt [y/N]: " input
            case "${input:-$default}" in
                [Yy]|[Yy][Ee][Ss]) 
                    export "$var"=true
                    break
                    ;;
                [Nn]|[Nn][Oo]|"") 
                    export "$var"=false
                    break
                    ;;
                *) 
                    echo "Please answer yes or no"
                    ;;
            esac
        done
    fi
}

# Prompt for selection from choices
prompt_choice() {
    local var="$1"
    local prompt="$2"
    shift 2
    local choices=("$@")
    local default="${choices[0]}"
    
    if [[ -z "${!var:-}" ]]; then
        echo "$prompt"
        for i in "${!choices[@]}"; do
            echo "  $((i+1))) ${choices[i]}"
        done
        
        while true; do
            read -rp "Select choice [1-${#choices[@]}]: " input
            if [[ "$input" =~ ^[0-9]+$ ]] && [[ "$input" -ge 1 ]] && [[ "$input" -le ${#choices[@]} ]]; then
                export "$var"="${choices[$((input-1))]}"
                break
            elif [[ -z "$input" ]]; then
                export "$var"="$default"
                break
            else
                echo "Please enter a number between 1 and ${#choices[@]}"
            fi
        done
    fi
}

# Validate configuration
validate_config() {
    local errors=0
    
    # Check required variables
    local required_vars=("disk" "hostname" "username" "locale" "timezone")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Required configuration missing: $var"
            ((errors++))
        fi
    done
    
    # Validate disk exists
    if [[ -n "${disk:-}" && ! -b "$disk" ]]; then
        error "Disk does not exist: $disk"
        ((errors++))
    fi
    
    # Validate username format
    if [[ -n "${username:-}" && ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        error "Invalid username format: $username"
        ((errors++))
    fi
    
    # Validate locale format
    if [[ -n "${locale:-}" && ! "$locale" =~ ^[a-z]{2}_[A-Z]{2}\.UTF-8$ ]]; then
        error "Invalid locale format: $locale (expected: en_GB.UTF-8)"
        ((errors++))
    fi
    
    return $errors
}

# Display configuration summary
show_config_summary() {
    info "=== Configuration Summary ==="
    info "Disk: ${disk:-not set}"
    info "Hostname: ${hostname:-not set}"
    info "Username: ${username:-not set}"
    info "Locale: ${locale:-not set}"
    info "Keyboard: ${keyboard_layout:-uk}"
    info "Timezone: ${timezone:-not set}"
    info "Kernel: ${kernel:-linux}"
    info "Encryption: ${encryption:-false}"
    info "Secure Boot: ${secure_boot:-false}"
    info "ZRAM: ${enable_zram:-false}"
    info "Tailscale: ${enable_tailscale:-false}"
    info "Syncthing: ${enable_syncthing:-false}"
    echo
}

# Main configuration function
run_config() {
    info "=== Configuration Loading ==="
    
    # Determine config file to use
    local config_file="$DEFAULT_CONFIG"
    
    # Check for --config argument
    for arg in "$@"; do
        case "$arg" in
            --config=*)
                config_file="${arg#--config=}"
                ;;
            --config)
                shift
                config_file="$1"
                ;;
        esac
    done
    
    # Try to load configuration
    if ! load_config "$config_file"; then
        warn "Failed to load configuration, using interactive mode"
    fi
    
    # Interactive prompts for missing values
    info "=== Interactive Configuration ==="
    
    # Basic system configuration
    prompt_if_empty disk "Select install disk" "/dev/nvme0n1"
    prompt_if_empty hostname "Enter hostname" "arch-linux"
    prompt_if_empty username "Enter username" "user"
    prompt_choice locale "Select locale" "en_GB.UTF-8" "en_US.UTF-8"
    prompt_if_empty keyboard_layout "Enter keyboard layout" "uk"
    prompt_if_empty timezone "Enter timezone" "Europe/London"
    prompt_choice kernel "Select kernel" "linux" "linux-lts" "linux-zen" "linux-hardened"
    
    # Security configuration
    prompt_boolean encryption "Enable LUKS encryption" "true"
    prompt_boolean secure_boot "Enable Secure Boot" "true"
    
    # Performance options
    prompt_boolean enable_zram "Enable ZRAM" "true"
    prompt_choice cpu_governor "Select CPU governor" "performance" "powersave" "ondemand" "schedutil"
    
    # Network services
    prompt_boolean enable_tailscale "Enable Tailscale" "true"
    prompt_boolean enable_syncthing "Enable Syncthing" "true"
    
    # Security hardening
    prompt_boolean enable_firewall "Enable UFW firewall" "true"
    prompt_boolean enable_apparmor "Enable AppArmor" "true"
    prompt_boolean enable_fail2ban "Enable Fail2ban" "true"
    
    # Backup and maintenance
    prompt_boolean enable_snapper "Enable Snapper snapshots" "true"
    prompt_boolean auto_updates "Enable automatic updates" "true"
    prompt_boolean btrfs_scrub "Enable Btrfs scrub" "true"
    prompt_boolean enable_reflector "Enable mirror updates" "true"
    
    # DNS configuration
    prompt_boolean dns_over_tls "Enable DNS-over-TLS" "true"
    prompt_boolean dnssec "Enable DNSSEC" "true"
    
    # Post-installation
    prompt_boolean dotfiles_enabled "Enable dotfiles stowing" "true"
    if [[ "${dotfiles_enabled:-false}" == "true" ]]; then
        prompt_if_empty dotfiles_repository "Dotfiles repository" "git@github.com:joe-butler-23/.dotfiles"
    fi
    
    # Sensitive information (always prompted)
    if [[ "${encryption:-false}" == "true" ]]; then
        prompt_if_empty encryption_password "Enter encryption password" "" true
    fi
    prompt_if_empty root_password "Enter root password" "" true
    prompt_if_empty user_password "Enter user password" "" true
    
    # Validate configuration
    if ! validate_config; then
        error "Configuration validation failed"
        exit 1
    fi
    
    # Show summary
    show_config_summary
    
    info "✅ Configuration completed successfully"
}
