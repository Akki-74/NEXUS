#!/bin/bash
# NEXUS - Quick Minimal Rootfs Setup
# Creates a tiny BusyBox-based rootfs (boots in ~5 seconds)

set -e

cd "$(dirname "$0")"
mkdir -p rootfs
cd rootfs

echo "[*] Creating minimal BusyBox rootfs..."

if [ ! -f "rootfs.img" ]; then
    # Create 512MB image
    dd if=/dev/zero of=rootfs.img bs=1M count=512
    mkfs.ext4 -F rootfs.img

    # Mount and populate
    mkdir -p mnt
    sudo mount -o loop rootfs.img mnt

    # Create basic directory structure
    sudo mkdir -p mnt/{bin,sbin,etc,proc,sys,dev,tmp,root,usr/bin,usr/sbin}

    # Download and extract static BusyBox
    echo "[+] Downloading BusyBox..."
    wget -q https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox -O busybox
    chmod +x busybox
    sudo mv busybox mnt/bin/

    # Create symlinks for common commands
    sudo chroot mnt /bin/busybox --install -s

    # Create init script
    sudo tee mnt/init > /dev/null << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

echo "NEXUS Kernel Test Environment"
echo "Linux 5.15.40 - CVE-2022-32250 Research"
echo ""

exec /bin/sh
EOF

    sudo chmod +x mnt/init

    # Create minimal /etc files
    echo "root:x:0:0:root:/root:/bin/sh" | sudo tee mnt/etc/passwd > /dev/null
    echo "root::0::::::" | sudo tee mnt/etc/shadow > /dev/null

    sudo umount mnt
    rmdir mnt

    echo "[+] Rootfs created: $(pwd)/rootfs.img (512MB)"
else
    echo "[*] Rootfs already exists"
fi

echo ""
echo "[+] Done! Boot with: ./run_qemu.sh"
