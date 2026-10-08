# Package descriptions and changelogs

Every FreeMixer package has a description that says what it does for a musician or an engineer, and a
changelog that the person updating it sees. This page is how that works for every repository that ships an
RPM or a deb through the workflows of this repository.

## What a user sees

| Where | What |
| --- | --- |
| `dnf info <package>` / `apt show <package>` | the Summary and %description / the Description |
| `dnf updateinfo info` | one advisory per release, with the release's changelog text and a link to its release notes |
| `dnf check-update --changelogs` | the changelog entries of the versions an update brings |
| `apt changelog <package>` | the changelog of the version about to be installed, or of the installed one |
| `apt-listchanges` (when installed) | the changelog of each deb it is about to upgrade, read from the deb itself |
| GitHub release page | the release's entry of `CHANGELOG.md` |

## One source: CHANGELOG.md

Each repository has a `CHANGELOG.md` with one section per version, newest first:

```
## 0.1.5 - 2026-10-07

- What changed for someone who installs the package, in plain words. A bullet may continue on
  lines indented by two spaces.
```

Write for the person updating: what they can do now, what no longer breaks, what to know before they
update. No lane names, task numbers or internal vocabulary; a line a user cannot act on or understand does
not belong. A version is `<version>` or `<version>-<release>` (a repository that bumps the RPM release
without a new version, such as openmixer, writes `0.1.0-14`); without a release the RPM release is 1.

`.github/actions/changelog/changelog.sh` generates everything else from it:

| Command | Output |
| --- | --- |
| `changelog.sh sync` | rewrites the `%changelog` of `packaging/*.spec` and `debian/changelog` |
| `changelog.sh check [-t v<version>]` | fails when either differs from what `sync` writes, when the spec's Version or Release is not the newest entry's, and, with a tag, when the tag is not the newest entry |
| `changelog.sh notes <version>` | the GitHub release notes |

The generated files stay in the repository, so a source tarball builds without the tool, and nobody edits
them by hand: the check refuses a hand edit the same way it refuses a stale file. The author of the entries
is `$CHANGELOG_AUTHOR` (Pau Aliagas by default); the Debian date is the entry's date at 12:00 UTC. Two entries
on one date get a minute each, the older at 12:00 and the newer at 12:01, so lintian sees the newer release as
newer than the one before it.

A repository adopts it by adding `CHANGELOG.md`, running `changelog.sh sync`, and calling the action from
its `ci.yml`:

```yaml
- uses: actions/checkout@v4
- uses: FreeMixer/.github/.github/actions/changelog@v1
```

A release is then: add the version's section to `CHANGELOG.md`, run `changelog.sh sync`, bump the version
files, tag `v<version>`.

## Where the shared workflows enforce it

`build-rpm.yml` and `build-deb.yml` run the check first, before any build minutes: on a tag it refuses a
version with no entry, or a spec or `debian/changelog` that `CHANGELOG.md` does not generate. Their release
job creates the GitHub release with the entry as its notes (it used to list merged pull requests).

## The channel's update metadata

RPM: `publish-rpms/publish-tree.sh` writes an `updateinfo.xml` for every directory that holds binary
packages and merges it into the repository metadata with `modifyrepo_c`, before the metadata is signed.
`updateinfo.py` makes it from the packages themselves: one advisory per source RPM, whose text is the
package's newest `%changelog` entry (the entry named after the package's own version and release). The
channel keeps no extra state, so every publish rewrites the advisories of every release the directory holds
and releases published earlier get theirs. The first release of a package is a `newpackage` advisory, the
others `enhancement`.

deb: `debhelper` puts `debian/changelog` into each package, as `changelog.Debian.gz` (`changelog.gz` for a
native package, which the FreeMixer packages are); that is what `apt-listchanges` and `apt changelog` for
an installed package read, and what lintian requires. `apt changelog` for a version that is not installed
yet asks the `Changelogs:` field of the Release file, so `publish-debs/publish-tree.sh` also writes each
package's changelog to `deb/changelogs/<prefix>/<source>/<source>_<version>_changelog` (a flat repository
has no component in the path) and adds `Changelogs: <base-url>/deb/changelogs/@CHANGEPATH@_changelog` to
every Release file. The `Changes` field of a `.changes` file is `debian/changelog` too.

## Descriptions

The Summary and `%description` of the spec and the `Description` of `debian/control` say what the package is
for and what it gives a person, in two to four sentences: a feature or a sound, not a build detail.
Developer packages (`-devel`, `-dev`) say what they let a developer build and against what. Internal names,
task numbers and how it is built belong in the repository's docs.

## Tests

`tests/changelog.sh` (the generator and each way the check refuses), `tests/updateinfo.sh` (two releases
published, `dnf updateinfo info` and `dnf check-update --changelogs` on a machine that holds the first) and
`tests/deb-changelog.sh` (a package built, published, and `apt changelog` over HTTP) run in `ci.yml`.
