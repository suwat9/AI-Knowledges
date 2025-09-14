#!/bin/bash
set -e

echo "=== Cleaning old npm configs ==="
npm config delete proxy || true
npm config delete https-proxy || true
npm config set registry https://registry.npmjs.org/

echo "=== Updating system packages ==="
sudo apt update && sudo apt upgrade -y

echo "=== Installing Node.js (LTS) & npm ==="
# Install Node.js 20.x (n8n works well with Node 18/20)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs build-essential

echo "=== Checking versions ==="
node -v
npm -v

echo "=== Preparing n8n project ==="
mkdir -p ~/n8n-project && cd ~/n8n-project
npm init -y

echo "=== Installing n8n locally ==="
npm install n8n

echo "=== Running n8n with npx ==="
npx n8n
