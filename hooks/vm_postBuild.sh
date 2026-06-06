

echo 'ip6mode="none"' >> /etc/rc.conf

echo 'dhcpcd_flags="-4"' >> /etc/rc.conf


echo 'name_servers="8.8.8.8 1.1.1.1"' >>/etc/resolvconf.conf

resolvconf -u



