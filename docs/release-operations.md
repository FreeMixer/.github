# Release operations

What a caller of `build-rpm.yml` and `build-deb.yml` must grant, and how the parts that only run on a real
release are tested.

## What the calling release.yml grants

A called workflow cannot raise the token of its caller; the `permissions:` inside the reusable workflow only
narrow it. The calling `release.yml` therefore carries, at the top level or on the job that calls the shared
workflow:

```yaml
permissions:
  contents: write   # the GitHub release and its assets
  issues: write     # the issue opened when a release ends without packages
```

Without `issues: write` the `report-failure` job still runs, and ends in an error naming the missing permission
instead of a silent miss.

## Secrets

| Secret | Used for |
| --- | --- |
| `PAGES_TOKEN` | pushing the packages to the Pages repository |
| `OPENMIXER_PACKAGES_SIGNING_KEY`, `RPM_GPG_KEY`, `RPM_GPG_PASSPHRASE` | signing the packages and the index |
| `SITE_GPG_KEY` | signing the commits to the channel |
| `DISPATCH_TOKEN` | the `repository_dispatch` that tells the worker image build about a new package |

`DISPATCH_TOKEN` is the token meant for the dispatch. When it is unset, `PAGES_TOKEN` is tried and the job says
so in a notice; what `PAGES_TOKEN` may do on the dispatch repository is not recorded, so a refusal there is
expected. With neither token the job skips with a notice. The job is `continue-on-error` while nothing listens
for the event, so it never turns a published release red.

`verify-install: false` skips the clean-container install check. The release is then not proven installable,
and the dispatch goes out on the publish alone.

## The lost-race retry of channel-push

Two releases that publish to the same Pages repository can race for the tip of its branch. `channel-push`
repeats a push that lost on the new tip: it resets the checkout, assembles the tree again, signs a new commit
and pushes. The GitHub release assets are copied from the tree after the push, so they are the bytes the
channel serves.

### Local test

`tests/channel-push-race.sh` runs the real push step of the action against a bare git remote whose first push
loses the race to another publish. It checks that the remote ends with both publishes and a signed commit on
top, and that the same race fails the step when no rebuild command is given. It runs in CI as
`channel-push-race`. To sabotage-verify it, change the loop condition in `channel-push/action.yml` so it
always gives up: the test goes red.

### Forced race on a real release

Use a throwaway Pages repository, never the live channel.

1. Make a repository with a `release.yml` that calls the shared workflows with `target-repo` set to the
   throwaway Pages repository, and a small package in it.
2. Push two tags of two packages (or of the rpm and the deb workflows) within a few seconds of each other, so
   both reach `channel-push` together. To make the collision certain, add a short `sleep 40` to a copy of the
   first package's build job so the second one pushes first.
3. In the log of the later run look for `the push to ... lost a race (attempt 1 of 6)`, then
   `published <tag> to ...`.
4. In the Pages repository check that `git log` holds both publishes, that each commit is signed, and that the
   repodata or `InRelease` lists both packages.
5. Download an RPM or DEB from the GitHub release of the retried run and compare its sha256 with the file the
   channel serves.

## openmixer-release, the package that adds the repository

A machine adds the channel by installing `openmixer-release`, as RPM Fusion's machines do with
`rpmfusion-free-release`: a change of baseurl, key or Debian release reaches every machine as an update of that
package. The packaging is `packaging/openmixer-release`; workflow `release-package.yml` builds it and
publishes it.

| | RPM | DEB |
| --- | --- | --- |
| repository | `/etc/yum.repos.d/openmixer.repo`, ids `openmixer` and `openmixer-noarch` | `/etc/apt/sources.list.d/openmixer.sources`, deb822, a link to the source of the system's `VERSION_CODENAME` |
| key | `/etc/pki/rpm-gpg/RPM-GPG-KEY-openmixer`, the channel's `rpm/RPM-GPG-KEY-openmixer` | `/usr/share/keyrings/openmixer-archive-keyring.asc`, the channel's `deb/openmixer.asc` |
| stable name | `rpm/openmixer-release.noarch.rpm` | `deb/openmixer-release.deb` |
| updates from | `fedora/<release>/noarch/` of the tree | `debian/<suite>/all/` of the tree |

The DEB ships one source per Debian release the channel serves (bookworm, trixie) and links the one of the
running system at configure time: the stable `.deb` is one file for every release, and the sources stay
package contents, so an upgrade changes them. A system whose codename the channel does not serve fails the
install. A system upgraded to another Debian release relinks with `dpkg-reconfigure openmixer-release`.

The key is the file the channel serves at build time, read over HTTPS from `www.openmixer.org`, never kept in
this repository: a key added to the channel (channel-keys.sh) reaches machines by the next release of the
package.

To release: bump `Release:` in the spec and add the same version on top of `debian/changelog` (build.sh
refuses a build where the two differ), merge, and push the tag `openmixer-release-<Version>-<Release>`, for
example `openmixer-release-1-2`. Without that tag the workflow is a dry run: both packages are built, each is
installed in a clean container with a package of the channel installed through the repository it adds
(`install-check.sh`), and the unsigned trees with the stable names are attached to the run. A release signs,
publishes into the tree and at the stable names, and checks from a clean fedora:44, bookworm and trixie that
the stable name carries the release and installs.

`add-openmixer` is the action the shared workflows use to add the channel to a build or install-check
container: it installs the stable name from `base-url`.
