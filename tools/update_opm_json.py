#!/usr/bin/env python3
"""Regenerate update_FpIdn.json - the OPM external update manifest.

The manifest's Version must always equal the version of the lpk that ships
inside the archive it points to, otherwise OPM keeps offering the same
"update" forever. This script is the single place that derives the manifest
from fpidn_rt.lpk. CI runs it on every 'v*' tag push (see
.github/workflows/opm-update.yml) and commits the result, so a release is:
bump the lpk version, tag v<version>, push.

InternalVersion is derived from the version digits (no separate counter to
keep in sync); it only matters together with ForceNotify, which we do not
use.

Usage:
  update_opm_json.py [--expect-tag vX.Y.Z.W] [--print-version]
"""
import json
import os
import sys
import xml.etree.ElementTree as ET

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LPK = os.path.join(REPO, "fpidn_rt.lpk")
OUT = os.path.join(REPO, "update_FpIdn.json")
SLUG = "al-muhandis/fp-idn"
LPK_NAME = "fpidn_rt.lpk"


def lpk_version():
    root = ET.parse(LPK).getroot()
    v = root.find("./Package/Version")
    if v is None:
        sys.exit("no Package/Version element in " + LPK)

    def attr(name):
        return int(v.get(name, "0"))

    return attr("Major"), attr("Minor"), attr("Release"), attr("Build")


def build_text(major, minor, release, build):
    version = "%d.%d.%d.%d" % (major, minor, release, build)
    tag = "v" + version
    internal = major * 1000000 + minor * 10000 + release * 100 + build
    return (
        "{\r\n"
        "  \"UpdatePackageData\" : {\r\n"
        "    \"DisableInOPM\" : false,\r\n"
        "    \"DownloadZipURL\" : \"https://github.com/%s/archive/refs/tags/%s.zip\",\r\n"
        "    \"Name\" : \"%s.zip\"\r\n"
        "  },\r\n"
        "  \"UpdatePackageFiles\" : [\r\n"
        "    {\r\n"
        "      \"ForceNotify\" : false,\r\n"
        "      \"InternalVersion\" : %d,\r\n"
        "      \"Name\" : \"%s\",\r\n"
        "      \"Version\" : \"%s\"\r\n"
        "    }\r\n"
        "  ]\r\n"
        "}\r\n"
    ) % (SLUG, tag, tag, internal, LPK_NAME, version)


def main():
    argv = sys.argv[1:]
    expect_tag = argv[argv.index("--expect-tag") + 1] if "--expect-tag" in argv else None
    print_version = "--print-version" in argv

    major, minor, release, build = lpk_version()
    version = "%d.%d.%d.%d" % (major, minor, release, build)
    if print_version:
        print(version)
        return
    if expect_tag:
        tag = expect_tag[1:] if expect_tag.startswith("v") else expect_tag
        if tag != version:
            sys.exit("tag %s does not match lpk version %s - fix the lpk "
                     "or the tag before releasing" % (expect_tag, version))

    new = build_text(major, minor, release, build).encode("ascii")
    old = open(OUT, "rb").read() if os.path.exists(OUT) else None
    if old == new:
        print("manifest already up to date:", version)
        return
    with open(OUT, "wb") as f:
        f.write(new)
    print("updated", os.path.relpath(OUT, REPO), "->", version)
    if old is not None:
        json.loads(new.decode("ascii"))  # sanity: still valid JSON


if __name__ == "__main__":
    main()
