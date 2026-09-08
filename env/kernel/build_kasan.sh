#!/bin/bash
# NEXUS KASAN Kernel Build Script
# Builds Linux 5.15.40 with KASAN enabled for UAF detection
#
# Purpose: When CVE-2022-32250 is triggered, KASAN will report:
#   BUG: KASAN: slab-use-after-free in nft_set_elem_expr_alloc+0x.../0x...
#   With full allocation and free stack traces.
#
# Usage: cd env/kernel && ./build_kasan.sh
# Output: bzImage-kasan

set -e

KERNEL_DIR="linux-5.15.40"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[*] NEXUS KASAN Kernel Builder"
echo "[*] Target: Linux 5.15.40 + KASAN memory sanitizer"
echo ""

# Verify kernel source exists
if [ ! -d "${KERNEL_DIR}" ]; then
    echo "[-] Kernel source not found at ${KERNEL_DIR}"
    echo "[-] Run build_baseline.sh first to clone the kernel source."
    exit 1
fi

cd "${KERNEL_DIR}"

# Back up current .config if it exists
if [ -f ".config" ]; then
    cp .config .config.backup
    echo "[*] Backed up existing .config to .config.backup"
fi

# Merge baseline + KASAN configs
echo "[+] Merging baseline config with KASAN overlay..."
if [ -f "scripts/kconfig/merge_config.sh" ]; then
    ./scripts/kconfig/merge_config.sh -m \
        "${SCRIPT_DIR}/nexus_baseline.config" \
        "${SCRIPT_DIR}/nexus_kasan.config"
else
    # Fallback: copy baseline and append KASAN options
    cp "${SCRIPT_DIR}/nexus_baseline.config" .config
    cat "${SCRIPT_DIR}/nexus_kasan.config" >> .config
fi

# Resolve any dependency issues
make olddefconfig

# Verify critical KASAN options are enabled
echo ""
echo "[*] Verifying KASAN configuration..."
KASAN_ENABLED=$(grep -c "CONFIG_KASAN=y" .config || true)
SLUB_DEBUG=$(grep -c "CONFIG_SLUB_DEBUG=y" .config || true)

if [ "$KASAN_ENABLED" -lt 1 ]; then
    echo "[-] ERROR: CONFIG_KASAN=y not found in .config!"
    echo "[-] KASAN may require CONFIG_SLUB=y (not SLAB). Check kernel config."
    exit 1
fi

echo "[+] CONFIG_KASAN=y         : confirmed"
echo "[+] CONFIG_SLUB_DEBUG=y    : $([ "$SLUB_DEBUG" -ge 1 ] && echo 'confirmed' || echo 'MISSING')"
echo ""

# Build kernel
echo "[+] Building KASAN kernel (this will take longer than baseline)..."
make -j$(nproc) bzImage

# Check result
if [ -f "arch/x86/boot/bzImage" ]; then
    KASAN_SIZE=$(du -h arch/x86/boot/bzImage | cut -f1)
    echo ""
    echo "[+] KASAN build successful!"
    echo "[+] Kernel image: ${KASAN_SIZE} (larger than baseline due to KASAN instrumentation)"
    cp arch/x86/boot/bzImage "${SCRIPT_DIR}/bzImage-kasan"
    echo "[+] Copied to: ${SCRIPT_DIR}/bzImage-kasan"
    echo ""
    echo "[*] Boot with:"
    echo "    qemu-system-x86_64 -kernel bzImage-kasan -initrd ../rootfs/initramfs.cpio.gz \\"
    echo "        -append 'console=ttyS0 nokaslr panic=1 rdinit=/init' \\"
    echo "        -nographic -m 2G"
    echo ""
    echo "[!] NOTE: Use -m 2G or more. KASAN doubles memory usage."
else
    echo "[-] Build failed!"
    exit 1
fi
