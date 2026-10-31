<img src="openmixer-logo.svg" alt="openmixer" width="330">

# OpenMixer

**openmixer** is a free, real-time digital mixing console for Linux: a live mixer
you run on a PC, with a web UI on any tablet and hardware control surfaces.
→ https://www.openmixer.org

## What you can install

Each row is a piece you can use without the rest, with a badge that links to its latest release. Add the repository ([Install](#install))
and install by name; a dash means the piece does not ship in that form.

| Piece | Version | What it gives you | Fedora | Debian / Raspberry Pi OS | npm |
|---|---|---|---|---|---|
| [plugin-hostd](https://github.com/FreeMixer/plugin-hostd) | [![release](https://img.shields.io/github/v/release/FreeMixer/plugin-hostd?label=)](https://github.com/FreeMixer/plugin-hostd/releases/latest) | CLAP and LV2 plugins, each format in a native host, in worker processes behind one mod-host socket; a crash restarts only that worker | `plugin-hostd` | `plugin-hostd` | - |
| [omx-clap-core](https://github.com/FreeMixer/omx-clap-core) | [![release](https://img.shields.io/github/v/release/FreeMixer/omx-clap-core?label=)](https://github.com/FreeMixer/omx-clap-core/releases/latest) | `omx-clap-host`, a headless CLAP and LV2 host that speaks mod-host's protocol, one JACK client per plugin; the CLAP hosting library; the LV2 adapter library | `omx-clap-host`, `omx-clap-core`, `omx-clap-core-devel`, `omx-clap-lv2-devel` | `omx-clap-host`, `libomx-clap-core-dev`, `libomx-clap-lv2-dev` | - |
| [omx-panel](https://github.com/FreeMixer/omx-panel) | [![release](https://img.shields.io/github/v/release/FreeMixer/omx-panel?label=)](https://github.com/FreeMixer/omx-panel/releases/latest) | a panel for any LV2 or CLAP plugin without drawing one: MOD GUI, controller pages, host layout | `omx-panel` | `omx-panel` | `@openmixer/omx-panel` |
| [omx-plugins](https://github.com/FreeMixer/omx-plugins) | [![release](https://img.shields.io/github/v/release/FreeMixer/omx-plugins?label=)](https://github.com/FreeMixer/omx-plugins/releases/latest) | our own effects as CLAP and LV2 plugins | `omx-plugins`, `omx-plugins-clap`, `omx-plugins-lv2` | `omx-plugins` | - |
| [omx-dsp](https://github.com/FreeMixer/omx-dsp) | [![release](https://img.shields.io/github/v/release/FreeMixer/omx-dsp?label=)](https://github.com/FreeMixer/omx-dsp/releases/latest) | the DSP kernels the plugins and the console share, a C library | `omx-dsp-devel` | `libomxdsp-dev` | - |
| [omx-contract](https://github.com/FreeMixer/omx-contract) | [![release](https://img.shields.io/github/v/release/FreeMixer/omx-contract?label=)](https://github.com/FreeMixer/omx-contract/releases/latest) | the declarations every piece agrees on: parameters, units, limits, codes | `omx-contract-devel` | `libomx-contract-dev` | `@openmixer/omx-contract` |
| [plugin-qualify](https://github.com/FreeMixer/plugin-qualify) | [![release](https://img.shields.io/github/v/release/FreeMixer/plugin-qualify?label=)](https://github.com/FreeMixer/plugin-qualify/releases/latest) | checks a plugin for real-time safety and cost before a stage runs it | `plugin-qualify` | `plugin-qualify` | - |
| [libreac](https://github.com/FreeREAC/libreac) and [reac-pw](https://github.com/FreeREAC/reac-pw) | [![release](https://img.shields.io/github/v/release/FreeREAC/libreac?label=)](https://github.com/FreeREAC/libreac/releases/latest) [![release](https://img.shields.io/github/v/release/FreeREAC/reac-pw?label=)](https://github.com/FreeREAC/reac-pw/releases/latest) | the REAC protocol and its PipeWire bridge, for Roland stageboxes | `libreac`, `reac-pw` | `libreac-dev`, `reac-pw` | - |
| [libdiginet](https://github.com/FreeMixer/libdiginet) | [![release](https://img.shields.io/github/v/release/FreeMixer/libdiginet?label=)](https://github.com/FreeMixer/libdiginet/releases/latest) | the Digidesign Control&#124;24 and ProControl surface protocol over Ethernet, a C library with a probe tool | `libdiginet`, `diginet-tools` | `libdiginet-dev`, `diginet-tools` | - |
| [libsurface](https://github.com/FreeMixer/libsurface) | [![release](https://img.shields.io/github/v/release/FreeMixer/libsurface?label=)](https://github.com/FreeMixer/libsurface/releases/latest) | the device behaviour every motorised control surface shares (motor faders that never fight the hand, touch, banking, repaint, meters), a C library with a Control&#124;24 module over libdiginet and a Mackie module over libmackie | `libsurface`, `libsurface-devel`, `libsurface-diginet`, `libsurface-diginet-devel`, `libsurface-mackie`, `libsurface-mackie-devel`, `surface-c24` | `libsurface0`, `libsurface-dev`, `libsurface-diginet0`, `libsurface-diginet-dev`, `libsurface-mackie0`, `libsurface-mackie-dev`, `surface-c24` | - |
| [libmackie](https://github.com/FreeMixer/libmackie) | [![release](https://img.shields.io/github/v/release/FreeMixer/libmackie?label=)](https://github.com/FreeMixer/libmackie/releases/latest) | Mackie Control and HUI byte for byte: the MCU codec for an X-Touch or any MCU surface, a C library with no I/O | `libmackie`, `libmackie-devel` | `libmackie0`, `libmackie-dev` | - |
| [mod-host](https://github.com/FreeMixer/mod-host) and the protocol library | [![release](https://img.shields.io/github/v/release/FreeMixer/mod-host?label=)](https://github.com/FreeMixer/mod-host/releases/latest) | the plugin host most of the above can drive. The `freemixer` branch of our fork carries what we offer upstream; each change is an open [pull request upstream](https://github.com/mod-audio/mod-host/pulls) and the packages carry it until upstream releases | `mod-host`, `mod-host-protocol` | `libmod-host-protocol-dev` | - |

## On a Zynthian

The FreeMixer forks of [zynthian-ui](https://github.com/FreeMixer/zynthian-ui) and
[zynthian-sys](https://github.com/FreeMixer/zynthian-sys) (branch `vangelis`) add an engine that runs a Zynthian
chain's LV2 and CLAP plugins through plugin-hostd, with the plugin menus ordered from the measurements
[plugin-qualify](https://github.com/FreeMixer/plugin-qualify) records. Those records for a ZynthianOS
Vangelis image on a Raspberry Pi 5 are in [omx-qualification-records](https://github.com/FreeMixer/omx-qualification-records).

Repository, package and pkg-config names of every piece:
https://www.openmixer.org/docs/plugins-names/

## Install

Installing `openmixer-release` adds the repository and its key; `dnf update` and `apt upgrade` keep them current.

Fedora: `sudo dnf install https://www.openmixer.org/rpm/openmixer-release.noarch.rpm`

Debian and Raspberry Pi OS (bookworm, trixie): `curl -fsSLO https://www.openmixer.org/deb/openmixer-release.deb && sudo apt install ./openmixer-release.deb && sudo apt update`

## Checked

[Theorem's OSS Verify](https://github.com/theorem-labs/oss-verify) lists these projects of ours in its `projects/`:
[libdiginet](https://github.com/FreeMixer/libdiginet), [mod-host](https://github.com/FreeMixer/mod-host),
[omx-clap-core](https://github.com/FreeMixer/omx-clap-core), [plugin-hostd](https://github.com/FreeMixer/plugin-hostd),
[libreac](https://github.com/FreeREAC/libreac) and [reac-pw](https://github.com/FreeREAC/reac-pw).
Each ships fuzz targets written to its contract. The other pieces are not listed there.

## Also here

- [openmixer-www](https://github.com/FreeMixer/openmixer-www): the website and documentation, <https://www.openmixer.org>.
- [freemixer.github.io](https://github.com/FreeMixer/freemixer.github.io): the package repositories the install above uses.
- [.github](https://github.com/FreeMixer/.github): this page and the release workflow every package shares.
