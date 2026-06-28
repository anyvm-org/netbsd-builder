

| Release | x86_64(amd64)  | aarch64(arm64) | riscv64 | sparc64 |
|---------|---------|---------|---------|---------|
|  11.0   |  ✅ (rsync,scp,sshfs,nfs)     |   ✅ (rsync,scp,sshfs,nfs)   |   ✅ (rsync,scp,sshfs,nfs)   |   ✅ (scp,sshfs,nfs)   |
|  10.1   |  ✅ (rsync,scp,sshfs,nfs)     |   ✅ (rsync,scp,sshfs,nfs)   |   —   |   ✅ (scp,sshfs,nfs)   |
|  10.0   |  ✅ (rsync,scp,sshfs,nfs)     |   ✅ (rsync,scp,sshfs,nfs)   |   —   |   ✅ (scp,sshfs,nfs)   |
|  9.4    |  ✅ (rsync,scp,sshfs,nfs)     |   —   |   —   |   —   |
|  9.3    |  ✅ (rsync,scp,sshfs,nfs)     |   —   |   —   |   —   |
|  9.2    |  ✅ (rsync,scp,sshfs,nfs)     |   —   |   —   |   —   |
|  9.1    |  ✅ (rsync,scp,sshfs,nfs)     |   —   |   —   |   —   |
|  9.0    |  ✅ (rsync,scp,sshfs,nfs)     |   —   |   —   |   —   |


> **Note:** NetBSD sparc64 runs under QEMU `sun4u` (TCG only). Its emulated
> CMD646 IDE controller can intermittently wedge ("lost interrupt") under
> sustained disk+network I/O, so sparc64 is **not fully stable and will
> occasionally fail to boot**. This is intrinsic to QEMU's sun4u emulation,
> not the image -- a re-run usually succeeds.


