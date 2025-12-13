#!/bin/bash
# Build script for FPGA Encryption C++ project

set -e

echo "============================================================"
echo "Building FPGA Encryption C++ Project"
echo "============================================================"

# Check for dependencies
echo "Checking dependencies..."
command -v cmake >/dev/null 2>&1 || { echo "ERROR: cmake not found. Install with: sudo apt-get install cmake"; exit 1; }
command -v g++ >/dev/null 2>&1 || { echo "ERROR: g++ not found. Install with: sudo apt-get install g++"; exit 1; }

# Check for OpenSSL
if ! pkg-config --exists openssl 2>/dev/null; then
    echo "WARNING: OpenSSL development files not found."
    echo "Install with: sudo apt-get install libssl-dev"
    echo "Continuing anyway..."
fi

# Create build directory
echo "Creating build directory..."
mkdir -p build
cd build

# Configure
echo "Configuring with CMake..."
cmake ..

# Build
echo "Building..."
make -j$(nproc 2>/dev/null || echo 2)

echo "============================================================"
echo "✓ Build complete!"
echo "Binaries:"
echo "  - ./build/encrypt_local (local encryption tool)"
echo "  - ./build/fpga_sender (Raspberry Pi sender)"
echo ""
echo "Next steps:"
echo "  1. Edit piApp/secret.txt"
echo "  2. Run: ./build/encrypt_local"
echo "  3. Commit and push piApp/encrypted.txt"
echo "============================================================"
