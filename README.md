

[![Build](https://github.com/anyvm-org/netbsd-builder/actions/workflows/build.yml/badge.svg)](https://github.com/anyvm-org/netbsd-builder/actions/workflows/build.yml)

Latest: v2.1.2


The image builder for `netbsd`


All the supported releases are here:



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






How to build:

1. Use the [manual.yml](.github/workflows/manual.yml) to build manually.
   
    Run the workflow manually, you will get a view-only webconsole from the output of the workflow, just open the link in your web browser.
   
    You will also get an interactive VNC connection port from the output, you can connect to the vm by any vnc client.

2. Run the builder locally on your Ubuntu machine.

    Just clone the repo. and run:
    ```bash
    python3 build.py conf/netbsd-9.4.conf
    ```
   
