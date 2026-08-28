# NEXUS Complete Setup Guide

## Project Overview
**Goal**: Educational kernel exploitation - understanding CVE-2022-32250 (netfilter UAF)

**Environment**: WSL2 Ubuntu on Windows  
**Target Kernel**: Linux 5.15.40 (vulnerable baseline)

---

## ✅ Completed Setup

### 1. Baseline Kernel - DONE
- **Location**: `env/kernel/linux-5.15.40/`
- **Built**: ✅ `arch/x86/boot/bzImage` (3.7MB)
- **Config**: `env/kernel/nexus_baseline.config`
- **Version**: v5.15.40 (stable tree)

---

## 🔄 Next Steps

### 2. QEMU + Rootfs Setup

**Install QEMU (in WSL2):**
```bash
sudo apt update
sudo apt install -y qemu-system-x86
```

**Create Minimal Rootfs:**
```bash
cd env/rootfs
wget https://github.com/google/syzkaller/raw/master/tools/create-image.sh
chmod +x create-image.sh
./create-image.sh -d buster -s 2048
```

**Quick Boot Test:**
```bash
cd env/kernel/linux-5.15.40
qemu-system-x86_64 \
    -kernel arch/x86/boot/bzImage \
    -append "console=ttyS0 root=/dev/sda nokaslr" \
    -hda ../../rootfs/rootfs.ext2 \
    -nographic -m 2G
```

### 3. Build KASAN Kernel (For Debugging)
```bash
cd env/kernel/linux-5.15.40
cp .config .config.baseline
make menuconfig
# Enable: CONFIG_KASAN=y, CONFIG_SLUB_DEBUG=y
make -j$(nproc) bzImage
cp arch/x86/boot/bzImage ../bzImage-kasan
```

### 4. Build Patched Kernel (With Fix)
```bash
cd env/kernel/linux-5.15.40
git fetch origin 520778042de0
git cherry-pick 520778042de0
make -j$(nproc) bzImage
cp arch/x86/boot/bzImage ../bzImage-patched
```

---

## 🎯 Planned Kernel Builds

| Build | Status | Purpose | Output |
|-------|--------|---------|--------|
| **Baseline** | ✅ Done | Vulnerable - trigger CVE | `bzImage-baseline` |
| **KASAN** | ⏳ Pending | Debug memory corruption | `bzImage-kasan` |
| **Patched** | ⏳ Pending | Verify upstream fix | `bzImage-patched` |

---

## 📁 Project Structure

```
NEXUS/
├── env/
│   ├── kernel/
│   │   ├── linux-5.15.40/          ✅ Cloned & built
│   │   ├── nexus_baseline.config   ✅ Created
│   │   └── bzImage-baseline         (will copy here)
│   ├── rootfs/                      ⏳ Next step
│   └── run_qemu.sh                  ⏳ To create
├── exploit/
│   ├── common/                      (namespace, netlink, heap)
│   └── cve_2022_32250/              (trigger, exploit)
├── patches/                         (upstream fix, hardening)
└── SESSION_LOG.md                   ✅ Tracking progress
```

---

## 🚀 Quick Commands Reference

**Build baseline kernel:**
```bash
cd env/kernel/linux-5.15.40
cp ../nexus_baseline.config .config
make olddefconfig
make -j$(nproc) bzImage
```

**Boot in QEMU:**
```bash
qemu-system-x86_64 -kernel bzImage -append "console=ttyS0" -nographic
```

**Check kernel version:**
```bash
cd env/kernel/linux-5.15.40
git log --oneline -1
# Should show: ae766496dbd4 (v5.15.40)
```

---

## 📝 Current Session Status

- ✅ WSL2 environment confirmed
- ✅ Kernel source cloned (v5.15.40)
- ✅ Baseline kernel built successfully
- ⏳ QEMU + rootfs setup in progress
- ⏳ Exploit development not started

**Next action**: Install QEMU and create rootfs
