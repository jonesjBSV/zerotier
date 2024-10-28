FROM ubuntu:latest

# Install curl, jq and other dependencies
RUN apt-get update && apt-get install -y curl jq

# Copy the startup script
COPY zerotier-startup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/zerotier-startup.sh

# Set environment variables (or use docker-compose/kubernetes config)
ENV ZEROTIER_NETWORK_ID="your_network_id"
ENV ZEROTIER_CENTRAL_TOKEN="your_api_token"

# Run the script
CMD ["/usr/local/bin/zerotier-startup.sh"]
