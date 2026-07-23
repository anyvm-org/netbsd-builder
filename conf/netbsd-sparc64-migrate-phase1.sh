# Runs INSIDE the NetBSD 10.x sparc64 guest (piped into sh over ssh by
# hooks/host_postBuild.py) while the system still roots on wd0 (cmd646 IDE).
# Copies the live root filesystem onto the mptsas1068 SCSI disk sd0, points
# the copy's fstab at sd0, and installs the ANYVM kernel (root on sd0a) as
# wd0:/netbsd so the NEXT boot roots on sd0a. Verified end-to-end locally
# 2026-07-23 (PoC) before being wired in here.
set -x

# On a blank disk disklabel exits non-zero ("boot block size 0") but still
# prints a usable fictitious label; keep the output and verify it instead.
disklabel sd0 > /tmp/lab 2>/dev/null
grep -q "total sectors:" /tmp/lab || exit 1

# Sun labels want cylinder-aligned partitions (1008 sectors/cylinder on the
# QEMU geometry): a = everything minus swap, b = 520 cylinders (~256MB) swap.
TOT=`awk '/total sectors:/ {print $3}' /tmp/lab`
CYL=1008
TOTC=`expr $TOT / $CYL`
SWAPC=520
ROOTC=`expr $TOTC - $SWAPC`
ROOTSEC=`expr $ROOTC \* $CYL`
SWAPSEC=`expr $SWAPC \* $CYL`
CSEC=`expr $TOTC \* $CYL`
sed -n '1,/partitions:/p' /tmp/lab > /tmp/proto
echo " a: $ROOTSEC 0 4.2BSD 0 0 0" >> /tmp/proto
echo " b: $SWAPSEC $ROOTSEC swap" >> /tmp/proto
echo " c: $CSEC 0 unused 0 0" >> /tmp/proto
cat /tmp/proto
disklabel -R -r sd0 /tmp/proto || exit 1
newfs /dev/rsd0a || exit 1

mount /dev/sd0a /mnt || exit 1
cd /mnt || exit 1
dump -0f - / | restore -rf - || exit 1
rm /mnt/restoresymtable
sed -i.bak 's,/dev/wd0,/dev/sd0,g' /mnt/etc/fstab
rm /mnt/etc/fstab.bak
echo "===== migrated fstab ====="
cat /mnt/etc/fstab

# The dump above copied the pre-migration /netbsd (GENERIC) and the staged
# kernel in /tmp; fix both on the copy, then arm the NEXT boot by replacing
# wd0's /netbsd with the ANYVM kernel (GENERIC stays as /netbsd.generic).
cp /tmp/netbsd.anyvm /mnt/netbsd || exit 1
rm /mnt/tmp/netbsd.anyvm
cp /netbsd /netbsd.generic || exit 1
cp /tmp/netbsd.anyvm /netbsd || exit 1
sync
cd /
umount /mnt || exit 1
echo ANYVM_MIGRATE1_OK
