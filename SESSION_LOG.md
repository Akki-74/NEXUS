# NEXUS Project - Session Log

**Project Goal**: Educational kernel exploitation learning focused on CVE-2022-32250

**Session Started**: 2026-08-28

---

## Project Overview

### Target Vulnerability
- **CVE**: CVE-2022-32250
- **Subsystem**: netfilter/nf_tables
- **Type**: Use-after-free (UAF) in SLUB allocator
- **Attack Vector**: Unprivileged user+network namespace privilege escalation

### Kernel Versions Plan
1. **Baseline (Vulnerable)**: Linux v5.15.40 unpatched - Primary learning target
2. **KASAN-enabled**: v5.15.40 + memory debugging for tracing
3. **Patched**: v5.15.40 + upstream fix commit `520778042de0`

---

## Session 1: 2026-08-28

### Progress
- ✅ Project structure created
- ✅ Implementation plan reviewed
- ✅ Session tracking initialized
- ✅ Kernel cloned: Linux v5.15.40 (stable tree)
- ✅ Baseline kernel config created
- ✅ **Kernel built successfully!** (`bzImage` 3.7MB)

### Build Details
- **Environment**: WSL2 Ubuntu
- **Kernel**: Linux 5.15.40 (vulnerable baseline)
- **Output**: `env/kernel/linux-5.15.40/arch/x86/boot/bzImage`

---

## Session 2: 2026-08-29

### Current Focus
Task #2 - QEMU Environment + Rootfs

### Progress
- ✅ QEMU installed in WSL2 (`qemu-system-x86`)
- ✅ `run_qemu.sh` - QEMU launch script created
- ✅ `test_kernel.sh` - bare kernel boot test script created
- ✅ **Debugged blank screen issue**: serial console support was missing
  - Added `CONFIG_SERIAL_8250=y`, `CONFIG_SERIAL_8250_CONSOLE=y` to config
  - **Kernel now boots successfully** - full boot log verified
- ✅ **Confirmed kernel boots**: reached "Kernel panic - VFS: Unable to mount root fs" (expected - no rootfs attached)
- ✅ `build_initramfs.sh` - BusyBox initramfs builder created
- ✅ `setup_minimal_rootfs.sh` - alt rootfs approach created

### CURRENT ISSUE (unresolved)
- **Reboot loop when booting with initramfs**
- Root cause identified: `CONFIG_BLK_DEV_INITRD` not set in kernel config
- Kernel panics → reboots in 1s (panic=1) → loops forever
- Fix: added `CONFIG_BLK_DEV_INITRD=y`, `CONFIG_RD_GZIP=y`, `CONFIG_DEVTMPFS=y` to config
- **Status: rebuild needed** - run `make olddefconfig && make -j$(nproc) bzImage` in WSL2

### Config Changes Made (Session 2)
| Option | Before | After | Why |
|--------|--------|-------|-----|
| `CONFIG_SERIAL_8250` | not set | `=y` | Blank screen fix - serial console output |
| `CONFIG_SERIAL_8250_CONSOLE` | not set | `=y` | console=ttyS0 support |
| `CONFIG_BLK_DEV_INITRD` | not set | `=y` | Initramfs boot support |
| `CONFIG_RD_GZIP` | not set | `=y` | Decompress gzipped initramfs |
| `CONFIG_DEVTMPFS` | not set | `=y` | Populate /dev |

### Files Created This Session
- `env/setup_qemu_env.sh` - Full Debian rootfs builder (superseded by initramfs)
- `env/setup_minimal_rootfs.sh` - BusyBox ext4 rootfs builder
- `env/build_initramfs.sh` - BusyBox initramfs builder (current approach)
- `env/run_qemu.sh` - QEMU launch script (updated for initramfs)
- `env/test_kernel.sh` - Bare kernel boot test (no rootfs)

---

## NEXT SESSION - Resume Here

### Action Items
1. **Rebuild kernel with fixed config** (in WSL2):
   ```bash
   cd /mnt/c/Users/akank/Downloads/NEXUS/env/kernel/linux-5.15.40
   cp ../nexus_baseline.config .config
   make olddefconfig
   grep CONFIG_BLK_DEV_INITRD .config  # verify =y
   make -j$(nproc) bzImage
   ```
2. **Build initramfs** (in WSL2):
   ```bash
   cd /mnt/c/Users/akank/Downloads/NEXUS/env
   ./build_initramfs.sh
   ```
3. **Boot**:
   ```bash
   ./run_qemu.sh
   ```
4. **Expected result**: BusyBox root shell (`/ #`) prompt

### Once Booting Works
- [ ] Task #3: Build KASAN-enabled kernel for debugging
- [ ] Task #4: Build patched kernel with upstream fix
- [ ] Start exploit development (namespace setup, netlink trigger)

---

## Notes
- **IMPORTANT**: Kernel builds run in WSL2, NOT Windows Git Bash (make not available in Git Bash)
- QEMU has no KVM in default WSL2 - removed `-enable-kvm` from scripts
- Kernel build config lives at `env/kernel/nexus_baseline.config`
- Boot approach: `-kernel bzImage + -initrd initramfs.cpio.gz` (simpler than drive image)
- Educational focus - understanding CVE-2022-32250 fundamentals
