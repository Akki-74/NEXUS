#!/bin/bash
# NEXUS - Quick QEMU + Rootfs Setup Script
# Creates minimal BusyBox-based rootfs for kernel testing

set -e

echo "[*] NEXUS QEMU Environment Setup"

# Check if QEMU is installed
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "[+] Installing QEMU..."
    sudo apt update
    sudo apt install -y qemu-system-x86
else
    echo "[*] QEMU already installed"
fi

# Create rootfs directory
ROOTFS_DIR="$(pwd)/minimal-rootfs"
mkdir -p "${ROOTFS_DIR}"

cd "${ROOTFS_DIR}"

# Download pre-built BusyBox rootfs (fastest option)
if [ ! -f "rootfs.ext2" ]; then
    echo "[+] Downloading minimal BusyBox rootfs..."
    wget -q --show-progress https://github.com/google/syzkaller/raw/master/tools/create-image.sh
    chmod +x create-image.sh
    ./create-image.sh -d buster -s 2048

    echo "[+] Rootfs created: ${ROOTFS_DIR}/rootfs.ext2"
else
    echo "[*] Rootfs already exists"
fi

echo "[+] Setup complete!"
echo ""
echo "To boot kernel:"
echo "  cd $(dirname $(pwd))"
echo "  ./run_qemu.sh"
