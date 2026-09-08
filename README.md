# NEXUS 🔬

**Kernel Vulnerability Research & Analysis Platform**

A structured research environment for studying Linux kernel memory safety vulnerabilities, with a focus on object lifetime failures in the `netfilter/nf_tables` subsystem.

> **⚠️ Disclaimer**: This project is strictly for **educational and academic research purposes only**. All work is conducted in isolated QEMU virtual machines. No code in this repository targets production systems.

---

## 📋 Project Overview

NEXUS provides a reproducible lab environment for analyzing **CVE-2022-32250** — a Use-After-Free (UAF) vulnerability in the Linux kernel's `nf_tables` netfilter subsystem.

| Property | Detail |
|:---|:---|
| **Target CVE** | [CVE-2022-32250](https://nvd.nist.gov/vuln/detail/CVE-2022-32250) |
| **Subsystem** | `netfilter` / `nf_tables` (`net/netfilter/nf_tables_api.c`) |
| **Bug Class** | Object Lifetime Failure / Use-After-Free (SLUB) |
| **Baseline Kernel** | Upstream Linux `v5.15.40` (unpatched) |
| **Upstream Fix** | Commit [`f36736fbd484`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=f36736fbd48491a8d85cd22f4740d542c5a1546e) |
| **Virtualization** | QEMU `x86_64` (no KVM) on WSL2 Ubuntu |

### Vulnerability Summary

The bug resides in `nft_set_elem_expr_alloc()`, which calls `nft_expr_init()` to allocate and initialize a set element expression **before** validating the `NFT_EXPR_STATEFUL` flag. When a non-stateful expression (e.g., lookup) is passed, `init()` binds the expression to internal set data structures. The subsequent validation failure frees the expression via `kfree()` without unbinding, leaving a dangling pointer in `set->binding` — a classic Use-After-Free.

The upstream fix moves the `NFT_EXPR_STATEFUL` check into `nft_expr_init()` **before** allocation and initialization, ensuring non-stateful expressions are rejected cleanly with `-EOPNOTSUPP`.

---

## 🏗️ Repository Structure

```
NEXUS/
├── README.md                        # This file
├── .gitignore                       # Excludes kernel source trees, build artifacts, binaries
│
├── docs/                            # Research documentation
│   └── CVE-2022-32250-deep-dive.md  # Phase 1: Vulnerability anatomy & source analysis
│
├── env/                             # Lab environment setup
│   ├── kernel/                      # Kernel build infrastructure
│   │   ├── nexus_baseline.config    # Minimal x86_64 config with netfilter & namespaces
│   │   ├── nexus_kasan.config       # KASAN + SLUB_DEBUG overlay config
│   │   ├── build_baseline.sh        # Builds bzImage-baseline (unpatched)
│   │   ├── build_kasan.sh           # Builds bzImage-kasan (with memory sanitizer)
│   │   ├── build_patched.sh         # Builds bzImage-patched (with upstream fix applied)
│   │   └── linux-5.15.40/           # Kernel source tree (git-ignored, cloned at setup)
│   │
│   ├── rootfs/                      # Root filesystem artifacts (git-ignored)
│   ├── build_initramfs.sh           # BusyBox initramfs builder script
│   ├── run_qemu.sh                  # QEMU launch script (serial console, no KVM)
│   ├── test_kernel.sh               # Quick kernel boot test
│   ├── test_namespaces.sh           # Verify user/net namespace support in guest
│   ├── setup_qemu.sh               # QEMU installation helper
│   └── setup_qemu_env.sh           # Full environment setup helper
│
├── patches/                         # Kernel patches
│   ├── 0001-fix-cve-2022-32250-upstream.patch  # Unified diff of the upstream fix
│   └── apply_cve_fix.py             # Python helper to apply/revert the fix on source
│
├── exploit/                         # Exploit development (WIP)
│   ├── common/                      # Shared libraries (namespace setup, netlink helpers)
│   └── cve_2022_32250/              # CVE-specific trigger & analysis code
│
├── bench/                           # Benchmarking scripts (planned)
│
└── results/                         # Output artifacts
    ├── benchmarks/                  # Performance comparison data (planned)
    └── traces/                      # KASAN traces, dmesg logs (planned)
```

---

## 🔧 Environment & Prerequisites

| Requirement | Version / Notes |
|:---|:---|
| **Host OS** | Windows 10/11 with WSL2 |
| **WSL Distro** | Ubuntu 22.04 |
| **QEMU** | `qemu-system-x86_64` (installed via `apt`) |
| **Toolchain** | `gcc`, `make`, `flex`, `bison`, `libelf-dev`, `libssl-dev` |
| **BusyBox** | Static binary for initramfs (downloaded by `build_initramfs.sh`) |
| **Python 3** | For `apply_cve_fix.py` patch helper |

> **Note**: The project directory lives on the Windows filesystem (`/mnt/c/...` in WSL2). Kernel compilation on `/mnt/c` is slower than on the ext4 filesystem — this is a known WSL2 limitation. No KVM acceleration is available in default WSL2.

---

## 🚀 Quick Start

### 1. Clone & Enter

```bash
git clone https://github.com/<your-username>/NEXUS.git
cd NEXUS
```

### 2. Download Kernel Source

```bash
cd env/kernel
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.40.tar.xz
tar -xf linux-5.15.40.tar.xz
rm linux-5.15.40.tar.xz
```

### 3. Build Kernel Images

```bash
# Baseline (unpatched, vulnerable)
bash build_baseline.sh

# KASAN-enabled (memory sanitizer for UAF detection)
bash build_kasan.sh

# Patched (upstream fix applied)
bash build_patched.sh
```

### 4. Build Initramfs

```bash
cd ../..
bash env/build_initramfs.sh
```

### 5. Boot in QEMU

```bash
# Boot baseline kernel
bash env/run_qemu.sh

# Boot KASAN kernel (requires 2G RAM)
qemu-system-x86_64 \
  -kernel env/kernel/bzImage-kasan \
  -initrd env/rootfs/initramfs.cpio.gz \
  -append "console=ttyS0 nokaslr" \
  -nographic -m 2G -no-reboot
```

> **Exit QEMU**: Press `Ctrl-A` then `X`.

---

## 🧪 Kernel Build Matrix

| Image | Size | Config | Purpose |
|:---|:---|:---|:---|
| `bzImage-baseline` | ~3.7 MB | `nexus_baseline.config` | Unpatched vulnerable kernel for reproduction |
| `bzImage-kasan` | ~8.5 MB | `nexus_kasan.config` | Instrumented kernel with KASAN & SLUB_DEBUG for memory error detection |
| `bzImage-patched` | ~3.8 MB | Baseline + upstream fix | Kernel with commit `f36736fbd484` applied to verify the patch |

### Key Kernel Config Options

```
# Netfilter / nf_tables (attack surface)
CONFIG_NETFILTER=y
CONFIG_NF_TABLES=y
CONFIG_NF_TABLES_IPV4=y
CONFIG_NF_TABLES_IPV6=y

# Namespace support (unprivileged access path)
CONFIG_USER_NS=y
CONFIG_NET_NS=y

# KASAN (memory sanitizer — kasan build only)
CONFIG_KASAN=y
CONFIG_KASAN_GENERIC=y
CONFIG_SLUB_DEBUG=y
CONFIG_SLUB_DEBUG_ON=y

# Serial console (QEMU output)
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
```

---

## 📖 Documentation

| Document | Description |
|:---|:---|
| [`docs/CVE-2022-32250-deep-dive.md`](docs/CVE-2022-32250-deep-dive.md) | Full vulnerability anatomy: source locus, root cause analysis, call graph, upstream patch diff, and vulnerable-vs-patched comparison matrix |

---

## 🛡️ Guest Environment Verification

The following capabilities have been verified inside the QEMU guest:

| Capability | Status | Verification |
|:---|:---|:---|
| BusyBox shell boot | ✅ | Kernel boots to `/ #` prompt |
| User namespaces | ✅ | `unshare -U -n id` returns `uid=65534` |
| `nft_set_elem_expr` in kallsyms | ✅ | 3 matches found in `/proc/kallsyms` |
| Serial console | ✅ | Full `dmesg` + interactive shell via `-nographic` |

---

## 📊 Project Status

| Phase | Description | Status |
|:---|:---|:---|
| **Phase 0** | Repository structure & architecture | ✅ Complete |
| **Phase 1** | Vulnerability anatomy & source analysis | ✅ Complete |
| **Phase 2** | QEMU lab environment (kernel builds + initramfs + boot) | ✅ Complete |
| **Phase 3** | Exploit development & KASAN trace capture | 🔲 Planned |
| **Phase 4** | Patch verification & differential analysis | 🔲 Planned |
| **Phase 5** | Benchmarking & defense evaluation | 🔲 Planned |

---

## 📚 References

- [CVE-2022-32250 — NVD](https://nvd.nist.gov/vuln/detail/CVE-2022-32250)
- [Upstream Fix Commit `f36736fbd484`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=f36736fbd48491a8d85cd22f4740d542c5a1546e)
- [Linux Kernel Source — v5.15.40](https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.40.tar.xz)
- [KASAN Documentation](https://www.kernel.org/doc/html/latest/dev-tools/kasan.html)
- [Kernel Self-Protection Project (KSPP)](https://kspp.github.io/)

---

## 📝 License

This project is for educational and academic research purposes only.
