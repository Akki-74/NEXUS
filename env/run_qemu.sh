#!/bin/bash
# NEXUS - QEMU Launch Script
# Boots a NEXUS kernel with BusyBox initramfs
# Usage: ./run_qemu.sh [kernel_path]

cd "$(dirname "$0")"

KERNEL="${1:-kernel/bzImage-baseline}"
if [ ! -f "$KERNEL" ] && [ -f "kernel/linux-5.15.40/arch/x86/boot/bzImage" ]; then
    KERNEL="kernel/linux-5.15.40/arch/x86/boot/bzImage"
fi

INITRD="rootfs/initramfs.cpio.gz"

if [ ! -f "$KERNEL" ]; then
    echo "Error: Kernel not found at $KERNEL"
    echo "Usage: ./run_qemu.sh [kernel/bzImage-baseline | kernel/bzImage-kasan | kernel/bzImage-patched]"
    exit 1
fi

if [ ! -f "$INITRD" ]; then
    echo "Error: Initramfs not found at $INITRD"
    echo "Run ./build_initramfs.sh first"
    exit 1
fi

# KASAN kernels require >= 2GB memory to prevent OOM panic
MEM="512M"
if [[ "$KERNEL" =~ "kasan" ]]; then
    MEM="2G"
fi

echo "[*] Booting NEXUS kernel..."
echo "[*] Kernel: $KERNEL"
echo "[*] Memory: $MEM"
echo "[*] Initramfs: $INITRD"
echo ""
echo "Press Ctrl-A then X to exit QEMU"
echo ""

qemu-system-x86_64 \
    -kernel "$KERNEL" \
    -initrd "$INITRD" \
    -append "console=ttyS0 nokaslr panic=1" \
    -nographic \
    -m "$MEM" \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0
