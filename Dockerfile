FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install system basics
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
# Create NODE project files
# -------------------------

WORKDIR /app

# package.json
RUN cat <<'EOF' > package.json
{
  "name": "terminal-server",
  "type": "module",
  "dependencies": {
    "axios": "^1.6.7",
    "cors": "^2.8.5",
    "express": "^4.18.2",
    "node-cron": "^3.0.2",
    "node-pty": "^1.0.0",
    "ws": "^8.15.0"
  }
}
EOF


# server.js
RUN cat <<'EOF' > server.js
import express from "express";
import cors from "cors";
import { WebSocketServer } from "ws";
import { spawn } from "node-pty";
import path from "path";
import axios from "axios";
import cron from "node-cron";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(cors());

const PORT = process.env.PORT || 3000;
const RENDER_URL = process.env.RENDER_EXTERNAL_URL;

// --- HTTP Routes ---

app.get("/", (req, res) => {
  res.send("Server is running");
});

app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});

// Serve xterm client
app.use("/tty", express.static(path.join(__dirname, "public")));

const server = app.listen(PORT, () => {
  console.log(`Server running on ${PORT}`);
});

// --- WebSocket Terminal ---

const wss = new WebSocketServer({ server, path: "/ws" });

wss.on("connection", (ws) => {
  console.log("⚡ WebSocket terminal connected");

  const shell = spawn("bash", [], {
    name: "xterm-color",
    cols: 80,
    rows: 30,
    cwd: process.env.HOME,
    env: process.env,
  });

  shell.on("data", (data) => ws.send(data));
  ws.on("message", (msg) => shell.write(msg.toString()));
  ws.on("close", () => shell.kill());
});

// --- Render Keep-Alive Cron job ---

if (RENDER_URL) {
  console.log("Keep-alive enabled:", RENDER_URL);

  const CronExpression = {
    EVERY_5_MINUTES: "0 */5 * * * *",
  };

  cron.schedule(CronExpression.EVERY_5_MINUTES, async () => {
    try {
      await axios.get(RENDER_URL);
      console.log(
        `Pinged ${RENDER_URL} at ${new Date().toISOString()}`
      );
    } catch (error) {
      console.error(`Ping error:`, error.message);
    }
  });
}
EOF


# public directory & index.html
RUN mkdir -p public

RUN cat <<'EOF' > public/index.html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Web Terminal</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm/css/xterm.css">
  <script src="https://cdn.jsdelivr.net/npm/xterm/lib/xterm.js"></script>
</head>

<body style="margin:0;background:black;">
  <div id="terminal" style="width:100vw;height:100vh;"></div>

  <script>
    const term = new Terminal();
    term.open(document.getElementById("terminal"));

    const ws = new WebSocket(`wss://${window.location.hostname}/ws`);

    ws.onmessage = (ev) => term.write(ev.data);
    term.onData(data => ws.send(data));
  </script>
</body>
</html>
EOF



# Install Node dependencies
RUN npm install

# Render will supply PORT env var
EXPOSE $PORT

CMD ["node", "server.js"]
