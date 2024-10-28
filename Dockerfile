FROM ubuntu:latest

# Install curl and other dependencies
RUN apt-get update && apt-get install -y curl

# Copy the startup script
COPY zerotier-startup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/zerotier-startup.sh

# Set environment variable (or use docker-compose/kubernetes config)
ENV ZEROTIER_NETWORK_ID="your_network_id"

# Run the script
CMD ["/usr/local/bin/zerotier-startup.sh"]
