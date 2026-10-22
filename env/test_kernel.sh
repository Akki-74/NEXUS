#!/bin/bash
# NEXUS - Test kernel boot (no rootfs needed)
# Usage: ./test_kernel.sh [kernel_path]

cd "$(dirname "$0")"

KERNEL="${1:-kernel/bzImage-baseline}"
if [ ! -f "$KERNEL" ] && [ -f "kernel/linux-5.15.40/arch/x86/boot/bzImage" ]; then
    KERNEL="kernel/linux-5.15.40/arch/x86/boot/bzImage"
fi

if [ ! -f "$KERNEL" ]; then
    echo "Error: Kernel not found at $KERNEL"
    exit 1
fi

MEM="512M"
if [[ "$KERNEL" =~ "kasan" ]]; then
    MEM="2G"
fi

echo "[*] Testing kernel boot (no rootfs)..."
echo "[*] Kernel: $KERNEL (Memory: $MEM)"
echo "Press Ctrl-A then X to exit QEMU"
echo ""

qemu-system-x86_64 \
    -kernel "$KERNEL" \
    -append "console=ttyS0 debug" \
    -nographic \
    -m "$MEM"
