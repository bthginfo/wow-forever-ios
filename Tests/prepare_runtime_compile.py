#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prepare a throwaway package for an iPhoneOS compiler check of Playport's app target."""

import hashlib
from pathlib import Path
import runpy
import subprocess
import sys


runtime, package = (Path(argument).resolve() for argument in sys.argv[1:])
app = runtime / "app"
package.mkdir(parents=True)
sources = package / "Sources"
sources.mkdir()
for source in (app / "Sources").iterdir():
    if source.name != "WinIOS":
        (sources / source.name).symlink_to(source, target_is_directory=source.is_dir())
for directory in app.iterdir():
    if (directory / "Package.swift").is_file():
        (package / directory.name).symlink_to(directory, target_is_directory=True)

# The staging script defines the real driver sources and exact patches for the pinned runtime.
stage = runpy.run_path(str(runtime / "build" / "stages" / "stage-artifacts.py"))
pin, url = next(row.split()[1:3] for row in (runtime / "pins.lock").read_text().splitlines()
                if row.startswith("madeira "))
madeira = package / ".madeira"
subprocess.run(["git", "init", "--quiet", str(madeira)], check=True)
subprocess.run(["git", "-C", str(madeira), "fetch", "--depth=1", url, pin], check=True)
for line in (app / "artifacts.tsv").read_text().splitlines():
    if not line.startswith("source\tWinIOS/"):
        continue
    _, target, size, sha256, _, original, _ = line.split("\t")
    source = original.removeprefix("mythic/")
    data = subprocess.check_output(["git", "-C", str(madeira), "show", f"{pin}:{source}"])
    if len(data) != int(size) or hashlib.sha256(data).hexdigest() != sha256:
        raise ValueError(f"Driver source differs from Playport's recorded input: {target}")
    destination = sources / target
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    if target in stage["PATCHES"]:
        patch_set, strip = stage["PATCHES"][target]
        for patch in stage["series"](patch_set):
            with patch.open("rb") as content:
                subprocess.run(["patch", "--quiet", "--forward", "--fuzz=0", f"-p{strip}",
                                "-d", str(destination.parent)], stdin=content, check=True)

manifest = (app / "Package.swift").read_text()
frameworks = ', "KosmicKrisp", "MesaEGL", "MesaGallium"'
if manifest.count(frameworks) != 1:
    raise ValueError("Unexpected Playport app target at the pinned commit")
manifest = manifest.replace(frameworks, "")
# These binary frameworks are staged for linking and packaging. This build stops at compilation.
manifest += '''
package.products.removeAll { $0.name == "PlayportJIT" }
package.targets.removeAll {
    ["PlayportJIT", "StikJIT", "KosmicKrisp", "MesaEGL", "MesaGallium"].contains($0.name)
}
'''
(package / "Package.swift").write_text(manifest)
