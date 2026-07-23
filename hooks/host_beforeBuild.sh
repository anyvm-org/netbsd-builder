#!/bin/bash
# NetBSD 10.x sparc64 only: build the hybrid-layout boot disk + ANYVM kernel
# before the image build starts. All the heavy lifting (kernel cross-build,
# base-set extraction, FFS/bootblock/label assembly) lives in
# files/build-sparc64-bootdisk.sh -- the SAME script the release-files job
# (.github/data/uploadfiles.yml) runs to publish the boot-disk assets, so
# what ships is exactly what this build boots and verifies.
# run_hook() treats a non-zero exit as FATAL, which is what we want -- a
# missing kernel would fail the migration hook an hour later anyway.
set -e

case "$VM_ARCH:$VM_RELEASE" in
  sparc64:10.*) : ;;
  *) exit 0 ;;
esac

bash files/build-sparc64-bootdisk.sh "$VM_RELEASE" build
