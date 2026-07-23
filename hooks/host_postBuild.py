# NetBSD host-side postBuild hook (exec()'d into build.py's globals).
#
# run_hook() runs BOTH sides of a hook point, guest first: by the time this
# executes, hooks/vm_postBuild.sh (dhcpcd -4, DNS, boot.cfg timeout) has
# already run in the guest.
#
# sparc64 10.x ONLY: migrate the system off the wedge-prone cmd646
# IDE disk. QEMU sun4u's CMD646 randomly enters a sustained "lost interrupt"
# wedge under DMA load (QEMU 8.2.2 and 10.2.3 alike; every alternative disk
# path except mptsas1068 is broken -- see the conf comments). The migration:
#
#   reboot 1: the sd0 qcow2 now exists, so build_qemu_args() attaches the
#             mptsas1068 HBA; phase1 (guest) copies the root fs onto sd0a
#             (dump|restore), points its fstab at sd0, and installs the
#             ANYVM kernel (GENERIC + root on sd0a) as wd0:/netbsd.
#   reboot 2: ofwboot loads the ANYVM kernel, so the guest now roots on
#             sd0a; after verifying that, the VM is shut down and the whole
#             IDE work disk is REPLACED host-side by the boot disk that
#             hooks/host_beforeBuild.sh assembled with
#             files/build-sparc64-bootdisk.sh (sun label + FFSv1 +
#             bootblock + ofwboot + ANYVM kernel, ~14MB) -- the exact same
#             artifact the release-files job publishes as
#             <output>-boot.qcow2.zst, so this build verifies the shipped
#             boot disk itself.
#
# main()'s standard post-postBuild reboot then boots the final hybrid
# topology, which also means the package-install phase and everything after
# it already run with root on sd0 -- the build-time wedge windows are gone
# along with the runtime ones. exportOVA() exports the sd0 root disk as the
# main <output>.qcow2.zst asset (the -boot asset ships via release-files,
# NOT from the build matrix).


def _sparc64_hybrid_migrate():
    kernel = wf("netbsd-ANYVM")
    bootdisk = wf("netbsd-%s-sparc64-boot.qcow2" % env("VM_RELEASE"))
    xdisk_name = env("VM_EXTRA_DISK")
    if not xdisk_name:
        log("sparc64 migrate: VM_EXTRA_DISK not set in the conf; aborting")
        sys.exit(1)
    if not os.path.exists(kernel) or not os.path.exists(bootdisk):
        log("sparc64 migrate: %s or %s missing (host_beforeBuild.sh builds "
            "them via files/build-sparc64-bootdisk.sh)" % (kernel, bootdisk))
        sys.exit(1)
    xdisk = wf(xdisk_name)
    must_run(["qemu-img", "create", "-f", "qcow2", xdisk,
              env("VM_DISK_SIZE") or "4G"], "create sd0 disk")

    def _mig_restart():
        if isRunning() == 0 and shutdownVM() != 0:
            log("shutdown error"); sys.exit(1)
        _wait_vm_down(what="sparc64 migrate reboot", poll=5)
        closeConsole()
        if start_and_wait() != 0:
            log("sparc64 migrate: reboot never reached the login prompt")
            sys.exit(1)

    def _guest_script(path, marker):
        with open(path, "rb") as f:
            p = subprocess.run(["ssh", "-o", "SendEnv=VM_RELEASE",
                                env("VM_OS_NAME"), "sh"],
                               stdin=f, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT)
        out = p.stdout.decode("utf-8", "replace")
        log(out[-4000:])
        if marker not in out:
            log("sparc64 migrate: %s did not reach its %s marker"
                % (path, marker))
            sys.exit(1)

    # Reboot so the freshly created sd0 file gets attached (build_qemu_args
    # gates the mptsas1068 HBA on the file existing).
    _mig_restart()
    if not _wait_ssh(restart_cb=_mig_restart):
        log("sparc64 migrate: ssh never came back after attaching sd0")
        sys.exit(1)

    if subprocess.run(["scp", kernel,
                       "%s:/tmp/netbsd.anyvm" % env("VM_OS_NAME")]).returncode != 0:
        log("sparc64 migrate: ANYVM kernel scp failed"); sys.exit(1)

    _guest_script("conf/netbsd-sparc64-migrate-phase1.sh", "ANYVM_MIGRATE1_OK")

    # Reboot: ofwboot still loads wd0:/netbsd, which phase1 just replaced
    # with the ANYVM kernel, so this boot roots on sd0a.
    _mig_restart()
    if not _wait_ssh(restart_cb=_mig_restart):
        log("sparc64 migrate: ssh never came back on the sd0 root")
        sys.exit(1)
    chk = subprocess.run(["ssh", env("VM_OS_NAME"),
                          "df / ; dmesg | grep 'root on'"],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    chk_out = chk.stdout.decode("utf-8", "replace")
    log(chk_out)
    if "sd0a" not in chk_out:
        log("sparc64 migrate: root did not move to sd0a"); sys.exit(1)

    # Root is on sd0a, so the IDE work disk is now just a kernel carrier:
    # shut the guest down and replace the whole disk file with the
    # host-assembled boot disk. main() reboots right after this hook
    # returns (restart_and_wait tolerates the already-down VM), and that
    # boot runs the final hybrid topology: tiny wd0 bootblock -> ofwboot ->
    # ANYVM kernel -> root on sd0a.
    if isRunning() == 0 and shutdownVM() != 0:
        log("shutdown error"); sys.exit(1)
    _wait_vm_down(what="sparc64 boot-disk swap", poll=5)
    closeConsole()
    shutil.copy(bootdisk, wf("%s.qcow2" % env("VM_OS_NAME")))
    log("sparc64 migrate: IDE work disk replaced by the assembled boot disk")


if env("VM_ARCH") == "sparc64" and (env("VM_RELEASE") or "").startswith("10."):
    _sparc64_hybrid_migrate()
