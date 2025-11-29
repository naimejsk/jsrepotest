FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------
# Install sudo and dependencies
# ------------------------
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    wget \
    git \
    bash \
    build-essential \
    ca-certificates \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# ------------------------
# Install Node.js LTS
# ------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs

# ------------------------
# Install sshx (official working tarball)
# ------------------------
RUN wget https://sshx.s3.amazonaws.com/sshx-x86_64-unknown-linux-musl.tar.gz \
    -O /tmp/sshx.tar.gz && \
    tar -xzf /tmp/sshx.tar.gz -C /tmp && \
    mv /tmp/sshx /usr/local/bin/sshx && \
    chmod +x /usr/local/bin/sshx && \
    rm /tmp/sshx.tar.gz

# ------------------------
# Workdir
# ------------------------
WORKDIR /app

# ------------------------
# package.json
# ------------------------
RUN cat <<'EOF' > package.json
{
  "name": "sshx-server",
  "type": "module",
  "dependencies": {
    "axios": "^1.6.7",
    "cors": "^2.8.5",
    "express": "^4.18.2",
    "node-cron": "^3.0.2"
  }
}
EOF

# ------------------------
# server.js
# ------------------------
RUN cat <<'EOF' > server.js
import express from "express";
import cors from "cors";
import cron from "node-cron";
import axios from "axios";
import { spawn } from "child_process";

const app = express();
app.use(cors());

const PORT = process.env.PORT || 3000;
const RENDER_URL = process.env.RENDER_EXTERNAL_URL;

let sshxProcess = null;
let sshxKey = null;

// Function to remove ANSI escape codes
function stripANSI(str) {
  return str.replace(/\u001b\[[0-9;]*m/g, "").trim();
}

// Start sshx if not running
function startSSHX() {
  if (sshxProcess) return;

  console.log("Starting sshx...");
  sshxProcess = spawn("sshx", [], { env: process.env, cwd: "/app" });

  sshxProcess.stdout.on("data", (data) => {
    const line = stripANSI(data.toString());

    // Extract key after https://sshx.io/s/
    const match = line.match(/https:\/\/sshx\.io\/s\/([^\s]+)/);
    if (match) {
      sshxKey = match[1];
      console.log("SSHX KEY:", sshxKey);
    }
  });

  sshxProcess.on("exit", () => {
    console.log("sshx stopped");
    sshxProcess = null;
    sshxKey = null;
  });
}

// ------------------------
// Routes
// ------------------------
app.get("/", (req, res) => res.send("Server is running"));

app.get("/health", (req, res) => res.json({ status: "ok" }));

app.get("/tty", (req, res) => {
  if (!sshxProcess) startSSHX();

  res.json({
    status: "ok",
    time: sshxKey || null
  });
});

// ------------------------
// Render keep-alive (allowed)
if (RENDER_URL) {
  cron.schedule("0 */5 * * * *", async () => {
    try {
      await axios.get(RENDER_URL);
      console.log("Pinged", RENDER_URL);
    } catch (err) {
      console.error("Ping error:", err.message);
    }
  });
}

// ------------------------
app.listen(PORT, () => console.log("Server running on port", PORT));
EOF

# ------------------------
# Install Node.js dependencies
# ------------------------
RUN npm install

# ------------------------
# Expose Render port
# ------------------------
EXPOSE $PORT

# ------------------------
# Start server
# ------------------------
CMD ["node", "server.js"]
