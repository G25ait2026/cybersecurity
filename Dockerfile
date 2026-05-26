# Use Ubuntu base image
FROM ubuntu:20.04

# Avoid prompt during installations
ENV DEBIAN_FRONTEND=noninteractive

# Install essential build tools, gcc, make, and library components
RUN apt-get update && apt-get install -y \
    gcc \
    libc6-dev \
    make \
    pthread-w32 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create target test file owned by root and readable by all but writable by NONE
RUN mkdir -p /var/secret && \
    echo "THIS_IS_A_SECRET_KEY_THAT_IS_READ_ONLY" > /var/secret/target.txt && \
    chmod 444 /var/secret/target.txt && \
    chown root:root /var/secret/target.txt

# Create an unprivileged user to perform the exploit
RUN useradd -m -s /bin/bash victim

# Copy source code and demo scripts
COPY dirtyc0w.c /home/victim/dirtyc0w.c
COPY run_demo.sh /home/victim/run_demo.sh

# Change ownerships and set execute permissions
RUN chown -R victim:victim /home/victim && \
    chmod +x /home/victim/run_demo.sh

# Switch to the low-privileged user environment
USER victim
WORKDIR /home/victim

# Default to running the demo
CMD ["/bin/bash", "/home/victim/run_demo.sh"]
