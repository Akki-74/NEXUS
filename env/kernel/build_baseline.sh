#!/bin/bash
# NEXUS Baseline Kernel Build Script
# Builds vulnerable Linux 5.15.40 kernel

set -e

KERNEL_VERSION="v5.15.40"
KERNEL_DIR="linux-5.15.40"
KERNEL_REPO="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"

echo "[*] NEXUS Baseline Kernel Builder"
echo "[*] Target: ${KERNEL_VERSION}"

# Clone kernel if not already present
if [ ! -d "${KERNEL_DIR}" ]; then
    echo "[+] Cloning Linux kernel ${KERNEL_VERSION}..."
    git clone --depth=1 --branch ${KERNEL_VERSION} ${KERNEL_REPO} ${KERNEL_DIR}
else
    echo "[*] Kernel source already exists at ${KERNEL_DIR}"
fi

cd ${KERNEL_DIR}

# Copy our config if it exists, otherwise use defconfig
if [ -f "../nexus_baseline.config" ]; then
    echo "[+] Using NEXUS baseline configuration..."
    cp ../nexus_baseline.config .config
else
    echo "[+] Using defconfig as baseline..."
    make defconfig
fi

# Build kernel
echo "[+] Building kernel (this will take a while)..."
make -j$(nproc) bzImage

# Check if build succeeded
if [ -f "arch/x86/boot/bzImage" ]; then
    echo "[+] Build successful!"
    echo "[+] Kernel image: $(pwd)/arch/x86/boot/bzImage"
    cp arch/x86/boot/bzImage ../bzImage-baseline
    echo "[+] Copied to: ../bzImage-baseline"
else
    echo "[-] Build failed!"
    exit 1
fi
