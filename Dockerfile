FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
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


# ---------------------------------------
# Install sshx (correct working version)
# ---------------------------------------
RUN wget https://sshx.s3.amazonaws.com/sshx-x86_64-unknown-linux-musl.tar.gz \
    -O /tmp/sshx.tar.gz && \
    tar -xzf /tmp/sshx.tar.gz -C /tmp && \
    mv /tmp/sshx /usr/local/bin/sshx && \
    chmod +x /usr/local/bin/sshx && \
    rm /tmp/sshx.tar.gz


WORKDIR /app


# =======================================
# package.json
# =======================================
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


# =======================================
# server.js
# =======================================
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
let sshxKey = null; // the code after https://sshx.io/s/


// Start sshx if not running
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

    // Parse link
    // "➜  Link:  https://sshx.io/s/XXXX#YYYY"
    if (line.includes("https://sshx.io/s/")) {
      const part = line.split("https://sshx.io/s/")[1];
      sshxKey = part.trim();  // full key
      console.log("SSHX KEY:", sshxKey);
    }
  });

  sshxProcess.on("exit", () => {
    console.log("sshx stopped");
    sshxProcess = null;
    sshxKey = null;
  });
}


// ------------------ Routes ------------------

app.get("/", (req, res) => res.send("Server is running"));

app.get("/health", (req, res) =>
  res.json({ status: "ok" })
);

app.get("/tty", (req, res) => {
  if (!sshxProcess) startSSHX();

  res.json({
    status: "ok",
    time: sshxKey
  });
});


// Render keep alive (normal, allowed)
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

app.listen(PORT, () => console.log("Server running:", PORT));
EOF


RUN npm install

EXPOSE $PORT

CMD ["node", "server.js"]
