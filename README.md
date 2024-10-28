# ZeroTier Startup Script

## Features

1. Automatic installation of ZeroTier if not present
2. Service management
3. Network connection and monitoring
4. Detailed logging
5. Error handling
6. Signal handling for graceful shutdown
7. Configuration via environment variables

## Usage

1. Make it executable:
```
chmod +x zerotier-startup.sh
```

2. Set the network ID:
```
export ZEROTIER_NETOWORK_ID="your_network_id"
```

3. Set the ZeroTier Central API token:
```
export ZEROTIER_CENTRAL_TOKEN="your_api_token"
```

4. Run the script:
```
sudo ./zerotier-startup.sh
```

## Docker

For Docker usage, you can include this script in your Dockerfile:

The script will:
- Install ZeroTier if not present
- Join the specified ZeroTier network
- Monitor the connection status
- Automatically reconnect if the connection is lost
- Log all activities to /var/log/zerotier-startup.log
