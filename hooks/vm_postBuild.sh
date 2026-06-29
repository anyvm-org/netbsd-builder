

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



