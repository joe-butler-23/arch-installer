#!/usr/bin/env bash

# Simplified configuration loader for personal use

# Default configuration file
DEFAULT_CONFIG="config/desktop.yaml"

# Load configuration from YAML file
load_config() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        die "Configuration file not found: $yaml_file"
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
        die "Failed to parse YAML configuration: $yaml_file"
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

# Prompt for sensitive information (passwords only)
prompt_password() {
    local var="$1"
    local prompt="$2"
    
    read -rsp "$prompt: " input
    echo
    export "$var"="$input"
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
    
    # Load configuration
    if ! load_config "$config_file"; then
        die "Failed to load configuration"
    fi
    
    # Prompt for passwords (only interactive part)
    info "=== Password Setup ==="
    if [[ "${encryption:-false}" == "true" ]]; then
        prompt_password encryption_password "Enter encryption password"
    fi
    prompt_password root_password "Enter root password"
    prompt_password user_password "Enter user password"
    
    # Validate configuration
    if ! validate_config; then
        die "Configuration validation failed"
    fi
    
    # Show summary
    show_config_summary
    
    info "✅ Configuration completed successfully"
}
