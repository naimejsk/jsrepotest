FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js LTS
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs

# Install GoTTY
RUN wget https://github.com/yudai/gotty/releases/download/v1.0.1/gotty_linux_amd64.tar.gz \
    && tar -xzf gotty_linux_amd64.tar.gz \
    && mv gotty /usr/local/bin/gotty \
    && rm gotty_linux_amd64.tar.gz

# App directory (Render default)
WORKDIR /app
COPY . .

# Expose Render's provided port
EXPOSE $PORT

# Start gotty and Pinggy Tunnel
CMD bash -lc "gotty --port ${PORT} --once bash & ssh -p 443 -R0:127.0.0.1:${PORT} tcp@free.pinggy.io"
