

[![Build](https://github.com/anyvm-org/netbsd-builder/actions/workflows/build.yml/badge.svg)](https://github.com/anyvm-org/netbsd-builder/actions/workflows/build.yml)

Latest: v2.2.2


The image builder for `netbsd`


All the supported releases are here:



| Release | x86_64(amd64) | aarch64(arm64) | riscv64 | sparc64 |
|---------|---------|---------|---------|---------|
| 11.0 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | ✅ (scp,sshfs,nfs) |
| 10.1 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | — | ✅ (scp,sshfs,nfs,rsync) |
| 10.0 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | — | ✅ (scp,sshfs,nfs,rsync) |
| 9.4 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | — | — |
| 9.3 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | — | — |
| 9.2 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | — | — |
| 9.1 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | — | — |
| 9.0 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | — | — |

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




How to build:

1. Use the [manual.yml](.github/workflows/manual.yml) to build manually.
   
    Run the workflow manually, you will get a view-only webconsole from the output of the workflow, just open the link in your web browser.
   
    You will also get an interactive VNC connection port from the output, you can connect to the vm by any vnc client.

2. Run the builder locally on your Ubuntu machine.

    Just clone the repo. and run:
    ```bash
    python3 build.py conf/netbsd-9.4.conf
    ```
   
