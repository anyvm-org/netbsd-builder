

# NetBSD's ip6mode only accepts autohost/host/router; ip6mode="none" was never
# valid -- a silent no-op before 11.0, a boot-time `WARNING: invalid $ip6mode
# value "none"` on 11.0+ -- so it is dropped. IPv4-only is enforced by
# dhcpcd_flags="-4" below.
echo 'dhcpcd_flags="-4"' >> /etc/rc.conf


# Do not run postfix. These images are CI workers, never mail servers, so the
# daemon is dead weight -- and worse, it is an amplifier: /etc/rc.d/postfix
# resolves the host's name at startup, so with no working network it BLOCKS,
# and because it sits late in the rc order nothing after it ever runs. A guest
# whose DHCP lease is late or missing therefore stops dead at
# "Starting postfix." -- no inetd, no cron, no getty, no console login, no
# further serial output at all. That is exactly how netbsd 10.0-aarch64 failed
# in anyvm run 30353533772: three jobs sat at that line until the 600 s boot
# probe gave up, and the frozen console made it look like a kernel hang rather
# than a network problem. Turning postfix off does not fix a missing lease, but
# it keeps rc completing so the console still reaches a login prompt and the
# failure stays diagnosable. Compare a green boot, where the lease lands a few
# seconds into postfix's lookup and rc resumes immediately.
echo 'postfix=NO' >> /etc/rc.conf


echo 'name_servers="8.8.8.8 1.1.1.1"' >>/etc/resolvconf.conf

resolvconf -u


# Remove the boot loader countdown ("booting netbsd - starting in N seconds").
# timeout=0 boots the default immediately (boot.cfg(5)). VERIFIED by a banner
# test: on evbarm aarch64, efiboot >= 10.0 (rev 2.x) reads boot.cfg from the
# FAT/EFI partition's ROOT (mounted at /boot), NOT the FFS root. NetBSD 9.x
# efiboot (rev 1.13) ignores boot.cfg entirely, so its 5s prompt is not
# removable -- writing the file there is simply a harmless no-op. Also drop one
# on the FFS root for loaders that read it there (x86 boot, sparc64 ofwboot).
# Each write forces a single timeout=0 while keeping any existing menu entries.
anyvm_set_timeout0() {
  if [ -f "$1" ]; then
    grep -v '^timeout=' "$1" > "$1.anyvm" 2>/dev/null && printf 'timeout=0\n' >> "$1.anyvm" && mv "$1.anyvm" "$1"
  else
    printf 'timeout=0\n' > "$1" 2>/dev/null
  fi
}
anyvm_set_timeout0 /boot.cfg
anyvm_esp=$(mount | awk '$5=="msdos"{print $3; exit}')
[ -n "$anyvm_esp" ] && [ "$anyvm_esp" != "/" ] && anyvm_set_timeout0 "$anyvm_esp/boot.cfg"


# Persistent binary-package search path. pkg_install.conf(5) reads PKG_PATH as
# a "semicolon-separated list of paths or URLs" on EVERY pkg_add invocation, so
# this covers ssh commands, interactive logins and cron alike -- unlike a value
# in ~/.ssh/environment, which only applies to ssh sessions AND (per the "(*)"
# marker in that man page) shadows this file entirely. enablessh.txt therefore
# no longer writes PKG_PATH.
#
# Entry 1 is the newest quarterly that ACTUALLY EXISTS, found by scraping
# the arch directory listing at bake time. The old entry 1 was the rolling
# per-release alias, on the theory that its 302 "self-heals across
# quarterly rollovers and needs no maintenance" -- refuted 2026-08-03:
# upstream neglects those symlinks (riscv64/11.0 still pointed at the
# DELETED 11.0_2025Q4 for weeks after 11.0_2026Q2 replaced it), which left
# the baked PKG_PATH dead on the whole riscv64 image and every runtime
# pkg_add failing (netbsd-vm run 30790664175). Listings do not lie about
# which directories exist; aliases do. Same lesson, same fix shape as the
# build-time scrape in conf/netbsd-11.0-riscv64.conf.
#
# Entry 2 keeps the rolling alias as the self-healing backup for the day
# the scraped quarterly is itself rotated away AND the alias is healthy.
# It is emitted unconditionally; entry 1 is simply omitted when no exact
# quarterly exists, rather than falling back to this same URL (which used
# to put the identical 404 in the list twice).
#
# Entry 3 and beyond are the BRANCH fallback: EVERY quarterly built for
# the branch's base release ("<major>.0_YYYYQn"), newest first. A release
# gets binary packages from its own major branch -- that is upstream's own
# rule, not an inference: ftp.netbsd.org serves ".../x86_64/10.1/All/" as
# a 302 to ".../x86_64/10.0_2026Q2/All/", which is why 10.1 builds green
# today with no 10.1_* quarterly of its own. They are scraped from the
# listing, never taken as an alias, for the riscv64 reason in entry 1.
#
# ALL of them, not just the newest, because NEWEST IS NOT BEST: a bulk
# build can be partial. sparc64's 10.0_2026Q1 carries 15176 packages but
# none of rsync, fuse-sshfs or tree, while the OLDER 10.0_2024Q3 is
# complete at 25056 (counted 2026-09-17) -- exactly the same shape as the
# empty 9.0_2026Q2 below. Listing every quarterly costs one extra round of
# "Not Found" per miss and lets pkg_add, which consults entries in order,
# walk back to a build that actually has the package.
#
# This entry REPLACED a hardcoded 9.0_2026Q1 pin whose guard tested the
# arch LISTING for that directory instead of testing the GUEST's release.
# Every arch listing that has 9.x at all contains it, so the pin was
# appended to 10.x and 11.x images too, and pkg_add -- which only WARNS
# on a platform mismatch -- happily installed 9.x packages onto a 10.x
# guest whenever the earlier entries missed. NetBSD 10.2 hit exactly
# that on 2026-09-17 (build run 35161331304): no 10.2/ directory exists
# upstream yet, so both earlier entries 404'd, rsync-3.4.3 came from
# 9.0_2026Q1 with only "built for NetBSD/x86_64 9.0 vs 10.2 (this host)",
# and the installed binary could not start -- 'Shared object
# "libcrypto.so.14" not found', because 9.x links libcrypto.so.14 and
# 10.2 does not ship it. build.py's post-install verification caught it
# and failed the build, which is the intended outcome, but the image had
# no business getting 9.x packages in the first place.
#
# 9.x KEEPS the 9.0_2026Q1 pin rather than the newest branch quarterly:
# 9.0_2026Q2 exists but shipped ZERO packages, and 9.x pkg_add cannot
# follow redirects either. Drop the special case once a quarterly ships
# a real 9.x bulk build again.
#
# A branch quarterly that would repeat entry 1 is skipped (that is every
# ".0" release, e.g. 11.0), and a branch with no quarterly on this arch
# contributes nothing (riscv64 has only 11.0_2026Q2). pkg_add consults
# EVERY entry while searching, so a dead entry is not silent -- it sprays
# "Can't process ... Not Found" noise on every runtime pkg_add
# (netbsd-vm run 30827543128, 10.1-sparc64). That is the price of the
# walk-back above; keep the list to this release and its branch so it
# stays two or three entries, never the whole listing.
#
# base ftp(1) speaks plain http on every NetBSD release we ship; if the
# scrape fails (offline mirror at bake time), the list degrades to the
# rolling alias alone, never to an empty PKG_PATH.
anyvm_pkgarch=$(uname -p)
anyvm_pkgrel=$(uname -r | cut -f 1,2 -d. | cut -f 1 -d_)
anyvm_pkgmajor=$(echo "$anyvm_pkgrel" | cut -f 1 -d.)
anyvm_pkgbase=http://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD
anyvm_listing=$(ftp -o - "$anyvm_pkgbase/$anyvm_pkgarch/" 2>/dev/null)

# Every "<prefix>_YYYYQn" directory present in the listing, NEWEST FIRST
# (empty when there is none). All candidates share the prefix, so a plain
# reverse sort orders them by date.
anyvm_all_q() {
  printf '%s\n' "$anyvm_listing" \
    | grep -oE "$1_[0-9][0-9][0-9][0-9]Q[0-9]" \
    | sort -ru
}

anyvm_q_exact=$(anyvm_all_q "$anyvm_pkgrel" | head -n 1)
if [ "$anyvm_pkgmajor" = "9" ]; then
  anyvm_q_branch=$(printf '%s\n' "$anyvm_listing" \
    | grep -o "9\.0_2026Q1" | head -n 1)
else
  anyvm_q_branch=$(anyvm_all_q "$anyvm_pkgmajor\.0")
fi

anyvm_path=
if [ -n "$anyvm_q_exact" ]; then
  anyvm_path=$anyvm_pkgbase/$anyvm_pkgarch/$anyvm_q_exact/All\;
fi
anyvm_path=$anyvm_path$anyvm_pkgbase/$anyvm_pkgarch/$anyvm_pkgrel/All/
for anyvm_q in $anyvm_q_branch; do
  if [ "$anyvm_q" != "$anyvm_q_exact" ]; then
    anyvm_path=$anyvm_path\;$anyvm_pkgbase/$anyvm_pkgarch/$anyvm_q/All
  fi
done

cat >/etc/pkg_install.conf <<ANYVM_EOF
PKG_PATH=$anyvm_path
ANYVM_EOF
cat /etc/pkg_install.conf



