How the images are built:

Each image is built automatically in the
[anyvm-org/netbsd-builder](https://github.com/anyvm-org/netbsd-builder)
repo's GitHub Actions: it downloads the official NetBSD installer ISO,
boots it in QEMU, drives sysinst unattended over the serial console,
enables ssh, pre-installs the packages listed in the conf, and exports
the installed disk as a compressed qcow2 image.

Upstream install media: current releases from
https://ftp.netbsd.org/pub/NetBSD/ and EOL releases from
https://archive.netbsd.org/pub/NetBSD-archive/.
