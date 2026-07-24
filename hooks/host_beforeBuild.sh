#!/bin/bash
# NetBSD sparc64 beforeBuild -- the earliest hook, before setup() extracts
# VM_QEMU_TAR.
#
# Build the PATCHED qemu-system-sparc64 that the BUILD ITSELF runs on.
# GitHub runners ship stock QEMU 8.2, whose sun4u sabre PCI-host has the
# single-slot IRQ-clobber bug (files/qemu-sabre-irq-clobber.patch): under
# concurrent cmd646 IDE + e1000 DMA the guest's interrupt-clear is dropped
# and both devices' interrupts wedge, so install / first-boot randomly fail
# with a "lost interrupt" storm. Building on the patched QEMU makes the build
# reliable -- setup() extracts VM_QEMU_TAR and every VM in the pipeline runs
# on it. Done for ALL sparc64 releases (all are single IDE disk).
#
# Everything is built from upstream sources by THIS builder's own files/
# script -- no reference to any sibling builder (user policy).
set -e

[ "$VM_ARCH" = "sparc64" ] || exit 0

# VM_QEMU_TAR names the output tarball; its dirname is the outdir. setup()
# extracts it next and VM_QEMU_BIN (set in the conf) points at the binary.
if [ -n "${VM_QEMU_TAR:-}" ] && [ ! -e "$VM_QEMU_TAR" ]; then
  echo "host_beforeBuild: building patched sparc64 QEMU -> $VM_QEMU_TAR"
  bash files/build-qemu-sparc64.sh "$(dirname "$VM_QEMU_TAR")"
  test -e "$VM_QEMU_TAR"
fi
