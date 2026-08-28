#!/bin/bash
# NEXUS - Complete QEMU Environment Setup
# Run this in WSL2 Ubuntu

set -e

echo "[*] NEXUS QEMU Environment Setup"
echo ""

# Install QEMU
echo "[+] Installing QEMU..."
sudo apt update
sudo apt install -y qemu-system-x86 wget debootstrap

# Create rootfs directory
cd "$(dirname "$0")"
mkdir -p rootfs
cd rootfs

# Create minimal Debian rootfs
if [ ! -f "rootfs.img" ]; then
    echo "[+] Creating minimal rootfs (this takes ~5 minutes)..."

    # Create empty disk image
    qemu-img create -f raw rootfs.img 2G

    # Format as ext4
    mkfs.ext4 -F rootfs.img

    # Mount and install base system
    mkdir -p mnt
    sudo mount -o loop rootfs.img mnt

    echo "[+] Installing Debian base system..."
    sudo debootstrap --arch=amd64 bullseye mnt http://deb.debian.org/debian

    # Basic system setup
    sudo chroot mnt /bin/bash -c "
        echo 'root:root' | chpasswd
        echo 'nexus-test' > /etc/hostname

        # Install essential tools
        apt update
        apt install -y build-essential libmnl-dev libnftnl-dev iproute2 vim gdb

        # Auto-login on serial console
        mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
        cat > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
EOF
    "

    sudo umount mnt
    rmdir mnt

    echo "[+] Rootfs created: $(pwd)/rootfs.img"
else
    echo "[*] Rootfs already exists"
fi

echo ""
echo "[+] Setup complete!"
echo ""
echo "To boot the kernel:"
echo "  cd /mnt/c/Users/akank/Downloads/NEXUS/env"
echo "  ./run_qemu.sh"
