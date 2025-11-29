FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisites
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    bash \
    build-essential \
    ca-certificates \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js LTS
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs


# -------------------------
# Install sshx
# -------------------------

RUN wget https://github.com/souramoo/sshx/releases/download/v0.4.1/sshx-v0.4.1-linux-x64 \
    -O /usr/local/bin/sshx && chmod +x /usr/local/bin/sshx


# -------------------------
# Create project
# -------------------------

WORKDIR /app

# package.json
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


# server.js
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
let sshxLink = null;   // Full URL returned by sshx
let sshxKey = null;    // Extracted "7tSZt4UZcW#jl8FYQC0vMaO0W"

// Function: start sshx if not running
function startSSHX() {
  if (sshxProcess) return;

  console.log("Starting sshx...");

  sshxProcess = spawn("sshx", [], {
    env: process.env,
    cwd: "/app"
  });

  sshxProcess.stdout.on("data", (data) => {
    const line = data.toString().trim();
    console.log("sshx:", line);

    // Parse link line:
    // "➜  Link:  https://sshx.io/s/7tSZt4UZcW#jl8FYQC0vMaO0W"
    if (line.includes("https://sshx.io/s/")) {
      sshxLink = line.split("https://sshx.io/s/")[1];
      // key = 7tSZt4UZcW#jl8FYQC0vMaO0W
      sshxKey = sshxLink.trim();
      console.log("SSHX KEY:", sshxKey);
    }
  });

  sshxProcess.on("exit", () => {
    console.log("sshx stopped");
    sshxProcess = null;
    sshxLink = null;
    sshxKey = null;
  });
}

// -------------------------
// Routes
// -------------------------

app.get("/", (req, res) => {
  res.send("Server is running");
});

app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});

app.get("/tty", (req, res) => {
  if (!sshxProcess) startSSHX();

  res.json({
    status: "ok",
    time: sshxKey || null
  });
});

// -------------------------
// Render Keep Alive
// -------------------------

if (RENDER_URL) {
  console.log("Keep-alive ping enabled:", RENDER_URL);

  cron.schedule("0 */5 * * * *", async () => {
    try {
      await axios.get(RENDER_URL);
      console.log("Pinged", RENDER_URL, "at", new Date().toISOString());
    } catch (err) {
      console.error("Ping error:", err.message);
    }
  });
}

// -------------------------
app.listen(PORT, () =>
  console.log("Server started on port", PORT)
);
EOF


RUN npm install

EXPOSE $PORT

CMD ["node", "server.js"]
