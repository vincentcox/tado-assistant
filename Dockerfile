FROM debian:bullseye

# Install required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl jq tzdata ca-certificates coreutils && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy scripts into the container
COPY tado-assistant.sh /usr/local/bin/tado-assistant.sh
COPY install.sh /usr/local/bin/install.sh

# Set permissions and prepare log file
RUN chmod +x /usr/local/bin/tado-assistant.sh /usr/local/bin/install.sh && \
    mkdir -p /var/log && \
    touch /var/log/tado-assistant.log && \
    chmod 666 /var/log/tado-assistant.log

# Define entrypoint script
ENTRYPOINT ["/bin/bash", "-c", \
    "if [ ! -s /etc/tado-assistant.env ]; then \
        /usr/local/bin/install.sh; \
    fi; \
    exec /usr/local/bin/tado-assistant.sh"]
