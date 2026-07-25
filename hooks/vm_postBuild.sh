

# NetBSD's ip6mode only accepts autohost/host/router; ip6mode="none" was never
# valid -- a silent no-op before 11.0, a boot-time `WARNING: invalid $ip6mode
# value "none"` on 11.0+ -- so it is dropped. IPv4-only is enforced by
# dhcpcd_flags="-4" below.
echo 'dhcpcd_flags="-4"' >> /etc/rc.conf


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
# Entry 1 is the rolling per-release URL, the same one pkg_add would default
# to. It 302-redirects to the current quarterly, so it self-heals across
# quarterly rollovers and needs no maintenance.
#
# Entry 2 pins 9.0_2026Q1 and exists because entry 1 is currently unusable on
# 9.x/x86_64: that redirect now lands on x86_64/9.0_2026Q2, whose bulk build
# shipped ZERO packages (checked 2026-07-25 -- 10.x/11.0 Q2 hold ~27.5k each,
# and aarch64 9.x still resolves to its Q1, which is why only 9.x amd64 broke).
# 9.0_2026Q1 is intact (27823 packages on x86_64, 21298 on aarch64) and is
# served with no redirect, which matters because the 9.x pkg_add does not
# follow redirects. Entry 2 is written unconditionally rather than behind a
# `case $(uname -r)` -- on 10.x/11.0 entry 1 satisfies every request so it is
# never consulted, and on arches that never had a 9.x set at all (sparc64 only
# ships 10.x/11.0) it is simply an URL nothing ever fetches. Drop entry 2 once
# a quarterly ships a real 9.x bulk build again.
anyvm_pkgarch=$(uname -p)
anyvm_pkgrel=$(uname -r | cut -f 1,2 -d. | cut -f 1 -d_)
anyvm_pkgbase=http://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD
cat >/etc/pkg_install.conf <<ANYVM_EOF
PKG_PATH=$anyvm_pkgbase/$anyvm_pkgarch/$anyvm_pkgrel/All/;$anyvm_pkgbase/$anyvm_pkgarch/9.0_2026Q1/All
ANYVM_EOF
cat /etc/pkg_install.conf



