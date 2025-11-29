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
    && rm -rf /var/lib/apt/lists/*

# Install Node.js LTS
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs

# Install GoTTY
RUN wget https://github.com/yudai/gotty/releases/download/v1.0.1/gotty_linux_amd64.tar.gz \
    && tar -xzf gotty_linux_amd64.tar.gz \
    && mv gotty /usr/local/bin/gotty \
    && rm gotty_linux_amd64.tar.gz

# Put your app in /app (Render's default)
WORKDIR /app
COPY . .

# Install Node dependencies (optional)
#RUN npm install || true

# Render uses $PORT — we map gotty to it
EXPOSE $PORT

# Environment variables for gotty login
ENV GOTTYPASS=tty
ENV GOTTYUSER=tty

# Start gotty (web terminal)
CMD gotty \
    --port ${PORT} \
    --credential "${GOTTYUSER}:${GOTTYPASS}" \
    --once \
    bash
