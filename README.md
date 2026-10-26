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

Call the shared workflows and actions by the `v1` tag, never by `main`:

    uses: FreeMixer/.github/.github/workflows/build-rpm.yml@v1

`v1` moves on compatible releases, so a repository on `v1` picks up fixes and additions without an edit.
`v1.0.0` and every other full version tag never move. A breaking change gets a new major tag, `v2`.
The shared workflows call their own actions at `v1` too, so a pinned caller runs one consistent version.

## Why we pin

`pins.txt` names each outside source the packages are built from by its exact commit, not by a branch or a
version name. A version name does not say which bytes you have; a commit does. So:

- Every package we publish can be traced back to the exact upstream commit it was built from.
- CI, the build machines and a developer's desk all build the same thing; nothing drifts when upstream moves.
- A change of dependency is one reviewed line here, with its changelog entry, so you can see when and why it moved.
- mod-host is not pinned here: `packaging/mod-host` carries the audinux spec and the upstream pull requests it
  applies, one patch file per pull request, until audinux ships them (`docs/mod-host-carried-patches.md`).

A published version is never rebuilt with new bytes. To change what goes in, move the pin and bump the version.
