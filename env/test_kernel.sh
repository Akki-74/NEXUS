#!/bin/bash
# NEXUS - Test kernel boot (no rootfs needed)
# Just boots kernel with initramfs built-in

KERNEL="kernel/linux-5.15.40/arch/x86/boot/bzImage"

if [ ! -f "$KERNEL" ]; then
    echo "Error: Kernel not found at $KERNEL"
    exit 1
fi

echo "[*] Testing kernel boot (no rootfs)..."
echo "Press Ctrl-A then X to exit QEMU"
echo ""

qemu-system-x86_64 \
    -kernel "$KERNEL" \
    -append "console=ttyS0 debug" \
    -nographic \
    -m 512M
