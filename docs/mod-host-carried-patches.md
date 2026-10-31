# mod-host: the patches we carry until audinux ships them

plugin-hostd and omx-clap-host link `libmod-host-protocol.so.0`, the socket and protocol library of mod-host. The
library and several fixes we need exist only as pull requests to mod-host. audinux packages mod-host for Fedora
and takes our pull requests as patches; a release of ours does not wait for it. Until audinux ships them, this
repository carries the packaging and builds the packages itself.

## What is carried, and where

`packaging/mod-host/` holds the audinux spec as proposed in
[audinux/fedora-spec#94](https://github.com/audinux/fedora-spec/pull/94), its service file, and one patch per
upstream pull request. Each `Patch` line of the spec has the URL of its pull request above it, and the patch file
starts with the same URL. The newest three are:

- [mod-audio/mod-host#112](https://github.com/mod-audio/mod-host/pull/112): trimming spaces no longer reads
  before the start of an empty command.
- [mod-audio/mod-host#113](https://github.com/mod-audio/mod-host/pull/113): socket input is split into
  NUL-terminated commands. A command of exactly the buffer size (1024 bytes) no longer hangs, several commands
  in one read all run, and a command split over several reads runs once.
- [FreeMixer/mod-host#12](https://github.com/FreeMixer/mod-host/pull/12) (`mod-host-bind.patch`): the socket and feedback
  ports listen on 127.0.0.1 instead of every address of the machine. `socket_set_bind_address()` before
  `socket_start()`, `mod-host -b <address>` or `MOD_DEVICE_HOST_BIND_ADDRESS` widens it. The workers plugin-hostd starts
  (mod-host, omx-clap-host) call `socket_start()` and take the default. This is not an upstream pull request yet.
- [mod-audio/mod-host#116](https://github.com/mod-audio/mod-host/pull/116): the command table holds 128 commands, and
  `protocol_add_command` refuses one past them with -1 and names it on stderr. It held 64 and dropped the rest in
  silence: omx-clap-host's 65th registration was `quit`. audinux/fedora-spec#94 (merged 2026-10-21, Release 12)
  does not carry it; [audinux/fedora-spec#95](https://github.com/audinux/fedora-spec/pull/95) proposes it as
  Release 13.

The source is the upstream commit the spec names, fetched from mod-audio/mod-host. No fork is built: the
linuxnow branches are where the pull requests are staged, nothing more.

One directory feeds every build, so the RPMs, the DEBs and the source builds in CI carry the same code:

| build | how | where it is used |
|---|---|---|
| RPMs `mod-host`, `mod-host-protocol`, `mod-host-protocol-devel` | `actions/mod-host-rpms` runs `rpmbuild` on the spec | `build-rpm.yml` (BuildRequires), `mod-host-protocol-rpm.yml` (publishes to the channel) |
| DEBs `libmod-host-protocol0`, `libmod-host-protocol-dev` | `actions/deb-deps` lays out the source with `prepare-source.sh`, then `dpkg-buildpackage` with `actions/deb-deps/mod-host-protocol/` | `build-deb.yml` (Build-Depends), `mod-host-protocol-deb.yml` (publishes to the channel) |
| library in a prefix | `actions/mod-host-protocol` runs `prepare-source.sh` and `make lib install-lib` | CI of plugin-hostd and omx-clap-host |

Every one of them installs the library and then runs `packaging/mod-host/framing-test.sh`, which compiles
`framing-test.c` against the installed headers and library and sends it a command of exactly 1024 bytes, two
commands in one write and one command in two writes. A library without #113 fails it, so no package and no CI
build can go out without the fix. It then builds `commands-test.c` and registers 65 commands, which a library
without the protocol-max-commands patch refuses (or which does not build against its header). It then builds
`bind-check.c`, starts the ports the way a worker does and connects to them from 127.0.0.1, 127.0.0.2 and an address
off the loopback when the machine has one: only the first may be reached. `tests/mod-host-carried.sh` (the `mod-host-carried` job of `ci.yml`) also runs
the tests the two pull requests bring, then takes the source part of each fix out again: without #113 the framing
test must fail, without #112 its AddressSanitizer test must fail.

The packages are published by the `mod-host-protocol-rpm.yml` and `mod-host-protocol-deb.yml` workflows, run by
hand on main with `publish` set. GitHub Actions builds and signs them; nothing is published from a desk.

## Versions

RPM: Version is the spec's, `0.10.6.f14a230`. Release is `11.3`, and the channel build appends `.omx`, the suffix
of every package openmixer rebuilds, so the published packages are `0.10.6.f14a230-11.3.omx.fc44`. The channel's
earlier builds carry `.fmx`; RPM compares alphabetic segments as strings, so `omx` sorts above `fmx` and the omx
build upgrades the fmx build of the same Release. RPM orders them like this:

| package | sorts |
|---|---|
| `11.fmx.fc44`, an earlier channel build, without #112/#113 | below ours |
| `11.fc44`, audinux today, without #112/#113 | below ours |
| `11.1.fmx.fc44`, an earlier channel build, without the protocol-max-commands patch | below ours |
| `11.1.omx.fc44`, an earlier channel build, without the protocol-max-commands patch | below ours |
| `11.2.omx.fc44`, an earlier channel build, without the bind-address patch | below ours |
| `11.3.omx.fc44`, ours | |
| `12.fc44`, audinux once #94 is merged | above ours, and replaces it |

PR #94 proposes Release 12. Our 11.3 sits below it on purpose: the day audinux publishes 12, a machine with both
repositories updates to audinux's package and ours is never chosen again. No Epoch is used: an Epoch would win
over audinux for good. `ci.yml` checks each of these comparisons with `rpm.vercmp`. #94 does not carry the
protocol-max-commands patch, so audinux's 12 holds 64 commands again: omx-clap-host stays within 64 for that
reason. audinux/fedora-spec#95 adds the patch as Release 13. #94 does not carry the bind-address patch either: a worker
running on audinux's 12 listens on every address again, so plugin-hostd keeps the floor on our build until the
patch is in the library that is installed.

DEB: `0.1.0-8~omx`, after the published `0.1.0-5`, `0.1.0-6~fmx`, `0.1.0-6~omx` and `0.1.0-7~omx` (without the
bind-address patch). A tilde sorts below anything, so `0.1.0-8~omx` sits above `0.1.0-7~omx` and below a
plain `0.1.0-8`. Debian has no audinux, so these packages stay ours until
Debian or upstream carries the library.

## What plugin-hostd requires

A floor, nothing more:

- spec: `Requires: mod-host-protocol%{?_isa} >= 0.10.6.f14a230-11.1`. Our `11.1.omx` meets it (`11.1.omx`
  sorts above `11.1`), as do our earlier `11.1.fmx` and audinux's `12`; audinux's `11` and our earlier `11.fmx` do
  not.
- debian/control: `Depends: libmod-host-protocol0 (>= 0.1.0-6~fmx)`. Our `0.1.0-8~omx` meets it, and so do the
  earlier `0.1.0-7~omx`, `0.1.0-6~omx` and `0.1.0-6~fmx`.

The RPM floor names the commit in the Version, because that is how the audinux spec writes it. If audinux moves to
a newer upstream commit, its Version changes and the floor must be checked again (see below).

## When audinux merges #94

1. Check the merged spec still has Release 12 (or higher) at Version `0.10.6.f14a230`, and that the audinux build
   for fc44 is published. Confirm with `rpm.vercmp` that it sorts above `0.10.6.f14a230-11.3.omx.fc44`.
2. Stop building our RPMs: `actions/mod-host-rpms` installs audinux's `mod-host-protocol-devel` from the audinux
   repository instead of running `rpmbuild` on `packaging/mod-host/mod-host.spec`, and its framing test stays.
3. Leave `mod-host-protocol-rpm.yml` unrun from then on, and delete it. The published `11.1.fmx` and `11.1.omx` packages stay in
   the channel (a published NEVRA is never taken back); audinux's `12` supersedes them.
4. If audinux's Version is no longer `0.10.6.f14a230`, set plugin-hostd's (and omx-clap-host's) RPM floor to the
   first audinux NEVRA that carries #112 and #113.
5. Keep `packaging/mod-host` for the DEBs and the source builds in CI: `prepare-source.sh` reads the upstream
   commit and the patch list from the spec. They go when mod-audio/mod-host merges the pull requests: move the
   commit to one that contains them, delete each patch it contains, and move the DEB floor to the first DEB
   built from it.
