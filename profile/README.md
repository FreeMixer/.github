# FreeMixer

A free, real-time digital mixing console for Linux.

The plugin-hosting pieces the console runs on, [omx-clap-host](https://github.com/FreeMixer/omx-clap-host) and
[plugin-hostd](https://github.com/FreeMixer/plugin-hostd), are separate packages, each released as
signed Fedora RPMs from a version tag.

## Releasing a package

Every package's release workflow is a few lines that call the one reusable workflow of this
repository, `.github/workflows/build-rpm.yml`: push a tag `vX.Y.Z` that matches the `Version:` of the
package's `packaging/*.spec`, and the RPMs are built for x86_64 and aarch64, signed, published into the
`rpm/` tree of the organisation's Pages repository and attached to the GitHub release. Without a tag
the same workflow is a dry run that publishes nothing.
