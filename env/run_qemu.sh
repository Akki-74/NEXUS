#!/bin/bash
# NEXUS - QEMU Launch Script
# Boots the baseline vulnerable kernel with BusyBox initramfs

KERNEL="kernel/linux-5.15.40/arch/x86/boot/bzImage"
INITRD="rootfs/initramfs.cpio.gz"

if [ ! -f "$KERNEL" ]; then
    echo "Error: Kernel not found at $KERNEL"
    exit 1
fi

if [ ! -f "$INITRD" ]; then
    echo "Error: Initramfs not found at $INITRD"
    echo "Run ./build_initramfs.sh first"
    exit 1
fi

echo "[*] Booting NEXUS kernel..."
echo "[*] Kernel: $KERNEL"
echo "[*] Initramfs: $INITRD"
echo ""
echo "Press Ctrl-A then X to exit QEMU"
echo ""

qemu-system-x86_64 \
    -kernel "$KERNEL" \
    -initrd "$INITRD" \
    -append "console=ttyS0 nokaslr panic=1" \
    -nographic \
    -m 512M \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0
