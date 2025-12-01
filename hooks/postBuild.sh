

#!/bin/sh

echo "Applying NetBSD fast boot optimizations for wm0 + DHCP..."

iface="wm0"
echo "Using interface: $iface"

# Backup
cp /etc/rc.conf /etc/rc.conf.bak.fastboot
cp /etc/dhcpcd.conf /etc/dhcpcd.conf.bak.fastboot 2>/dev/null

# rc.conf (with mandatory rc_configured=YES)
#hostname="netbsd"
cat <<EOF >/etc/rc.conf
rc_configured=YES


sshd=YES
sshd_flags="-o UseDNS=no -o PermitRootLogin=yes"

dhcpcd=YES

wscons=NO
ntpd=NO
postfix=NO
wpa_supplicant=NO
apmd=NO
rtsold=NO
avahidaemon=NO
rpcbind=NO
EOF

# Fast DHCP
cat <<EOF >/etc/dhcpcd.conf
interface $iface
noipv4ll
noarp
denyinterfaces lo0
timeout 2
persistent
hostname
option rapid_commit
EOF

# SSHD optimization
if ! grep -q "UseDNS no" /etc/ssh/sshd_config; then
    echo "UseDNS no" >> /etc/ssh/sshd_config
fi

# Quiet boot
if grep -q "menu=Boot" /boot.cfg; then
    sed -i 's/netbsd/netbsd -q/' /boot.cfg 2>/dev/null
fi

# Disable fsck
touch /fastboot

echo "Done. Reboot now."


