

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


> **Note:** NetBSD sparc64 runs under QEMU `sun4u` (TCG only). Since builder
> v2.1.5 the 10.0 / 10.1 images use a hybrid disk layout -- a tiny boot-only
> IDE disk plus the whole system on an `mptsas1068` SCSI disk (`sd0`) -- which
> eliminates the CMD646 IDE "lost interrupt" wedge that used to make sparc64
> boots intermittently fail; all four sync methods (incl. rsync) are verified
> by CI on every anyvm push (`testsparc64` in anyvm's netbsd.yml). These
> releases ship two disk assets: `<image>.qcow2.zst` (root) plus
> `<image>-boot.qcow2.zst`, both fetched automatically by anyvm. 11.0 still
> uses the classic single-IDE-disk image, where the wedge can appear under
> sustained disk+network I/O -- a re-run usually succeeds there.


