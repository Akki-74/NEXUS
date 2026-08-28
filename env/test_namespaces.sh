#!/bin/bash
# NEXUS - Test kernel capabilities inside QEMU guest
# Sends commands to QEMU via stdin, captures output

KERNEL="kernel/linux-5.15.40/arch/x86/boot/bzImage"
INITRD="rootfs/initramfs.cpio.gz"

cd "$(dirname "$0")"

# Create a commands file to feed into QEMU
cat > /tmp/nexus_test_cmds.sh << 'CMDS'
sleep 2
echo "=== NEXUS CAPABILITY TEST ==="
echo "--- Kernel Version ---"
uname -r
echo "--- User Namespace Support ---"
cat /proc/sys/user/max_user_namespaces 2>/dev/null || echo "max_user_namespaces: not found"
grep CONFIG_USER_NS /proc/config.gz 2>/dev/null || echo "config check: not available (expected)"
echo "--- Attempting unshare --user --net ---"
unshare --user --net -- id 2>&1 || echo "unshare failed (busybox may not support --user)"
echo "--- Checking /proc/self/ns ---"
ls -la /proc/self/ns/ 2>/dev/null || echo "ns dir not found"
echo "--- Checking nf_tables ---"
cat /proc/net/nf_tables 2>/dev/null || echo "nf_tables proc not found (may need nft tool)"
ls /proc/net/ 2>/dev/null | grep -i nf || echo "no nf entries in /proc/net"
echo "=== TEST COMPLETE ==="
poweroff -f 2>/dev/null || reboot -f 2>/dev/null
CMDS

timeout 60 qemu-system-x86_64 \
    -kernel "$KERNEL" \
    -initrd "$INITRD" \
    -append "console=ttyS0 nokaslr panic=1 rdinit=/init" \
    -nographic \
    -m 512M \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 2>&1
