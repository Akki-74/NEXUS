#!/bin/bash
# NEXUS Patched Kernel Build Script
# Builds Linux 5.15.40 with upstream fix for CVE-2022-32250 applied
#
# Purpose: Serves as the baseline patched kernel to verify that the upstream point-fix
#          prevents CVE-2022-32250.
#
# Usage: cd env/kernel && ./build_patched.sh
# Output: bzImage-patched

set -e

KERNEL_DIR="linux-5.15.40"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_FIX="${SCRIPT_DIR}/../../patches/apply_cve_fix.py"
TARGET_FILE="${SCRIPT_DIR}/${KERNEL_DIR}/net/netfilter/nf_tables_api.c"

echo "[*] NEXUS Patched Kernel Builder"
echo "[*] Target: Linux 5.15.40 + CVE-2022-32250 Upstream Patch"
echo ""

# Verify kernel source exists
if [ ! -d "${KERNEL_DIR}" ]; then
    echo "[-] Kernel source not found at ${KERNEL_DIR}"
    echo "[-] Run build_baseline.sh first to clone the kernel source."
    exit 1
fi

echo "[+] Applying CVE-2022-32250 fix to nf_tables_api.c..."
python3 "${PYTHON_FIX}" "${TARGET_FILE}"

cd "${KERNEL_DIR}"

# Verify config
if [ -f "${SCRIPT_DIR}/nexus_baseline.config" ]; then
    cp "${SCRIPT_DIR}/nexus_baseline.config" .config
    make olddefconfig
fi

# Build kernel
echo "[+] Building patched kernel..."
make -j$(nproc) bzImage

# Check result
if [ -f "arch/x86/boot/bzImage" ]; then
    SIZE=$(du -h arch/x86/boot/bzImage | cut -f1)
    echo ""
    echo "[+] Patched build successful!"
    echo "[+] Kernel image size: ${SIZE}"
    cp arch/x86/boot/bzImage "${SCRIPT_DIR}/bzImage-patched"
    echo "[+] Copied to: ${SCRIPT_DIR}/bzImage-patched"
    
    echo "[+] Reverting patch in source tree to keep clean state..."
    python3 "${PYTHON_FIX}" "${TARGET_FILE}" --reverse
else
    echo "[-] Build failed!"
    python3 "${PYTHON_FIX}" "${TARGET_FILE}" --reverse
    exit 1
fi
