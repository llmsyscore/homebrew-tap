#!/usr/bin/env python3
"""Rewrite every formula's release urls + per-asset sha256 to a given tag.

Usage: bump-formulas.py vX.Y.Z  (run from the tap root; used by bump.yml).
Fetches each asset's published .sha256 and fails loudly on any drift."""
import re
import sys
import urllib.request

RELEASE_BASE = "https://github.com/llmsyscore/llm-systems-manager/releases/download"
# Expected pinned-url count per formula — update when a formula adds/drops assets.
PATHS = {
    "Formula/llm-systems-agent.rb": 3,
    "Formula/llm-systems-manager.rb": 1,
    "Formula/llm-systems-alarm-engine.rb": 1,
}


def main() -> None:
    tag = sys.argv[1]
    assert re.fullmatch(r"v[0-9][0-9A-Za-z.\-]*", tag), tag
    shas: dict[str, str] = {}

    def sha_for(asset: str) -> str:
        if asset not in shas:
            with urllib.request.urlopen(f"{RELEASE_BASE}/{tag}/{asset}.sha256") as r:
                s = r.read().decode().split()[0]
            assert re.fullmatch(r"[0-9a-f]{64}", s), (asset, s)
            shas[asset] = s
        return shas[asset]

    for path, expected_urls in PATHS.items():
        src = open(path).read()
        src = re.sub(r"releases/download/v[0-9][^/]*/", f"releases/download/{tag}/", src)
        # The control-plane tarball embeds the tag in its filename too.
        src = re.sub(r"llm-systems-manager-v[0-9][^/\"]*\.tar\.gz",
                     f"llm-systems-manager-{tag}.tar.gz", src)
        out: list[str] = []
        cur_asset = None
        n_urls = 0
        for line in src.splitlines(keepends=True):
            m = re.search(r'url ".*/releases/download/[^/]+/([^"]+)"', line)
            if m:
                assert cur_asset is None, f"url without sha256 in {path}"
                cur_asset = m.group(1)
                n_urls += 1
            m = re.match(r'^(\s*sha256 ")[0-9a-f]{64}(")\s*$', line)
            if m:
                assert cur_asset, f"sha256 with no preceding url in {path}"
                line = m.group(1) + sha_for(cur_asset) + m.group(2) + "\n"
                cur_asset = None
            out.append(line)
        assert cur_asset is None, f"trailing url without sha256 in {path}"
        assert n_urls == expected_urls, \
            f"{path}: expected {expected_urls} pinned urls, saw {n_urls}"
        open(path, "w").write("".join(out))
    print(f"rewrote {len(PATHS)} formulas to {tag} with {len(shas)} asset checksums")


if __name__ == "__main__":
    main()
