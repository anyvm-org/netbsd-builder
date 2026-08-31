

| Release | x86_64(amd64) | aarch64(arm64) | riscv64 | sparc64 |
|---------|---------|---------|---------|---------|
| 11.0-microvm | ✅ (rsync,scp,sshfs,tar) | — | — | — |
| 11.0 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (scp,sshfs,nfs,tar) |
| 10.1 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | — | ✅ (scp,sshfs,nfs,rsync,tar) |
| 10.0 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | — | ✅ (scp,sshfs,nfs,rsync,tar) |
| 9.4 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | — | — |
| 9.3 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | — | — |
| 9.2 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | — | — |
| 9.1 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | — | — |
| 9.0 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | — | — |

<!-- arch-label: x86_64 = x86_64(amd64) -->
<!-- arch-label: aarch64 = aarch64(arm64) -->

> **Note:** NetBSD sparc64 runs under QEMU `sun4u` (TCG only). All releases
> ship a single-IDE-disk image. The CMD646 IDE "lost interrupt" wedge that
> used to make sparc64 boots intermittently fail is fixed at its source: the
> sun4u sabre IRQ-clobber bug present in every upstream QEMU is patched
> (`files/qemu-sabre-irq-clobber.patch`) in the QEMU the images are built on
> AND in the QEMU anyvm downloads at run time (netbsd-builder publishes the
> patched `qemu-10.2.3-sparc64-noble.tar.zst`). On **Linux x86_64** hosts every
> sync method listed above is CI-green (`testsparc64` in anyvm's netbsd.yml).
> 11.0 has no rsync because pkgsrc ships only a sparc64 rsync linked against
> 10.0's `libcrypto.so.15`, which will not install on 11.0's newer OpenSSL.
> CAVEAT: macOS / Windows hosts can't run that x86_64 patched
> tarball, so there sparc64 falls back to the system QEMU and can still wedge
> under heavy concurrent I/O -- a re-run usually succeeds.

> **Note:** `11.0-microvm` is a fast-boot VARIANT of 11.0 (same install,
> same userspace): anyvm boots NetBSD's official MICROVM kernel directly on
> QEMU's `microvm` machine type (no BIOS/PCI/ACPI, virtio over MMIO), which
> cuts boot-to-ssh about 4x vs the `pc` machine (7.4s vs 29.6s under KVM).
> The kernel ships as the `netbsd-11.0-microvm-kernel` release asset. No
> `nfs` sync: the MICROVM kernel has no NFS client and the GENERIC
> `nfs.kmod` does not load into it; `sshfs` works (puffs is built in).

> **Note:** NetBSD 8.0/8.1/8.2 confs are kept on disk but deliberately
> shelved (undocumented -- no table row, no releases.json entry; verified
> against `git show HEAD:.github/data/table.md`, which has never listed a
> 8.x row). The official 8.0 pkgsrc bulk-build source has gone from
> upstream (commit b6a2576 "revert my last changes. the official 8.0 pkg
> src has gone, we can not build it"), so 8.x cannot produce a working
> image.
<!-- shelved: 8.0 -->
<!-- shelved: 8.1 -->
<!-- shelved: 8.2 -->

How the images are built:

Each image is built automatically in the
[anyvm-org/netbsd-builder](https://github.com/anyvm-org/netbsd-builder)
repo's GitHub Actions: it downloads the official NetBSD installer ISO,
boots it in QEMU, drives sysinst unattended over the serial console,
enables ssh, pre-installs the packages listed in the conf, and exports
the installed disk as a compressed qcow2 image.

Upstream install media: current releases from
https://ftp.netbsd.org/pub/NetBSD/ and EOL releases from
https://archive.netbsd.org/pub/NetBSD-archive/.

The `-microvm` variants additionally ship NetBSD's own release MICROVM
kernel (`binary/kernel/netbsd-MICROVM.gz`, SHA512-verified against the
release checksums, gunzipped) as a `netbsd-<release>-microvm-kernel`
asset; anyvm boots it directly on QEMU's `microvm` machine type.
