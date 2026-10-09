#!/usr/bin/python3
"""Write updateinfo.xml for the binary RPMs of one directory of a dnf tree.

    updateinfo.py <rpm dir> <output file>

One advisory per release (per source RPM), made from the packages themselves: its text is the newest
%changelog entry of the RPM, made from git (docs/packaging-changelog.md).
The channel keeps no other state, so every publish regenerates the advisories of every release the
directory holds, and a release published before this existed gets its advisory the next time anything is
published. `dnf updateinfo info` prints them; modifyrepo_c merges the file into the repository metadata.
"""
import os
import re
import sys
from datetime import datetime, timezone
from xml.sax.saxutils import escape, quoteattr

import rpm

DIST = re.compile(r"\.(fc|el)\d+.*$")


def header(path):
    ts = rpm.TransactionSet()
    ts.setVSFlags(rpm._RPMVSF_NOSIGNATURES | rpm._RPMVSF_NODIGESTS)
    with open(path, "rb") as f:
        return ts.hdrFromFdno(f.fileno())


def text(value):
    return value.decode() if isinstance(value, bytes) else (value or "")


def entry_for(h, version_release):
    """The changelog entry named <version>-<release>, else the newest."""
    names = h[rpm.RPMTAG_CHANGELOGNAME] or []
    texts = h[rpm.RPMTAG_CHANGELOGTEXT] or []
    times = h[rpm.RPMTAG_CHANGELOGTIME] or []
    for i, name in enumerate(names):
        if text(name).endswith(" - " + version_release):
            return text(texts[i]), times[i], len(names)
    if names:
        return text(texts[0]), times[0], len(names)
    return "", int(h[rpm.RPMTAG_BUILDTIME]), 0


def main(directory, out):
    releases = {}
    for name in sorted(os.listdir(directory)):
        if not name.endswith(".rpm") or name.endswith(".src.rpm"):
            continue
        h = header(os.path.join(directory, name))
        src = text(h[rpm.RPMTAG_SOURCERPM])
        if not src:
            continue
        releases.setdefault(src, []).append((name, h))

    items = []
    for src in sorted(releases):
        members = releases[src]
        first = members[0][1]
        version = text(first[rpm.RPMTAG_VERSION])
        release = text(first[rpm.RPMTAG_RELEASE])
        srcname = src[: src.rindex("-", 0, src.rindex("-"))]
        body, when, count = entry_for(first, version + "-" + DIST.sub("", release))
        issued = datetime.fromtimestamp(when, timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
        dist = re.search(r"\.(fc|el)(\d+)", release)
        short = (dist.group(1) + dist.group(2)) if dist else "fedora"
        rel = ("Fedora " + dist.group(2)) if dist and dist.group(1) == "fc" else "Fedora"
        url = text(first[rpm.RPMTAG_URL])
        kind = "newpackage" if count == 1 else "enhancement"
        ident = "FMX-" + src[: -len(".src.rpm")]
        lines = [
            '  <update from="FreeMixer" status="stable" type="%s" version="1">' % kind,
            "    <id>%s</id>" % escape(ident),
            "    <title>%s</title>" % escape("%s %s" % (srcname, version)),
            '    <issued date="%s"/>' % issued,
            '    <updated date="%s"/>' % issued,
            "    <rights>GPL-3.0-or-later</rights>",
            "    <release>%s</release>" % escape(rel),
            "    <pushcount>1</pushcount>",
            "    <severity>None</severity>",
            "    <summary>%s</summary>" % escape(text(first[rpm.RPMTAG_SUMMARY])),
            "    <description>%s</description>" % escape(body.strip()),
        ]
        if url.startswith("https://github.com/"):
            lines += [
                "    <references>",
                "      <reference href=%s id=%s type=\"self\" title=\"Release notes\"/>"
                % (quoteattr(url.rstrip("/") + "/releases/tag/v" + version), quoteattr("v" + version)),
                "    </references>",
            ]
        else:
            lines.append("    <references/>")
        lines += ["    <pkglist>", '      <collection short="%s">' % escape(short), "        <name>FreeMixer</name>"]
        for fname, h in members:
            epoch = h[rpm.RPMTAG_EPOCH]
            lines.append(
                '        <package name=%s epoch="%d" version=%s release=%s arch=%s src=%s>'
                % (
                    quoteattr(text(h[rpm.RPMTAG_NAME])),
                    epoch if epoch is not None else 0,
                    quoteattr(version),
                    quoteattr(release),
                    quoteattr(text(h[rpm.RPMTAG_ARCH])),
                    quoteattr(src),
                )
            )
            lines.append("          <filename>%s</filename>" % escape(fname))
            lines.append("        </package>")
        lines += ["      </collection>", "    </pkglist>", "  </update>"]
        items.append("\n".join(lines))

    with open(out, "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<updates>\n' + "\n".join(items) + ("\n" if items else "") + "</updates>\n")
    print("updateinfo: %d advisories for %s" % (len(items), directory))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: updateinfo.py <rpm dir> <output file>")
    main(sys.argv[1], sys.argv[2])
