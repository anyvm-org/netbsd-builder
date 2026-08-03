

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
#
# Entry 3 pins 9.0_2026Q1 for the 9.x era: the 9.x amd64 quarterly redirect
# lands on a Q2 bulk build that shipped ZERO packages, and 9.x pkg_add
# cannot follow redirects anyway. Only appended when the arch listing
# actually contains 9.0_2026Q1 (x86_64 and aarch64 do; sparc64 and riscv64
# do not): pkg_add consults EVERY entry while searching, so a dead pin is
# not silent -- it sprays "Can't process ... Not Found" noise on every
# runtime pkg_add (netbsd-vm run 30827543128, 10.1-sparc64). Drop the pin
# once a quarterly ships a real 9.x bulk build again.
#
# base ftp(1) speaks plain http on every NetBSD release we ship; if the
# scrape fails (offline mirror at bake time), entry 1 degrades to the
# alias, i.e. exactly the previous behavior, never an empty PKG_PATH.
anyvm_pkgarch=$(uname -p)
anyvm_pkgrel=$(uname -r | cut -f 1,2 -d. | cut -f 1 -d_)
anyvm_pkgbase=http://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD
anyvm_listing=$(ftp -o - "$anyvm_pkgbase/$anyvm_pkgarch/" 2>/dev/null)
anyvm_quarter=$(printf '%s\n' "$anyvm_listing" \
  | grep -oE "${anyvm_pkgrel}_[0-9][0-9][0-9][0-9]Q[0-9]" \
  | sort | tail -n 1)
if [ -n "$anyvm_quarter" ]; then
  anyvm_entry1=$anyvm_pkgbase/$anyvm_pkgarch/$anyvm_quarter/All
else
  anyvm_entry1=$anyvm_pkgbase/$anyvm_pkgarch/$anyvm_pkgrel/All/
fi
anyvm_pin=
if printf '%s\n' "$anyvm_listing" | grep -q "9\.0_2026Q1"; then
  anyvm_pin=";$anyvm_pkgbase/$anyvm_pkgarch/9.0_2026Q1/All"
fi
cat >/etc/pkg_install.conf <<ANYVM_EOF
PKG_PATH=$anyvm_entry1;$anyvm_pkgbase/$anyvm_pkgarch/$anyvm_pkgrel/All/$anyvm_pin
ANYVM_EOF
cat /etc/pkg_install.conf



