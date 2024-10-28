#!/bin/bash

# ZeroTier startup script
# This script automates connecting to a ZeroTier network and maintains the connection

# Configuration
ZEROTIER_NETWORK_ID="${ZEROTIER_NETWORK_ID:-}"  # Network ID from environment variable
LOG_FILE="/var/log/zerotier-startup.log"
CHECK_INTERVAL=60  # Time between connection checks in seconds
ZEROTIER_CENTRAL_TOKEN="${ZEROTIER_CENTRAL_TOKEN:-}"  # API token from ZeroTier Central
ZEROTIER_CENTRAL_URL="https://api.zerotier.com/api/v1"

# Add these OS detection variables near the top after the configuration section
OS_TYPE="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
elif [[ -f /etc/os-release ]]; then
    OS_TYPE="linux"
fi

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
        
        case $OS_TYPE in
            "macos")
                if ! command -v brew &> /dev/null; then
                    log "Homebrew is required for macOS installation. Please install it first."
                    exit 1
                fi
                brew install zerotier-one || {
                    log "Failed to install ZeroTier"
                    exit 1
                }
                ;;
            "linux")
                curl -s https://install.zerotier.com | bash || {
                    log "Failed to install ZeroTier"
                    exit 1
                }
                ;;
            *)
                log "Unsupported operating system"
                exit 1
                ;;
        esac
        log "ZeroTier installed successfully"
    fi
}

# Start ZeroTier service
start_zerotier_service() {
    log "Starting ZeroTier service..."
    
    case $OS_TYPE in
        "macos")
            # Check if ZeroTier is already running
            if pgrep -x "zerotier-one" > /dev/null; then
                log "ZeroTier is already running"
            else
                # Start ZeroTier using launchctl
                sudo launchctl load /Library/LaunchDaemons/com.zerotier.one.plist 2>/dev/null || {
                    log "Failed to start ZeroTier with launchctl, trying direct method"
                    sudo zerotier-one -d
                }
            fi
            ;;
        "linux")
            # Existing Linux logic
            if pidof systemd >/dev/null; then
                systemctl start zerotier-one || {
                    log "Failed to start ZeroTier with systemctl, trying alternative method"
                    zerotier-one -d
                }
            else
                zerotier-one -d || {
                    log "Failed to start ZeroTier daemon"
                    exit 1
                }
            fi
            ;;
        *)
            log "Unsupported operating system"
            exit 1
            ;;
    esac
    
    # Wait for service to initialize
    local max_attempts=30
    local attempt=0
    while ! zerotier-cli info >/dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            log "ZeroTier service failed to start after $max_attempts seconds"
            exit 1
        fi
        sleep 1
    done
    
    log "ZeroTier service started successfully"
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
    
    # macOS might return "OK" or "ACTIVE"
    if [ "$status" = "OK" ] || [ "$status" = "ACTIVE" ]; then
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

# Authorize node
authorize_node() {
    local node_id=$1
    
    if [ -z "$ZEROTIER_CENTRAL_TOKEN" ]; then
        log "WARNING: ZEROTIER_CENTRAL_TOKEN not set. Cannot auto-authorize nodes."
        return 1
    }

    log "Attempting to authorize node: $node_id"
    
    # Get the current node config
    local response
    response=$(curl -s -X POST \
        -H "Authorization: Bearer $ZEROTIER_CENTRAL_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"config\": {\"authorized\": true}}" \
        "$ZEROTIER_CENTRAL_URL/network/$ZEROTIER_NETWORK_ID/member/$node_id")

    if echo "$response" | grep -q '"authorized":true'; then
        log "Successfully authorized node: $node_id"
        return 0
    else
        log "Failed to authorize node: $node_id"
        return 1
    fi
}

# Monitor for new nodes
monitor_new_nodes() {
    while true; do
        # Get list of unauthorized nodes
        local nodes
        nodes=$(curl -s -H "Authorization: Bearer $ZEROTIER_CENTRAL_TOKEN" \
            "$ZEROTIER_CENTRAL_URL/network/$ZEROTIER_NETWORK_ID/member" | \
            jq -r '.[] | select(.config.authorized==false) | .nodeId')

        for node in $nodes; do
            authorize_node "$node"
        done
        
        sleep 60  # Check every minute
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
    start_zerotier_service
    
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
    
    # Start monitoring connection
    monitor_connection &
    
    # Start monitoring for new nodes if token is provided
    if [ -n "$ZEROTIER_CENTRAL_TOKEN" ]; then
        monitor_new_nodes &
    fi
    
    # Wait for all background processes
    wait
}

# Trap signals
trap 'log "Received signal to stop. Exiting..."; exit 0' SIGTERM SIGINT

# Start the script
main
