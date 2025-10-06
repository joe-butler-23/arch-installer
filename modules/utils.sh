#!/usr/bin/env bash
# Shared utilities

BOLD='\e[1m'; GREEN='\e[32m'; RED='\e[31m'; YELLOW='\e[33m'; RESET='\e[0m'

info()  { echo -e "${GREEN}[ • ]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[ ! ]${RESET} $*"; }
error() { echo -e "${RED}[ ✗ ]${RESET} $*" >&2; }
die()   { error "$*"; exit 1; }

run_cmd() {
  local cmd="$*"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  if $DRYRUN; then
    local msg="$timestamp - [DRYRUN] $cmd"
    echo -e "${YELLOW}[DRYRUN]${RESET} $cmd"
    echo "$msg" >> "${LOGFILE:-/var/log/arch-installer.log}" 2>/dev/null || true
    echo "$msg" >> "logs/arch-installer-"*".log" 2>/dev/null || true
  else
    local msg="$timestamp - [CMD] $cmd"
    echo "$msg" >> "${LOGFILE:-/var/log/arch-installer.log}" 2>/dev/null || true
    echo "$msg" >> "logs/arch-installer-"*".log" 2>/dev/null || true
    
    # Execute the command and capture output
    if eval "$cmd"; then
      local success_msg="$timestamp - [SUCCESS] Command completed: $cmd"
      echo "$success_msg" >> "${LOGFILE:-/var/log/arch-installer.log}" 2>/dev/null || true
      echo "$success_msg" >> "logs/arch-installer-"*".log" 2>/dev/null || true
    else
      local exit_code=$?
      local error_msg="$timestamp - [ERROR] Command failed (exit code $exit_code): $cmd"
      echo "$error_msg" >> "${LOGFILE:-/var/log/arch-installer.log}" 2>/dev/null || true
      echo "$error_msg" >> "logs/arch-installer-"*".log" 2>/dev/null || true
      return $exit_code
    fi
  fi
}
