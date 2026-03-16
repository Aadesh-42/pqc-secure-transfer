#!/usr/bin/env bash
# Exit on error
set -o errexit

echo "Installing OS dependencies for liboqs..."
# Render uses Ubuntu/Debian based images
apt-get update && apt-get install -y cmake gcc libssl-dev git ninja-build

echo "Cloning liboqs..."
git clone -b main https://github.com/open-quantum-safe/liboqs.git
cd liboqs

echo "Building liboqs..."
mkdir build && cd build
cmake -GNinja -DOQS_USE_OPENSSL=ON -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=/usr/local ..
ninja
ninja install

echo "liboqs installed successfully!"

cd ../..
echo "Installing Python dependencies..."
pip install -r requirements.txt
