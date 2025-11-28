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
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user with sudo access
RUN useradd -m -s /bin/bash terminal && \
    echo "terminal:terminal" | chpasswd && \
    usermod -aG sudo terminal && \
    echo "terminal ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set working directory
WORKDIR /app

# Create package.json
RUN echo '{\n\
  "name": "web-terminal",\n\
  "version": "1.0.0",\n\
  "dependencies": {\n\
    "express": "^4.18.2",\n\
    "node-pty": "^1.0.0",\n\
    "xterm": "^5.3.0",\n\
    "xterm-addon-fit": "^0.8.0"\n\
  }\n\
}' > package.json

# Install dependencies
RUN npm install

# Create server.js
RUN echo 'const express = require("express");\n\
const pty = require("node-pty");\n\
const app = express();\n\
const PORT = process.env.PORT || 10000;\n\
\n\
let terminals = {};\n\
let logs = {};\n\
\n\
app.use(express.static("public"));\n\
app.use(express.json());\n\
\n\
app.post("/terminals", (req, res) => {\n\
  const term = pty.spawn("bash", [], {\n\
    name: "xterm-color",\n\
    cols: 80,\n\
    rows: 30,\n\
    cwd: process.env.HOME,\n\
    env: process.env\n\
  });\n\
  const pid = term.pid;\n\
  terminals[pid] = term;\n\
  logs[pid] = "";\n\
  term.on("data", (data) => {\n\
    logs[pid] += data;\n\
  });\n\
  console.log("Created terminal with PID:", pid);\n\
  res.send({ pid });\n\
});\n\
\n\
app.post("/terminals/:pid/size", (req, res) => {\n\
  const { pid } = req.params;\n\
  const { cols, rows } = req.body;\n\
  if (terminals[pid]) {\n\
    terminals[pid].resize(cols, rows);\n\
  }\n\
  res.send({ ok: true });\n\
});\n\
\n\
app.post("/terminals/:pid/data", (req, res) => {\n\
  const { pid } = req.params;\n\
  const { data } = req.body;\n\
  if (terminals[pid]) {\n\
    terminals[pid].write(data);\n\
  }\n\
  res.send({ ok: true });\n\
});\n\
\n\
app.get("/terminals/:pid/data", (req, res) => {\n\
  const { pid } = req.params;\n\
  if (logs[pid]) {\n\
    res.send({ data: logs[pid] });\n\
    logs[pid] = "";\n\
  } else {\n\
    res.send({ data: "" });\n\
  }\n\
});\n\
\n\
app.listen(PORT, "0.0.0.0", () => {\n\
  console.log(`Terminal server running on port ${PORT}`);\n\
});' > server.js

# Create public directory and HTML
RUN mkdir -p public && \
    echo '<!DOCTYPE html>\n\
<html>\n\
<head>\n\
  <title>Render Terminal</title>\n\
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css" />\n\
  <style>\n\
    body { margin: 0; padding: 20px; background: #000; }\n\
    #terminal { height: 100vh; }\n\
  </style>\n\
</head>\n\
<body>\n\
  <div id="terminal"></div>\n\
  <script src="https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.js"></script>\n\
  <script src="https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.8.0/lib/xterm-addon-fit.js"></script>\n\
  <script>\n\
    const term = new Terminal({ cursorBlink: true });\n\
    const fitAddon = new FitAddon.FitAddon();\n\
    term.loadAddon(fitAddon);\n\
    term.open(document.getElementById("terminal"));\n\
    fitAddon.fit();\n\
\n\
    let pid;\n\
\n\
    fetch("/terminals", { method: "POST" })\n\
      .then(res => res.json())\n\
      .then(data => {\n\
        pid = data.pid;\n\
        startPolling();\n\
      });\n\
\n\
    term.onData(data => {\n\
      if (pid) {\n\
        fetch(`/terminals/${pid}/data`, {\n\
          method: "POST",\n\
          headers: { "Content-Type": "application/json" },\n\
          body: JSON.stringify({ data })\n\
        });\n\
      }\n\
    });\n\
\n\
    term.onResize(({ cols, rows }) => {\n\
      if (pid) {\n\
        fetch(`/terminals/${pid}/size`, {\n\
          method: "POST",\n\
          headers: { "Content-Type": "application/json" },\n\
          body: JSON.stringify({ cols, rows })\n\
        });\n\
      }\n\
    });\n\
\n\
    function startPolling() {\n\
      setInterval(() => {\n\
        if (pid) {\n\
          fetch(`/terminals/${pid}/data`)\n\
            .then(res => res.json())\n\
            .then(data => {\n\
              if (data.data) term.write(data.data);\n\
            });\n\
        }\n\
      }, 100);\n\
    }\n\
\n\
    window.addEventListener("resize", () => fitAddon.fit());\n\
  </script>\n\
</body>\n\
</html>' > public/index.html

# Expose port
ENV PORT=10000

# Start the server
CMD ["node", "server.js"]
