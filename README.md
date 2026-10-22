# NEXUS 🔬

[![Kernel: Linux 5.15 LTS](https://img.shields.io/badge/Kernel-Linux%20v5.15.40-blue.svg)](https://kernel.org)
[![Target: CVE-2022-32250](https://img.shields.io/badge/CVE-2022--32250-red.svg)](https://nvd.nist.gov/vuln/detail/CVE-2022-32250)
[![Environment: QEMU x86_64](https://img.shields.io/badge/Virtualization-QEMU%20x86__64-orange.svg)](https://www.qemu.org/)
[![Status: Research Complete](https://img.shields.io/badge/Research%20Status-Complete%20(Phases%200--5)-brightgreen.svg)]()
[![License: Educational](https://img.shields.io/badge/License-Educational%20Research-lightgrey.svg)]()

**NEXUS** is an end-to-end Linux kernel vulnerability research, reproduction, and defense evaluation platform. It focuses on **object lifetime failures** in the Netfilter (`nf_tables`) subsystem, utilizing **CVE-2022-32250** on upstream Linux v5.15.40 as the primary case study.

> **⚠️ Disclaimer**: This project is strictly for **educational, academic, and defensive security research**. All testing is performed in isolated, virtualized QEMU environments. No functional exploit payloads targeting production infrastructure are provided.

---

## 📋 Research Focus & Anatomy

| Property | Specification |
|:---|:---|
| **Target CVE** | [CVE-2022-32250](https://nvd.nist.gov/vuln/detail/CVE-2022-32250) |
| **Vulnerability Class** | Object Lifetime Inversion / SLUB Use-After-Free (UAF) |
| **Subsystem** | `net/netfilter/nf_tables_api.c` (`nft_set_elem_expr_alloc`) |
| **Affected Slabs** | `kmalloc-64` general-purpose cache |
| **Attack Vector** | Local unprivileged user namespaces (`CLONE_NEWUSER | CLONE_NEWNET`) |
| **Upstream Patch** | Commit [`f36736fbd484`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=f36736fbd48491a8d85cd22f4740d542c5a1546e) (Merged in Linux v5.18) |

### The Root Cause Flaw
In unpatched Linux 5.15.40:
1. `nft_set_elem_expr_alloc()` calls `nft_expr_init()` to allocate an expression in `kmalloc-64` and initialize it.
2. `expr->ops->init()` (e.g. `nft_lookup_init`) links `priv->binding` directly into the target set's binding list (`s_target->bindings`).
3. **The Inversion**: `nft_set_elem_expr_alloc()` checks whether the expression is stateful (`NFT_EXPR_STATEFUL`) **after** initialization.
4. When a non-stateful lookup expression is passed, the check fails and destroys the expression (`kfree`). However, `nft_expr_destroy()` **fails to unbind the set**, leaving a dangling pointer inside `s_target->bindings`.
5. On the next bind attempt or namespace teardown, the kernel dereferences the freed memory chunk, triggering an immediate Use-After-Free.

---

## 🔬 Empirical Findings & Differential Verification

The vulnerability was empirically verified in QEMU across both vulnerable and remediated kernel builds:

```
+----------------------------------------------------------------------------------------------------+
|                                    NEXUS Differential Matrix                                       |
+----------------------------+---------------------------------------+-------------------------------+
| Feature                    | Unpatched Kernel (bzImage-kasan)      | Patched Kernel (bzImage-patched)|
+----------------------------+---------------------------------------+-------------------------------+
| Validation Point           | Post-init (nft_set_elem_expr_alloc)   | Pre-alloc (nft_expr_init)     |
| SLUB Allocation            | 64 bytes in kmalloc-64 allocated/freed| None (rejected before kzalloc)|
| Target Set Bindings List   | Stale pointer to freed chunk          | Untouched / Pristine          |
| Injection Round 2          | BUG: KASAN: use-after-free (read 4B)  | Clean -EOPNOTSUPP rejection   |
| Namespace Teardown         | WARNING: LIST_POISON (dead000000000122) Clean DELTABLE               |
| Kernel Taint               | Tainted (G B)                         | Untainted (Pristine)          |
+----------------------------+---------------------------------------+-------------------------------+
```

### KASAN Splat Snippet (`bzImage-kasan`)
```text
==================================================================
BUG: KASAN: use-after-free in nf_tables_bind_set+0x69f/0x960
Read of size 4 at addr ffff888005fd2670 by task trigger/28

Allocated by task 28:
 nft_expr_init+0xb6/0x260
 nft_set_elem_expr_alloc+0x1b/0x1e0
 nft_add_set_elem+0x3bb/0x2c50
 nf_tables_newsetelem+0x541/0x9c0

Freed by task 28:
 kfree+0xb7/0x270
 nft_set_elem_expr_alloc+0x180/0x1e0
 nft_add_set_elem+0x3bb/0x2c50
 nf_tables_newsetelem+0x541/0x9c0

The buggy address belongs to the object at ffff888005fd2640
 which belongs to the cache kmalloc-64 of size 64
==================================================================
```
*(Full diagnostic log captured in [`results/traces/cve-2022-32250-kasan.log`](results/traces/cve-2022-32250-kasan.log))*

---

## 📊 Performance & Benchmark Metrics

Benchmarked using [`bench/bench_netlink.c`](bench/bench_netlink.c) (500 atomic transaction cycles / 1,000 Netfilter operations):

| Metric | `bzImage-baseline` | `bzImage-kasan` | `bzImage-patched` | Fix Overhead |
|:---|:---:|:---:|:---:|:---:|
| **Binary Size** | 3.79 MB | 8.43 MB *(+122.5%)* | 3.79 MB | **+0.00%** |
| **Minimum VM RAM** | 512 MB | 2,048 MB *(+300%)* | 512 MB | **0 MB** |
| **Netlink Latency (avg)** | 48.2 μs | 124.6 μs | 48.4 μs | **+0.41%** (within jitter) |
| **Throughput** | 20,746 ops/s | 8,025 ops/s | 20,661 ops/s | **-0.41%** |
| **Security State** | Vulnerable | Sanitized | **Remediated** | Clean rejection |

*(Detailed analysis available in [`results/benchmarks/benchmark_summary.md`](results/benchmarks/benchmark_summary.md))*

---

## 🏗️ Repository Architecture

```
NEXUS/
├── README.md                            # Executive overview, architecture & quickstart
├── .gitignore                           # Excludes large kernel sources, images, raw logs
│
├── docs/                                # Technical & research documentation
│   ├── CVE-2022-32250-deep-dive.md      # Phase 1: Vulnerability anatomy, call graphs & fix diff
│   ├── differential-analysis.md         # Phase 4: Comparative matrix, KASAN splats & list poisoning
│   └── defense-evaluation.md            # Phase 5: RANDOM_KMALLOC_CACHES, MTE & namespace defenses
│
├── env/                                 # Kernel & QEMU lab infrastructure
│   ├── kernel/                          # Kernel configurations & build automation
│   │   ├── nexus_baseline.config        # Baseline configuration (netfilter + namespaces)
│   │   ├── nexus_kasan.config           # Sanitizer overlay (CONFIG_KASAN + CONFIG_SLUB_DEBUG)
│   │   ├── build_baseline.sh            # Compiles unpatched vulnerable kernel
│   │   ├── build_kasan.sh               # Compiles KASAN-instrumented kernel
│   │   └── build_patched.sh             # Compiles kernel with upstream patch applied
│   ├── rootfs/                          # Generated initramfs images (git-ignored)
│   ├── build_initramfs.sh               # Bundles BusyBox, trigger, and benchmark tools
│   ├── run_qemu.sh                      # Universal runner (auto-scales RAM for KASAN)
│   └── test_kernel.sh                   # Rapid boot tester
│
├── patches/                             # Patch artifacts
│   ├── 0001-fix-cve-2022-32250-upstream.patch  # Official unified patch
│   └── apply_cve_fix.py                 # Idempotent apply/revert Python helper
│
├── exploit/                             # Test modules & vulnerability triggers
│   ├── common/                          # Reusable netlink & namespace helpers
│   │   ├── namespace_setup.c / .h       # unshare(CLONE_NEWUSER|CLONE_NEWNET) & UID mapping
│   │   └── netlink_helpers.c / .h       # Header-free Netlink / nf_tables batch serializer
│   ├── cve_2022_32250/
│   │   └── trigger.c                    # UAF reproduction driver
│   ├── Makefile                         # Static binary builder
│   └── build_exploit.sh                 # Exploit build script
│
├── bench/                               # Performance profiling suite
│   ├── bench_netlink.c                  # Transaction latency & throughput micro-benchmark
│   └── Makefile                         # Static benchmark builder
│
└── results/                             # Empirical artifacts
    ├── traces/
    │   └── cve-2022-32250-kasan.log     # Captured KASAN UAF & list poison dmesg splat
    └── benchmarks/
        ├── kernel_metrics.csv           # Raw performance metrics dataset
        └── benchmark_summary.md         # In-depth performance evaluation report
```

---

## 🚀 Quick Start Guide

### 1. Prerequisites (WSL2 / Ubuntu)
```bash
sudo apt update && sudo apt install -y qemu-system-x86 build-essential flex bison libelf-dev libssl-dev bc
```

### 2. Kernel Compilation
```bash
cd env/kernel

# 1. Download upstream Linux v5.15.40
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.40.tar.xz
tar -xf linux-5.15.40.tar.xz && rm linux-5.15.40.tar.xz

# 2. Build target kernels
bash build_baseline.sh   # Builds bzImage-baseline (~3.8 MB)
bash build_kasan.sh      # Builds bzImage-kasan (~8.5 MB, with memory sanitizer)
bash build_patched.sh    # Builds bzImage-patched (~3.8 MB, with upstream fix)
```

### 3. Build Userspace Tools & Initramfs
```bash
# Build exploit trigger and benchmark binaries
cd ../../exploit && bash build_exploit.sh
cd ../bench && make

# Bundle binaries into guest initramfs
cd ../env && bash build_initramfs.sh
```

### 4. Running the Lab

#### Test Vulnerability Reproduction (KASAN Kernel)
```bash
./run_qemu.sh kernel/bzImage-kasan
```
Inside the guest:
```sh
/ # trigger
/ # dmesg | grep -i kasan
```
*(Observe the `BUG: KASAN: use-after-free` report)*

#### Test Patch Remediation (Patched Kernel)
```bash
./run_qemu.sh kernel/bzImage-patched
```
Inside the guest:
```sh
/ # trigger
/ # dmesg | tail -n 20
```
*(Observe clean `-EOPNOTSUPP` rejection with zero KASAN reports or warnings)*

#### Run Performance Benchmark
Inside any guest instance:
```sh
/ # bench_netlink 500
```

> **Exit QEMU**: Press `Ctrl-A` then `X`.

---

## 🛡️ Mitigation & Defense Evaluation Highlights

Our comprehensive defense analysis ([`docs/defense-evaluation.md`](docs/defense-evaluation.md)) reviews modern mitigations against this bug class:

1. **`CONFIG_RANDOM_KMALLOC_CACHES` (Linux 6.6+)**:  
   Introduces 16 random buckets per `kmalloc` size, hashed by callsite. With a **~93.75% probability**, allocations from cross-type grooming primitives (`msg_msg`, `pipe_buffer`, `sk_buff`) land in different cache buckets, heavily mitigating heap manipulation.
2. **`CONFIG_SLAB_FREELIST_HARDENED`**:  
   Obfuscates free pointers via XOR-canaries. Detects freelist pointer hijacking and panics the kernel before arbitrary write primitives can be established.
3. **Dedicated Cache Segregation**:  
   Migrating `nft_expr` allocations from multi-tenant `kmalloc-64` into an isolated `kmem_cache_create("nft_expr", ...)` structurally eliminates cross-type object substitution.
4. **Namespace Access Gating**:  
   Restricting unprivileged user namespace creation via sysctl (`user.max_user_namespaces = 0`) or fine-grained LSM policies (Ubuntu 24.04 AppArmor 4.0 profiles) prevents unprivileged users from accessing Netlink interfaces.

---

## 📈 Project Status Matrix

| Milestone | Phase | Description | Status |
|:---:|:---|:---|:---:|
| 🎯 | **Phase 0** | Repository Architecture & Tooling Setup | ✅ Complete |
| 🔍 | **Phase 1** | Vulnerability Deep-Dive & Root-Cause Analysis | ✅ Complete |
| 💻 | **Phase 2** | QEMU Lab Bring-Up (3 Kernels + Initramfs) | ✅ Complete |
| 🛠️ | **Phase 3** | Exploit Trigger Modules & Static Linking | ✅ Complete |
| 📊 | **Phase 4** | Empirical Reproduction & Patch Verification | ✅ Complete |
| 🛡️ | **Phase 5** | Mitigation Analysis & Benchmarking Suite | ✅ Complete |

---

## 📚 References & Prior Work

* [CVE-2022-32250 — National Vulnerability Database (NVD)](https://nvd.nist.gov/vuln/detail/CVE-2022-32250)
* [Linux Kernel Git — Commit f36736fbd484 (Upstream Fix)](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=f36736fbd48491a8d85cd22f4740d542c5a1546e)
* [Kernel Address Sanitizer (KASAN) Documentation](https://www.kernel.org/doc/html/latest/dev-tools/kasan.html)
* [Kernel Self-Protection Project (KSPP)](https://kspp.github.io/)
* [Linux Kernel Source v5.15.40](https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.40.tar.xz)

---

## 📝 License

This project is licensed under the MIT License for educational and research purposes.
