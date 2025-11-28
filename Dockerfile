# Use Ubuntu as base image
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install Node.js, npm, and essential tools
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    net-tools \
    iputils-ping \
    build-essential \
    python3 \
    python3-pip \
    sudo \
    cmake \
    g++ \
    pkg-config \
    libwebsockets-dev \
    libjson-c-dev \
    libssl-dev \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install ttyd (lightweight web terminal)
RUN wget https://github.com/tsl0922/ttyd/releases/download/1.7.4/ttyd.x86_64 -O /usr/local/bin/ttyd && \
    chmod +x /usr/local/bin/ttyd

# Create a non-root user with sudo access
RUN useradd -m -s /bin/bash terminal && \
    echo "terminal:terminal" | chpasswd && \
    usermod -aG sudo terminal && \
    echo "terminal ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set working directory
WORKDIR /home/terminal

# Expose port (Render uses PORT environment variable)
ENV PORT=10000

# Create startup script
RUN echo '#!/bin/bash\n\
echo "================================="\n\
echo "Web Terminal Ready!"\n\
echo "================================="\n\
echo "Access your terminal in browser"\n\
echo "================================="\n\
ttyd -p $PORT -i 0.0.0.0 --writable --credential terminal:terminal bash' > /start.sh && \
    chmod +x /start.sh

# Switch to terminal user
USER terminal

# Start the web terminal
CMD ["/start.sh"]
