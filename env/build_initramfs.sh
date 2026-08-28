#!/bin/bash
# NEXUS - Build BusyBox initramfs
# Creates initramfs.cpio.gz for booting with -initrd

set -e

cd "$(dirname "$0")"
mkdir -p rootfs
cd rootfs

echo "[*] Building BusyBox initramfs..."

if [ ! -f "busybox" ]; then
    echo "[+] Downloading static BusyBox..."
    wget -q https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
fi
chmod +x busybox

# Build initramfs directory
rm -rf initramfs
mkdir -p initramfs/{bin,sbin,etc,proc,sys,dev,tmp,root}

# Install busybox + symlinks
cp busybox initramfs/bin/
cd initramfs
for cmd in sh ls cat mount umount uname echo dmesg id whoami touch mkdir mknod \
           chmod chown cp mv rm ps kill sleep date ifconfig ip grep sed awk wc \
           tar gzip hostname su setsid clear unshare nsenter \
           head tail hexdump dd xargs sort tr cut tee ln find which env \
           free top df du stat readlink basename dirname vi; do
    ln -sf busybox bin/$cmd
done

# Create init script
cat > init << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

echo "=============================================="
echo "  NEXUS Kernel Research Environment"
echo "  Linux 5.15.40 - CVE-2022-32250"
echo "=============================================="
echo ""

exec /bin/sh
EOF

chmod +x init

# Create basic /etc files
echo "root:x:0:0:root:/root:/bin/sh" > etc/passwd
echo "root::0::::::" > etc/shadow
echo "hostname" > etc/hostname

# Create devices (devtmpfs handles most, but ensure console)
mkdir -p dev

cd ..

# Package as cpio.gz
echo "[+] Packaging initramfs..."
cd initramfs
find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > ../initramfs.cpio.gz
cd ..

echo "[+] Done! Created: $(pwd)/initramfs.cpio.gz"
echo "[+] Boot with: ./run_qemu.sh"
