#!/bin/bash
# Build the sparc64 hybrid-layout BOOT DISK for one NetBSD 10.x release,
# entirely on a Linux host from official NetBSD release sources/sets:
#
#   1. cross-build the ANYVM kernel (GENERIC + "config netbsd root on sd0a")
#      with NetBSD's build.sh (tools cached per release under $HOME);
#   2. extract bootblk + ofwboot from the release's base.tar.xz set;
#   3. assemble the disk: big-endian FFSv1 (nbmakefs) holding /ofwboot +
#      /netbsd, primary bootstrap via nbinstallboot, and a Sun disklabel
#      written per src/sys/dev/sun/disklabel.h (verified: makefs FFSv2
#      output is NOT readable by the sparc64 bootblk -- it dies with an
#      Unhandled Exception 0x30 -- while FFSv1 boots clean; keep version=1);
#   4. convert to qcow2 and zstd-compress to the release asset name.
#
# Usage: build-sparc64-bootdisk.sh <release> <outdir>
#   e.g. build-sparc64-bootdisk.sh 10.1 build
# Outputs in <outdir>:
#   netbsd-<release>-sparc64-boot.qcow2       (for the image build pipeline)
#   netbsd-<release>-sparc64-boot.qcow2.zst   (the release asset)
#   netbsd-ANYVM                              (raw kernel, for the migration
#                                              hook to scp into the guest)
#
# Called from two places so the shipped asset is exactly what the image
# build verified: hooks/host_beforeBuild.sh (per sparc64 10.x matrix job)
# and the release-files job (.github/data/uploadfiles.yml).
set -e

REL="$1"
OUTDIR="$2"
if [ -z "$REL" ] || [ -z "$OUTDIR" ]; then
  echo "usage: $0 <release> <outdir>"; exit 1
fi
ROOT="$(pwd)"
mkdir -p "$OUTDIR"
OUT="$ROOT/$OUTDIR"
NBSRC="$HOME/anyvm-nbsrc-$REL"
mkdir -p "$NBSRC"

echo "==> sparc64 boot disk for NetBSD $REL"
df -h / | tail -n 1

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
  --no-install-recommends \
  build-essential zlib1g-dev ncurses-dev flex bison m4 aria2 zstd \
  qemu-utils xz-utils python3

cd "$NBSRC"
# src+gnusrc+syssrc+sharesrc are enough for tools+kernel (no xsrc). Sets are
# immutable per release, so presence checks + aria2c -c make reruns cheap on
# a warm machine (local WSL); CI runners always start cold.
for s in src gnusrc syssrc sharesrc; do
  if [ ! -s "$s.tgz" ]; then
    aria2c -c -x8 -s8 -o "$s.tgz" \
      "https://cdn.netbsd.org/pub/NetBSD/NetBSD-$REL/source/sets/$s.tgz"
  fi
done
if [ ! -d usr/src/sys ]; then
  for s in src gnusrc syssrc sharesrc; do
    tar xzf "$s.tgz"
  done
fi

# bootblk (primary bootstrap FCode) + ofwboot (secondary loader) come from
# the release's binary base set; only those two members are extracted.
if [ ! -s usr/mdec/bootblk ] || [ ! -s usr/mdec/ofwboot ]; then
  if [ ! -s base.tar.xz ]; then
    aria2c -c -x8 -s8 -o base.tar.xz \
      "https://cdn.netbsd.org/pub/NetBSD/NetBSD-$REL/sparc64/binary/sets/base.tar.xz"
  fi
  tar -xJf base.tar.xz ./usr/mdec/bootblk ./usr/mdec/ofwboot
fi

cd usr/src
cat > sys/arch/sparc64/conf/ANYVM <<'EOF'
# ANYVM - GENERIC with root forced onto the mpt(4) SCSI disk sd0a.
# QEMU sun4u's onboard CMD646 IDE randomly wedges (lost interrupt) under
# DMA load; the anyvm image keeps only bootblock+ofwboot+kernel on the IDE
# disk (never mounted) and the whole system on an mptsas1068 disk, which
# needs the kernel to root on sd0a instead of the boot device wd0.
include "arch/sparc64/conf/GENERIC"
no config netbsd
config netbsd root on sd0a type ffs
EOF

MAKEJ="$(nproc)"
if [ ! -x ../tools/bin/nbmake-sparc64 ]; then
  sh build.sh -U -m sparc64 -j "$MAKEJ" -T ../tools -O ../obj tools
fi
sh build.sh -U -m sparc64 -j "$MAKEJ" -T ../tools -O ../obj kernel=ANYVM
install -m 755 ../obj/sys/arch/sparc64/compile/ANYVM/netbsd "$OUT/netbsd-ANYVM"

# ---- assemble the disk image ----
TB="$NBSRC/usr/tools/bin"
W="$NBSRC/bootdisk"
rm -f "$W/boot.img" "$W/boot.qcow2"
mkdir -p "$W/tree"
# install(1), not cp: the set's ofwboot is mode 0555 and a plain cp preserves
# that, so a rerun's cp over the read-only leftover fails with EACCES;
# install unlinks the target first.
install -m 644 "$NBSRC/usr/mdec/ofwboot" "$W/tree/ofwboot"
install -m 644 "$OUT/netbsd-ANYVM" "$W/tree/netbsd"

# Geometry: 63 sectors/track x 16 tracks = 1008 sectors (516096 bytes) per
# cylinder (matches what the guest's own disklabel reports for QEMU disks).
# Disk = 66 cylinders; partition a = 65 cylinders (~32MB), c = whole disk.
ASIZE=33546240
DSIZE=34062336
"$TB/nbmakefs" -t ffs -B be -o version=1 -s $ASIZE "$W/boot.img" "$W/tree"
truncate -s $DSIZE "$W/boot.img"
"$TB/nbinstallboot" -v -m sparc64 "$W/boot.img" "$NBSRC/usr/mdec/bootblk"

# Sun disklabel, layout per src/sys/dev/sun/disklabel.h (struct
# sun_disklabel, 512 bytes, all fields big-endian): sl_text[128],
# sl_xxx1[292], u16 rpm/pcylinders/sparespercyl, char[4], u16 interleave/
# ncylinders/acylinders/ntracks/nsectors, char[4], 8 x { i32 cyloffset,
# i32 nsectors }, u16 sl_magic == SUN_DKMAGIC (55998), u16 sl_cksum with
# XOR of all 256 shorts == 0 (sys/dev/sun/disksubr.c sun_disklabel cksum).
python3 - "$W/boot.img" "$REL" <<'EOF'
import struct, sys
img, rel = sys.argv[1], sys.argv[2]
NSECT = 63; NTRACK = 16; NCYL = 66; ACYL = 0
ASECS = 65520; DSECS = 66528
buf = bytearray(512)
text = ("anyvm boot disk | NetBSD %s sparc64" % rel).encode()
buf[0:len(text)] = text
off = 128 + 292
struct.pack_into(">HHH", buf, off, 5400, NCYL, 0)      # rpm, pcyl, spare
off += 6 + 4
struct.pack_into(">HHHHH", buf, off, 1, NCYL, ACYL, NTRACK, NSECT)
off += 10 + 4
assert off == 444, off
parts = [(0, ASECS), (0, 0), (0, DSECS)] + [(0, 0)] * 5
for i, (cyl, nsec) in enumerate(parts):
    struct.pack_into(">ii", buf, 444 + 8 * i, cyl, nsec)
struct.pack_into(">H", buf, 508, 55998)                # SUN_DKMAGIC
ck = 0
for i in range(0, 510, 2):
    ck ^= struct.unpack_from(">H", buf, i)[0]
struct.pack_into(">H", buf, 510, ck)
with open(img, "r+b") as f:
    f.write(bytes(buf))
print("sun label written, cksum=%04x" % ck)
EOF

qemu-img convert -f raw -O qcow2 "$W/boot.img" "$W/boot.qcow2"
cp "$W/boot.qcow2" "$OUT/netbsd-$REL-sparc64-boot.qcow2"
zstd -f "$OUT/netbsd-$REL-sparc64-boot.qcow2" \
  -o "$OUT/netbsd-$REL-sparc64-boot.qcow2.zst"
ls -lh "$OUT/netbsd-$REL-sparc64-boot.qcow2" \
  "$OUT/netbsd-$REL-sparc64-boot.qcow2.zst" "$OUT/netbsd-ANYVM"
df -h / | tail -n 1
echo "==> sparc64 boot disk for NetBSD $REL done"
