#!/bin/bash
# Fetch the official NetBSD MICROVM kernel(s) and stage them as release
# assets, one per microvm variant conf.
#
# The microvm variant images (conf/netbsd-*-microvm.conf) boot by direct
# kernel load on QEMU's 'microvm' machine type, so the kernel must live
# OUTSIDE the qcow2, as its own release asset next to the image sidecars.
# anyvm.py downloads it from THIS builder's release at the image's pinned
# version (profile.json "kernel_asset"), never from ftp.netbsd.org at run
# time.
#
# The kernel is bit-for-bit NetBSD's own release build
# (binary/kernel/netbsd-MICROVM.gz), verified against the release SHA512
# file and shipped gunzipped (QEMU -kernel PVH boot needs the plain ELF).
set -e

outdir="${1:-build}"
mkdir -p "$outdir"

fetch_one() {
  # $1 = NetBSD release (e.g. 11.0), $2 = arch dir (amd64), $3 = asset name
  rel="$1"; archdir="$2"; asset="$3"
  base="https://ftp.netbsd.org/pub/NetBSD/NetBSD-$rel/$archdir/binary/kernel"
  echo "fetch-microvm-kernel: $base/netbsd-MICROVM.gz -> $outdir/$asset"
  curl -fSL -o "$outdir/netbsd-MICROVM.gz.tmp" "$base/netbsd-MICROVM.gz"
  curl -fSL -o "$outdir/MICROVM.SHA512.tmp" "$base/SHA512"
  want=$(grep "(netbsd-MICROVM.gz)" "$outdir/MICROVM.SHA512.tmp" | awk '{print $NF}')
  got=$(sha512sum "$outdir/netbsd-MICROVM.gz.tmp" | awk '{print $1}')
  if [ -z "$want" ] || [ "$want" != "$got" ]; then
    echo "fetch-microvm-kernel: SHA512 mismatch for $asset (want=$want got=$got)"
    exit 1
  fi
  gunzip -c "$outdir/netbsd-MICROVM.gz.tmp" > "$outdir/$asset"
  rm -f "$outdir/netbsd-MICROVM.gz.tmp" "$outdir/MICROVM.SHA512.tmp"
  ls -l "$outdir/$asset"
}

# One line per microvm variant conf; keep in step with conf/*-microvm.conf.
fetch_one 11.0 amd64 netbsd-11.0-microvm-kernel
