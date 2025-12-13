#!/bin/bash
# Helper script to encrypt secret and prepare for commit

set -e

echo "============================================================"
echo "FPGA Encryption - Encrypt and Prepare for Commit"
echo "============================================================"

# Check if build exists
if [ ! -f "build/encrypt_local" ]; then
    echo "Build not found. Building project first..."
    ./build.sh
fi

# Check if secret.txt exists
if [ ! -f "piApp/secret.txt" ]; then
    echo "ERROR: piApp/secret.txt not found!"
    echo "Please create piApp/secret.txt with your secret message."
    exit 1
fi

# Run encryption
echo ""
echo "Running encryption..."
./build/encrypt_local

# Check if encrypted.txt was created
if [ ! -f "piApp/encrypted.txt" ]; then
    echo "ERROR: Encryption failed - encrypted.txt not created"
    exit 1
fi

echo ""
echo "============================================================"
echo "✓ Encryption complete!"
echo ""
echo "Next steps:"
echo "  1. Review piApp/encrypted.txt"
echo "  2. Commit and push:"
echo "     git add piApp/encrypted.txt"
echo "     git commit -m 'Update encrypted firmware'"
echo "     git push"
echo ""
echo "⚠️  DO NOT commit piApp/secret.txt (it's in .gitignore)"
echo "============================================================"
