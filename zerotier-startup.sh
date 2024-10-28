#!/bin/bash

# ZeroTier startup script
# This script automates connecting to a ZeroTier network and maintains the connection

# Configuration
ZEROTIER_NETWORK_ID="${ZEROTIER_NETWORK_ID:-}"  # Network ID from environment variable
LOG_FILE="/var/log/zerotier-startup.log"
CHECK_INTERVAL=60  # Time between connection checks in seconds

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if ZeroTier is installed
check_zerotier_installed() {
    if ! command -v zerotier-cli &> /dev/null; then
        log "ZeroTier is not installed. Installing..."
        curl -s https://install.zerotier.com | bash || {
            log "Failed to install ZeroTier"
            exit 1
        }
        log "ZeroTier installed successfully"
    fi
}

# Start ZeroTier service
start_zerotier() {
    log "Starting ZeroTier service..."
    systemctl start zerotier-one
    sleep 5  # Wait for service to start
}

# Join ZeroTier network
join_network() {
    if [ -z "$ZEROTIER_NETWORK_ID" ]; then
        log "ERROR: ZEROTIER_NETWORK_ID not set"
        exit 1
    fi

    log "Joining ZeroTier network: $ZEROTIER_NETWORK_ID"
    zerotier-cli join "$ZEROTIER_NETWORK_ID"
}

# Check network status
check_network_status() {
    local status
    status=$(zerotier-cli listnetworks | grep "$ZEROTIER_NETWORK_ID" | awk '{print $6}')
    
    if [ "$status" = "OK" ]; then
        return 0
    else
        return 1
    fi
}

# Monitor connection
monitor_connection() {
    while true; do
        if ! check_network_status; then
            log "Connection lost. Attempting to rejoin network..."
            join_network
        else
            log "Connection OK"
        fi
        sleep "$CHECK_INTERVAL"
    done
}

# Main execution
main() {
    log "Starting ZeroTier startup script"
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    # Check and install ZeroTier if needed
    check_zerotier_installed
    
    # Start ZeroTier service
    start_zerotier
    
    # Join network
    join_network
    
    # Wait for initial connection
    log "Waiting for network connection..."
    for i in {1..30}; do
        if check_network_status; then
            log "Successfully connected to ZeroTier network"
            break
        fi
        if [ $i -eq 30 ]; then
            log "Failed to connect to network after 30 seconds"
            exit 1
        fi
        sleep 1
    done
    
    # Start monitoring
    monitor_connection
}

# Trap signals
trap 'log "Received signal to stop. Exiting..."; exit 0' SIGTERM SIGINT

# Start the script
main
