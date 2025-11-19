#!/bin/bash

echo "=== Building Test Suite ==="

./kill-test-servers.sh

# Build test runner
echo "Building test runner..."
haxe test-runner.hxml || exit 1

# Build test servers
echo "Building PHP test server..."
haxe test-php.hxml || exit 1

echo "Building Node.js test server..."
haxe test-nodejs.hxml || exit 1

echo "Building C++ test server..."
haxe test-cpp.hxml || exit 1

echo ""
echo "=== Running Test Suite ==="
echo ""

# Test results tracking
FAILED=0

# Test PHP backend
echo "Starting PHP test server on port 8000..."
cd out/test-php
php -S localhost:8000 index.php > /dev/null 2>&1 &
PHP_PID=$!
cd ../..
sleep 2

echo "Running tests on PHP backend..."
pwd
node out/test-runner.js php 8000
if [ $? -ne 0 ]; then
    FAILED=1
fi
kill $PHP_PID 2>/dev/null || true
echo ""

# Test Node.js backend
echo "Starting Node.js test server on port 3000..."
cd out/test-nodejs
node test-server.js > /dev/null 2>&1 &
NODE_PID=$!
cd ../..
sleep 2

echo "Running tests on Node.js backend..."
node out/test-runner.js nodejs 3000
if [ $? -ne 0 ]; then
    FAILED=1
fi
kill $NODE_PID 2>/dev/null || true
echo ""

# Test C++ backend
echo "Starting C++ test server on port 8080..."
cd out/test-cpp
./TestServer > /dev/null 2>&1 &
CPP_PID=$!
cd ../..
sleep 2

echo "Running tests on C++ backend..."
node out/test-runner.js cpp 8080
if [ $? -ne 0 ]; then
    FAILED=1
fi
kill $CPP_PID 2>/dev/null || true
echo ""

# Final report
echo "================================"
if [ $FAILED -eq 0 ]; then
    echo "ALL TESTS PASSED!"
    echo "================================"
    exit 0
else
    echo "SOME TESTS FAILED!"
    echo "================================"
    exit 1
fi