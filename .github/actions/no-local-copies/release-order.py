#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
# release-order.py WORKFLOW...
#
# A release is one wave: a job that publishes DEBs (calls build-deb.yml) needs every job that builds RPMs (calls
# build-rpm.yml), and runs only when they passed. It carries no `if` at all, or one that still demands
# needs.<rpm>.result == 'success'; `!cancelled()`, `always()` and `failure()` on their own let a DEB ship after a
# red RPM job. A workflow with no DEB job is not judged.
import re
import sys

import yaml

bad = 0
for path in sys.argv[1:]:
    doc = yaml.safe_load(open(path)) or {}
    jobs = doc.get("jobs") or {}
    rpm = [n for n, j in jobs.items() if "build-rpm.yml" in str((j or {}).get("uses", ""))]
    for name, job in jobs.items():
        job = job or {}
        if "build-deb.yml" not in str(job.get("uses", "")) or not rpm:
            continue
        needs = job.get("needs") or []
        needs = [needs] if isinstance(needs, str) else list(needs)
        cond = str(job.get("if", "")) if "if" in job else ""
        for r in rpm:
            if r not in needs:
                print(f"release-order: {path}: job {name} publishes DEBs without needs: {r}", file=sys.stderr)
                bad = 1
            elif cond and not re.search(r"needs\.%s\.result\s*==\s*'success'" % re.escape(r), cond):
                print(f"release-order: {path}: job {name} has an if ({cond.strip()}) that lets it run after a failed {r}",
                      file=sys.stderr)
                bad = 1
sys.exit(bad)
