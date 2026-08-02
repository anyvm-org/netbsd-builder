#!/usr/bin/env python3
# Print the newest NetBSD release version, e.g. "11.0". Empty output means
# "nothing detected" and is not an error; a non-zero exit means detection
# itself is broken (network error, HTTP error, or a page that no longer
# matches the expected shape) and must be reported by the caller, never
# swallowed. A failure must NEVER print a plausible-but-wrong version --
# the version is only printed after every step below has succeeded.
#
# Source of truth: https://ftp.netbsd.org/pub/NetBSD/
# (conf/netbsd-*.conf's VM_ISO_LINK / VM_VHD_LINK all live under
# "NetBSD-<release>/" directories at this same top level, e.g.
#   ".../NetBSD-11.0_RC7/images/NetBSD-11.0_RC7-amd64-dvd.iso").
#
# Fetched and confirmed by hand (2026-07-26): the directory is an
# HTML-table autoindex, one row per entry, e.g.
#   <a href="NetBSD-10.0/">NetBSD-10.0/</a>
#   <a href="NetBSD-10.1/">NetBSD-10.1/</a>
#   <a href="NetBSD-11.0_RC6/">NetBSD-11.0_RC6/</a>
#   <a href="NetBSD-11.0_RC7/">NetBSD-11.0_RC7/</a>
#   <a href="NetBSD-8.3/">NetBSD-8.3/</a>
# alongside non-release entries that never look like "NetBSD-X.Y[_RCn]/":
# NetBSD-archive/, NetBSD-current/, NetBSD-daily/, NetBSD-release-9/,
# NetBSD-release-10/, NetBSD-release-11/ (branch dirs, not tagged release
# dirs), README, security/, packages/, etc. None of those has a digit
# immediately after "NetBSD-", so the pattern already excludes them.
#
# RELEASE CANDIDATES ARE DELIBERATELY NOT REPORTED. NetBSD 11.0 has never
# had a final "NetBSD-11.0/" directory cut -- only dated RC dirs ("_RC6",
# "_RC7") -- and conf/netbsd-11.0*.conf nonetheless pins the RC7 URL under
# VM_RELEASE=11.0. That was a MAINTAINER decision (NetBSD kept 11.0 in
# perpetual RC status, so the latest RC was adopted and the "_RCn" suffix
# dropped from the release tag), and it is recorded in the confs, not
# something this hook should re-derive.
#
# An earlier version of this pattern stripped "_RC<n>" and so reported a
# bare "11.1" the day "NetBSD-11.1_RC1/" appeared -- months before any
# 11.1 exists. The watcher would then try to land 11.1 confs every night,
# and every night the URL gate would reject them (the 11.0 template's URL
# carries the literal "11.0_RC7", which substitutes to a "11.1_RC7" that
# was never published), leaving a permanently red daily workflow.
# Matching final release directories only means the hook stays quiet
# through the entire RC cycle and speaks once, when a real release lands.
#
# When the final directory eventually appears for a release whose confs
# were pinned to RC media (as happened to 11.0 on 2026-08), watch.py's
# refresh path handles it: the hook reports the final version, decide()
# sees the existing confs still carry an RC token in their URLs, and the
# URLs are rewritten to the final media behind the same HEAD gate. With
# the confs on final URLs, the NEXT release (11.1) also derives cleanly
# by plain substitution -- the RC-era "has to be added by hand" caveat
# died with the RC pins.
#
# stdlib only (urllib.request, re, sys, os) -- no external dependencies.

import os
import re
import sys
import urllib.request

URL = "https://ftp.netbsd.org/pub/NetBSD/"
TIMEOUT = 60
USER_AGENT = "anyvm-org-upstream-watcher/1.0"

# Final release directories only: "NetBSD-X.Y/". An "_RC<n>" (or any
# other) suffix makes the name not match, which is the point -- see the
# release-candidate note in the header.
PATTERN = re.compile(r'href="NetBSD-(\d+\.\d+)/"')


def resolve_natural_key():
    """Return the engine's own natural_key, or fail loudly.

    watch.yml clones base-builder INTO the builder repo root, so at
    detection time it sits at "base-builder/" (relative to this hook's
    cwd, the builder repo root). A local checkout instead has it as a
    sibling, "../base-builder". Try both, in that order.

    There is deliberately NO local fallback copy. Ordering must be the
    single rule the engine uses -- a per-hook duplicate would have to be
    kept in sync by hand across every builder and would drift silently,
    and a hook that ranks versions differently from watch.py is worse
    than one that refuses to run. Both real contexts (CI and a local
    sibling checkout) always provide base-builder, so an ImportError here
    means the environment is wrong: report it as broken detection rather
    than guessing an order.
    """
    for candidate in ("base-builder", os.path.join("..", "base-builder")):
        if not os.path.isdir(candidate):
            continue
        path = os.path.abspath(candidate)
        if path not in sys.path:
            sys.path.insert(0, path)
        try:
            import gendata
            return gendata.natural_key
        except ImportError:
            continue
    raise ImportError(
        "base-builder/gendata.py not importable from %s; expected it at "
        "./base-builder (CI) or ../base-builder (local checkout)"
        % os.getcwd())


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read().decode("utf-8", "replace")


def main():
    try:
        key = resolve_natural_key()
    except ImportError as e:
        sys.stderr.write("upstream_check: %s\n" % e)
        return 1
    try:
        html = fetch(URL)
    except Exception as e:
        sys.stderr.write("upstream_check: fetch of %s failed: %s\n"
                         % (URL, e))
        return 1
    versions = PATTERN.findall(html)
    if not versions:
        sys.stderr.write("upstream_check: no NetBSD-X.Y release directory "
                         "found in %s; page shape may have changed\n" % URL)
        return 1
    newest = sorted(set(versions), key=key)[-1]
    print(newest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
