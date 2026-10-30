<img src="openmixer-logo.svg" alt="openmixer" width="330">

# OpenMixer

**openmixer** is a free, real-time digital mixing console for Linux: a live mixer
you run on a PC, with a web UI on any tablet and hardware control surfaces.
→ https://www.openmixer.org

## What you can install

Each row is a piece you can use without the rest, with its current release. Add the repository ([Install](#install))
and install by name; a dash means the piece does not ship in that form.

| Piece | Version | What it gives you | Fedora | Debian / Raspberry Pi OS | npm |
|---|---|---|---|---|---|
| [plugin-hostd](https://github.com/FreeMixer/plugin-hostd) | 0.15.0 | CLAP and LV2 plugins, each format in a native host, in worker processes behind one mod-host socket; a crash restarts only that worker | `plugin-hostd` | `plugin-hostd` | - |
| [omx-clap-core](https://github.com/FreeMixer/omx-clap-core) | 0.24.2 | `omx-clap-host`, a headless CLAP and LV2 host that speaks mod-host's protocol, one JACK client per plugin; the CLAP hosting library; the LV2 adapter library | `omx-clap-host`, `omx-clap-core`, `omx-clap-core-devel`, `omx-clap-lv2-devel` | `omx-clap-host`, `libomx-clap-core-dev`, `libomx-clap-lv2-dev` | - |
| [omx-panel](https://github.com/FreeMixer/omx-panel) | 0.7.2 | a panel for any LV2 or CLAP plugin without drawing one: MOD GUI, controller pages, host layout | `omx-panel` | `omx-panel` | `@openmixer/omx-panel` |
| [omx-plugins](https://github.com/FreeMixer/omx-plugins) | 0.16.0 | our own effects as CLAP and LV2 plugins | `omx-plugins`, `omx-plugins-clap`, `omx-plugins-lv2` | `omx-plugins` | - |
| [omx-dsp](https://github.com/FreeMixer/omx-dsp) | 0.26.0 | the DSP kernels the plugins and the console share, a C library | `omx-dsp-devel` | `libomxdsp-dev` | - |
| [omx-contract](https://github.com/FreeMixer/omx-contract) | 3.4.0 | the declarations every piece agrees on: parameters, units, limits, codes | `omx-contract-devel` | `libomx-contract-dev` | `@openmixer/omx-contract` |
| [plugin-qualify](https://github.com/FreeMixer/plugin-qualify) | 0.17.4 | checks a plugin for real-time safety and cost before a stage runs it | `plugin-qualify` | `plugin-qualify` | - |
| [libreac](https://github.com/FreeREAC/libreac) and [reac-pw](https://github.com/FreeREAC/reac-pw) | libreac 1.10.0, reac-pw 1.0.42 | the REAC protocol and its PipeWire bridge, for Roland stageboxes | `libreac`, `reac-pw` | `libreac-dev`, `reac-pw` | - |
| [libdiginet](https://github.com/FreeMixer/libdiginet) | 0.1.2 | the Digidesign Control&#124;24 and ProControl surface protocol over Ethernet, a C library with a probe tool | `libdiginet`, `diginet-tools` | `libdiginet-dev`, `diginet-tools` | - |
| [libsurface](https://github.com/FreeMixer/libsurface) | 0.1.0, not released yet | the device behaviour every motorised control surface shares (motor faders that never fight the hand, touch, banking, repaint, meters), a C library with a Control&#124;24 module over libdiginet | `libsurface`, `libsurface-devel`, `libsurface-diginet`, `libsurface-diginet-devel`, `surface-c24` | `libsurface0`, `libsurface-dev`, `libsurface-diginet0`, `libsurface-diginet-dev`, `surface-c24` | - |
| [libmackie](https://github.com/FreeMixer/libmackie) | 0.1.0, not released yet | Mackie Control and HUI byte for byte: the MCU codec for an X-Touch or any MCU surface, a C library with no I/O | `libmackie`, `libmackie-devel` | `libmackie0`, `libmackie-dev` | - |
| mod-host and the protocol library | 0.10.8 | the plugin host most of the above can drive; our changes are open [pull requests upstream](https://github.com/mod-audio/mod-host/pulls) | `mod-host`, `mod-host-protocol` | `libmod-host-protocol-dev` | - |

Repository, package and pkg-config names of every piece:
https://www.openmixer.org/docs/plugins-names/

## Install

Installing `openmixer-release` adds the repository and its key; `dnf update` and `apt upgrade` keep them current.

Fedora: `sudo dnf install https://www.openmixer.org/rpm/openmixer-release.noarch.rpm`

Debian and Raspberry Pi OS (bookworm, trixie): `curl -fsSLO https://www.openmixer.org/deb/openmixer-release.deb && sudo apt install ./openmixer-release.deb && sudo apt update`
