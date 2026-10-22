# NEXUS Project - Session Log

**Project Goal**: Educational kernel exploitation research focused on CVE-2022-32250 (netfilter UAF)  
**Primary Target Kernel**: Upstream Linux v5.15.40 unpatched  

---

## Session 1: 2026-08-28
### Progress
- ✅ Project repository structure initialized.
- ✅ Implementation plan locked around Linux v5.15.40 & CVE-2022-32250.
- ✅ Cloned kernel source: `linux-5.15.40` from kernel.org stable tree.
- ✅ Initial baseline config `nexus_baseline.config` created.
- ✅ **Baseline kernel built successfully!** (`bzImage` ~3.7 MB).

---

## Session 2: 2026-08-29 (Part 1)
### Progress
- ✅ QEMU installed in WSL2 (`qemu-system-x86`).
- ✅ Created `run_qemu.sh` and `test_kernel.sh` scripts.
- ✅ **Diagnosed blank screen issue**: Added `CONFIG_SERIAL_8250=y` and `CONFIG_SERIAL_8250_CONSOLE=y` to config.
- ✅ Confirmed serial console output working (reached expected VFS rootfs panic).
- ✅ Created BusyBox initramfs builder `build_initramfs.sh`.
- ✅ Enabled initramfs support in kernel config (`CONFIG_BLK_DEV_INITRD=y`, `CONFIG_RD_GZIP=y`, `CONFIG_DEVTMPFS=y`).
- ✅ Rebuilt kernel `bzImage` with initramfs config options enabled.

---

## Session 3: 2026-08-29 (Part 2 - Current Session)
### Progress
- ✅ **Fixed initramfs cpio archive bug**: Changed packaging script to run `find .` from inside the `initramfs` directory so `/init` is placed at the archive root.
- ✅ **Verified QEMU Boot**: Custom kernel + initramfs successfully boots to BusyBox `/ #` shell prompt!
- ✅ **Verified User Namespaces**: Tested `unshare -U -n id` inside guest → confirmed functional (`uid=65534` nobody user before mapping).
- ✅ **Verified Target Function**: Searched `/proc/kallsyms` inside guest → confirmed `nft_set_elem_expr` is present (**3 matches**).
- ✅ **Expanded BusyBox Utilities**: Added `unshare`, `nsenter`, `head`, `tail`, `hexdump`, `dd`, `stat`, `cut`, `tee`, and debugging tools to `build_initramfs.sh`.
- ✅ **Configured Git & `.gitignore`**: Excluded heavy kernel source (`linux-5.15.40` ~1.6 GB), rootfs build artifacts (`buildroot` ~2.1 GB), and compiled binaries.
- ✅ Cleaned up temporary test artifacts.

---

## Session 4: 2026-08-29 (Part 3)
### Progress
- ✅ **Created KASAN Kernel Build Script (`build_kasan.sh`)**: Built `bzImage-kasan` (8.5 MB) with `CONFIG_KASAN=y` and `CONFIG_SLUB_DEBUG=y`.
- ✅ **Tested KASAN Kernel Boot**: Confirmed `bzImage-kasan` boots in QEMU with `-m 2G`.
- ✅ **Created Patched Kernel Build Script (`build_patched.sh`)**: Built `bzImage-patched` (3.8 MB) with upstream fix patch applied.
- ✅ **Completed Phase 1 Source Analysis**: Created `docs/CVE-2022-32250-deep-dive.md` detailing the vulnerable function (`nft_set_elem_expr_alloc`), root cause, execution call graph, and patch analysis.

---

## Session 5: 2026-10-22
### Progress
- ✅ **Completed Phase 3 Implementation Modules**:
  - `exploit/common/namespace_setup.{c,h}`: unshare user+net namespaces, deny setgroups, 1:1 UID/GID map.
  - `exploit/common/netlink_helpers.{c,h}`: Header-free Netlink / nfnetlink batch message builder with nested attribute handling.
  - `exploit/cve_2022_32250/trigger.c`: Trigger logic for non-stateful lookup set expression UAF condition.
- ✅ **Static Build & Initramfs Integration**:
  - Successfully compiled static binary `exploit/trigger` (~970 KB).
  - Updated `env/build_initramfs.sh` to automatically bundle `trigger` into `bin/trigger` inside the root filesystem.
  - Rebuilt and verified `initramfs.cpio.gz`.
- ✅ **Fixed Netlink Batch Header Framing**:
  - Resolved `-EINVAL` (-22) in `nft_batch_msg()` by passing generic control message types (`NFNL_MSG_BATCH_BEGIN` = 16, `NFNL_MSG_BATCH_END` = 17) directly without subsystem shift.
- ✅ **Phase 4 Empirical Reproduction Confirmed (Vulnerable Baseline)**:
  - Ran `trigger` inside QEMU guest on `bzImage-kasan`.
  - **KASAN detected Use-After-Free**: `Read of size 4 at addr ffff888005fd2670 in nf_tables_bind_set+0x69f/0x960` in `kmalloc-64`.
  - Confirmed allocation path in `nft_expr_init` and free path in `nft_set_elem_expr_alloc`.
  - Confirmed list poisoning (`LIST_POISON1` / `LIST_POISON2`: `dead000000000122`) during `DELTABLE` teardown at `nft_set_destroy+0x316/0x400`.
  - Saved full KASAN report to `results/traces/cve-2022-32250-kasan.log`.
- ✅ **Phase 4 Patch Verification Confirmed (Remediated Kernel)**:
  - Ran `trigger` inside QEMU guest on `bzImage-patched` (upstream commit `f36736fbd484`).
  - Confirmed clean rejection with `-EOPNOTSUPP` and zero dangling pointers.
  - Confirmed **0 KASAN reports, 0 kernel warnings, and clean table teardown**.
  - Documented complete comparative analysis in `docs/differential-analysis.md`.
- ✅ **Phase 5 Defense Evaluation & Mitigation Analysis**:
  - Analyzed allocator-level defenses (`CONFIG_SLAB_FREELIST_HARDENED`, `CONFIG_SLAB_FREELIST_RANDOM`, `CONFIG_RANDOM_KMALLOC_CACHES`, dedicated `kmem_cache` segregation).
  - Evaluated attack surface gating via unprivileged user namespace sysctls and AppArmor 4.0 profiles.
  - Explored structural solutions (Rust for Linux RAII lifetimes, ARM MTE hardware memory tagging).
  - Authored comprehensive defense evaluation report in `docs/defense-evaluation.md`.
- ✅ **Benchmarking Suite & Performance Metrics**:
  - Implemented `bench/bench_netlink.c` micro-benchmark measuring transaction latency.
  - Statically linked `bench_netlink` and bundled into `initramfs.cpio.gz`.
  - Profiled kernel footprint and transaction latency: confirmed upstream fix imposes zero storage overhead (+0.00%) and negligible latency delta (<0.5%).
  - Generated metrics dataset in `results/benchmarks/kernel_metrics.csv` and summary in `results/benchmarks/benchmark_summary.md`.

---

## Project Status: All Planned Phases (0–5) Complete! 🎉
- Phase 0: Repository structure & architecture ✅
- Phase 1: Vulnerability anatomy & deep dive ✅
- Phase 2: QEMU lab environment (3 kernels + initramfs) ✅
- Phase 3: Exploit modules & initramfs integration ✅
- Phase 4: Empirical reproduction & patch verification ✅
- Phase 5: Mitigation & defense evaluation ✅
