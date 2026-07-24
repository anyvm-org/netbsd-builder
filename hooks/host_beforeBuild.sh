#!/bin/bash
# NetBSD sparc64 beforeBuild -- the earliest hook, before setup() extracts
# VM_QEMU_TAR.
#
# 1. Build the PATCHED qemu-system-sparc64 that the BUILD ITSELF runs on.
#    GitHub runners ship stock QEMU 8.2, whose sun4u sabre PCI-host has the
#    single-slot IRQ-clobber bug (files/qemu-sabre-irq-clobber.patch): under
#    concurrent cmd646 IDE + e1000 DMA the guest's interrupt-clear is dropped
#    and both devices' interrupts wedge, so install / first-boot / the 10.x
#    migration randomly fail with a "lost interrupt" storm. Building on the
#    patched QEMU makes the build itself reliable (this is what setup()
#    extracts via VM_QEMU_TAR and every VM in the pipeline then runs on).
#    Done for ALL sparc64 releases, including 11.0 (classic single disk).
#
# 2. For 10.x only, additionally build the hybrid boot disk + ANYVM
#    root-on-sd0a kernel (files/build-sparc64-bootdisk.sh) that the
#    cmd646-wedge bypass layout needs at RUN time on stock QEMU (macOS /
#    Windows hosts that can't run the x86_64 patched tarball).
#
# Everything is built from upstream sources by THIS builder's own files/
# scripts -- no reference to any sibling builder (user policy).
set -e

[ "$VM_ARCH" = "sparc64" ] || exit 0

# Patched QEMU for the build (all sparc64 releases). VM_QEMU_TAR names the
# output tarball; its dirname is the outdir. setup() extracts it next and
# VM_QEMU_BIN (set in the conf) points at the binary inside.
if [ -n "${VM_QEMU_TAR:-}" ] && [ ! -e "$VM_QEMU_TAR" ]; then
  echo "host_beforeBuild: building patched sparc64 QEMU -> $VM_QEMU_TAR"
  bash files/build-qemu-sparc64.sh "$(dirname "$VM_QEMU_TAR")"
  test -e "$VM_QEMU_TAR"
fi

# Hybrid boot disk + ANYVM kernel (10.x only).
case "$VM_RELEASE" in
  10.*) bash files/build-sparc64-bootdisk.sh "$VM_RELEASE" build ;;
esac
