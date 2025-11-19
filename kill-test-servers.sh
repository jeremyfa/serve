#!/bin/bash

# Kill any existing test servers from this project
echo "Killing existing test servers..."
# Only kill PHP servers on port 8000 in our test directory
pkill -f "php.*localhost:8000.*test-php" 2>/dev/null || true
# Only kill Node.js running our test-server.js
pkill -f "node.*out/test-nodejs/test-server.js" 2>/dev/null || true
# Only kill our C++ TestServer in the test-cpp directory
pkill -f "out/test-cpp/TestServer" 2>/dev/null || true
# Also kill any lingering Main processes from our project
pkill -f "out/cpp/Main" 2>/dev/null || true
pkill -f "out/nodejs/server.js" 2>/dev/null || true
sleep 1
