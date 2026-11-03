<!-- SPDX-License-Identifier: GPL-3.0-or-later
     Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com> -->
# FreeMixer/.github

Organisation defaults and the reusable package release workflows.

## Releasing a package

Every package's release workflow is a few lines that call the one reusable workflow of this
repository, `.github/workflows/build-rpm.yml`: push a tag `vX.Y.Z` that matches the `Version:` of the
package's `packaging/*.spec`, and the RPMs are built for x86_64 and aarch64, signed, published into the
`rpm/` tree of the organisation's Pages repository and attached to the GitHub release. Without a tag
the same workflow is a dry run that publishes nothing.

## Adding the repository

A machine adds the channel by installing `openmixer-release` (`packaging/openmixer-release`, released by
`.github/workflows/release-package.yml` on a tag `openmixer-release-<Version>-<Release>`):

    sudo dnf install https://www.openmixer.org/rpm/openmixer-release.noarch.rpm
    curl -fsSLO https://www.openmixer.org/deb/openmixer-release.deb && sudo apt install ./openmixer-release.deb

`docs/release-operations.md` says what it installs and how it is released.

## Versions

The checks and builds every repository runs are reusable workflows here, and a repository keeps no copy of
them: `public-sources-check.yml` (commit messages, private references, and no local copy of either, the
commit-msg hook being `.github/actions/commit-message-check/commit-msg` byte for byte; and, in a public repository,
no dated document, no dated folder and no folder of evidence or notes), `ci-node.yml`, `ci-c.yml`,
`fuzz.yml`, `release-c-lib.yml` (RPMs then DEBs) and `release-npm.yml` (trusted publishing). Each documents its
inputs at its top. A repository whose every tracked file carries its licence runs `.github/actions/spdx-check`: the
rule is the format of the file, a format with no comment syntax carries no header, and there is no list of files.

Call the shared workflows and actions by the `v1` tag, never by `main`:

    uses: FreeMixer/.github/.github/workflows/build-rpm.yml@v1

`v1` moves on compatible releases, so a repository on `v1` picks up fixes and additions without an edit.
`v1.0.0` and every other full version tag never move. A breaking change gets a new major tag, `v2`.
The shared workflows call their own actions at `v1` too, so a pinned caller runs one consistent version.

## Wave branches

Work that spans repositories lands on a `dedupe/all` branch of each, and a pull request into one builds on its
siblings' same branch, which the channel does not carry yet. `.github/actions/wave-deps` takes the siblings a
repository builds on and, on a pull request into `dedupe/all` or a push to it, builds each from its `dedupe/all` (as
the minor the wave releases) into a local package repository that dnf and apt then prefer over the channel; the
builddep and install steps after it are unchanged. Every other run keeps the channel's releases. The builds are
cached by the siblings' commits. The action's top says where it goes; `tests/wave-deps.sh` checks the version it
builds at and when it switches on.

## Why we pin

`pins.txt` names each outside source the packages are built from by its exact commit, not by a branch or a
version name. A version name does not say which bytes you have; a commit does. So:

- Every package we publish can be traced back to the exact upstream commit it was built from.
- CI, the build machines and a developer's desk all build the same thing; nothing drifts when upstream moves.
- A change of dependency is one reviewed line here, with its changelog entry, so you can see when and why it moved.
- mod-host is not pinned here: `packaging/mod-host` carries the audinux spec and the upstream pull requests it
  applies, one patch file per pull request, until audinux ships them (`docs/mod-host-carried-patches.md`).

- pugl and nanovg, which neither Fedora nor Debian package, are pinned here and built by `packaging/pugl`,
  `packaging/nanovg` (the RPMs, `actions/pinned-rpms`) and `actions/deb-deps/pugl`, `nanovg` (the DEBs); a spec
  whose `commit0` is not the pin is refused. NanoVG ships no library build, so `packaging/nanovg/overlay/meson.build`
  is laid on its source for both. omx-panel's renderer builds its window against them.

A published version is never rebuilt with new bytes. To change what goes in, move the pin and bump the version.
