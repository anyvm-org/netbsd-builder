

| Release | x86_64(amd64)  | aarch64(arm64) | riscv64 | sparc64 |
|---------|---------|---------|---------|---------|
|  11.0   |  ✅ (rsync,scp,sshfs,nfs)     |   ✅ (rsync,scp,sshfs,nfs)   |   ✅ (rsync,scp,sshfs,nfs)   |   ✅ (scp,sshfs,nfs)   |
|  10.1   |  ✅ (rsync,scp,sshfs,nfs)     |   ✅ (rsync,scp,sshfs,nfs)   |   —   |   ✅ (rsync,scp,sshfs,nfs)   |
|  10.0   |  ✅ (rsync,scp,sshfs,nfs)     |   ✅ (rsync,scp,sshfs,nfs)   |   —   |   ✅ (rsync,scp,sshfs,nfs)   |
|  9.4    |  ✅ (rsync,scp,sshfs,nfs)     |   ✅ (rsync,scp,sshfs,nfs)   |   —   |   —   |
|  9.3    |  ✅ (rsync,scp,sshfs,nfs)     |   ✅ (rsync,scp,sshfs,nfs)   |   —   |   —   |
|  9.2    |  ✅ (rsync,scp,sshfs,nfs)     |   ✅ (rsync,scp,sshfs,nfs)   |   —   |   —   |
|  9.1    |  ✅ (rsync,scp,sshfs,nfs)     |   ✅ (rsync,scp,sshfs,nfs)   |   —   |   —   |
|  9.0    |  ✅ (rsync,scp,sshfs,nfs)     |   ✅ (rsync,scp,sshfs,nfs)   |   —   |   —   |


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


