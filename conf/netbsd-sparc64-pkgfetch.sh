# Two-phase package install for NetBSD/sparc64 (run in the guest over ssh
# stdin by build.py when the conf sets VM_INSTALL_SCRIPT; build.py prepends
# `set -e` plus ANYVM_PKGS and ANYVM_PKG_PATH).
#
# Why two phases: QEMU sun4u's CMD646 IDE emulation loses completion
# interrupts when network DMA and disk DMA run CONCURRENTLY -- exactly what a
# plain `pkg_add <url>` does (fetch over the wire while extracting to wd0).
# Once wedged, every disk command times out ~10s and the final shutdown sync
# crawls for hours. Idle-network disk I/O and idle-disk network I/O are both
# fine, so split the work:
#   phase 1: download pkg_summary + the full dependency closure into a tmpfs
#            (network DMA only; the disk stays idle, writes go to RAM)
#   phase 2: pkg_add from the tmpfs (disk DMA only; the network stays idle)
#
# Uses only NetBSD base tools: sh, ftp(8) (speaks http/https), gunzip, awk
# (nawk), mount_tmpfs. The dependency closure is computed from pkg_summary's
# PKGNAME/DEPENDS fields; pattern oddities (brace alternatives etc.) that the
# resolver misses are covered by keeping the remote URL as a PKG_PATH fallback
# in phase 2 (a rare miss costs a small concurrency window, not a failure).

P="${ANYVM_PKG_PATH%/}"
if [ -z "$P" ]; then
    echo "pkgfetch: ANYVM_PKG_PATH is empty" >&2
    exit 1
fi

D=/tmp/anyvm-pkgs
mkdir -p "$D"
/sbin/mount_tmpfs -s 512m tmpfs "$D"
cd "$D"

echo "pkgfetch phase 1: downloading package closure for: $ANYVM_PKGS"
ftp -o pkg_summary.gz "$P/pkg_summary.gz" < /dev/null
gunzip -f pkg_summary.gz

# Closure over pkg_summary. Records carry PKGNAME=<name>-<version> and zero or
# more DEPENDS=<pattern>:<pkgsrc-path> lines. Map each base name (version
# suffix stripped) to its file name, reduce each DEPENDS pattern to a base
# name (cut at the first version/comparison character), then BFS from the
# wanted list.
awk -v want="$ANYVM_PKGS" '
/^PKGNAME=/ {
    pn = substr($0, 9)
    base = pn
    sub(/-[0-9][^-]*$/, "", base)
    name[base] = pn
    cur = base
    next
}
/^FILE_NAME=/ {
    if (cur != "") fname[cur] = substr($0, 11)
    next
}
/^DEPENDS=/ {
    d = substr($0, 9)
    sub(/:.*/, "", d)
    sub(/[><=\[{].*/, "", d)
    sub(/-$/, "", d)
    if (d != "" && cur != "") dep[cur] = dep[cur] " " d
    next
}
/^$/ { cur = "" }
END {
    n = split(want, W, " ")
    h = 0; t = 0
    for (i = 1; i <= n; i++) {
        if (!(W[i] in seen)) { seen[W[i]] = 1; t++; q[t] = W[i] }
    }
    while (h < t) {
        h++; p = q[h]
        if (!(p in name)) {
            print "pkgfetch: no pkg_summary entry for " p " (fallback to remote)" | "cat 1>&2"
            continue
        }
        m = split(dep[p], DD, " ")
        for (j = 1; j <= m; j++) {
            if (DD[j] != "" && !(DD[j] in seen)) { seen[DD[j]] = 1; t++; q[t] = DD[j] }
        }
    }
    for (i = 1; i <= t; i++) {
        p = q[i]
        if (p in name) {
            if (p in fname) print fname[p]
            else print name[p] ".tgz"
        }
    }
}' pkg_summary > files.txt

echo "pkgfetch phase 1: fetching $(wc -l < files.txt | tr -d ' ') package files to tmpfs"
for f in $(cat files.txt); do
    ftp -o "$f" "$P/$f" < /dev/null
done

# Let the NIC go quiet before the disk-heavy phase.
sleep 2

echo "pkgfetch phase 2: pkg_add from tmpfs (network idle)"
PKG_PATH="$D;$P" /usr/sbin/pkg_add $ANYVM_PKGS

cd /
umount "$D"
echo "pkgfetch: done"
