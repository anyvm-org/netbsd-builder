

# NetBSD's ip6mode only accepts autohost/host/router; ip6mode="none" was never
# valid -- a silent no-op before 11.0, a boot-time `WARNING: invalid $ip6mode
# value "none"` on 11.0+ -- so it is dropped. IPv4-only is enforced by
# dhcpcd_flags="-4" below.
echo 'dhcpcd_flags="-4"' >> /etc/rc.conf


echo 'name_servers="8.8.8.8 1.1.1.1"' >>/etc/resolvconf.conf

resolvconf -u



