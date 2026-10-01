# FreeMixer/.github

Organisation defaults and the reusable package release workflows.

## Releasing a package

Every package's release workflow is a few lines that call the one reusable workflow of this
repository, `.github/workflows/build-rpm.yml`: push a tag `vX.Y.Z` that matches the `Version:` of the
package's `packaging/*.spec`, and the RPMs are built for x86_64 and aarch64, signed, published into the
`rpm/` tree of the organisation's Pages repository and attached to the GitHub release. Without a tag
the same workflow is a dry run that publishes nothing.

## Why we pin

`pins.txt` names each outside source the packages are built from by its exact commit, not by a branch or a
version name. A version name does not say which bytes you have; a commit does. So:

- Every package we publish can be traced back to the exact upstream commit it was built from.
- CI, the build machines and a developer's desk all build the same thing; nothing drifts when upstream moves.
- A change of dependency is one reviewed line here, with its changelog entry, so you can see when and why it moved.
- What we ship is what we posted upstream: the mod-host pin is the tag of the patch set in our pull requests.

A published version is never rebuilt with new bytes. To change what goes in, move the pin and bump the version.
