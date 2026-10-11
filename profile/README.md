<img src="openmixer-logo.svg" alt="openmixer" width="330">

# OpenMixer

**openmixer** is a free, real-time digital mixing console for Linux: a live mixer
you run on a PC, with a web UI on any tablet and hardware control surfaces.
→ https://freemixer.github.io

## The pieces you can use on their own

- [plugin-hostd](https://github.com/FreeMixer/plugin-hostd) runs LV2 and CLAP plugins
  in separate worker processes behind one mod-host socket. If a plugin crashes,
  only its worker restarts and the others keep playing.
- [omx-clap-core](https://github.com/FreeMixer/omx-clap-core) is a headless CLAP host
  that speaks mod-host's protocol, one JACK client per plugin.
- **mod-host** with the protocol library: our changes are open pull requests upstream
  ([mod-audio/mod-host](https://github.com/mod-audio/mod-host/pulls)).

## Names: repository, package and pkg-config

One row per piece. A dash means the piece does not ship in that form.

| Repository | pkg-config | RPM | DEB | npm |
|---|---|---|---|---|
| [omx-clap-core](https://github.com/FreeMixer/omx-clap-core) | `omx-clap-core`, `omx-clap-lv2` | `omx-clap-host`, `omx-clap-core`, `omx-clap-core-devel`, `omx-clap-lv2-devel` | `omx-clap-host`, `libomx-clap-core0`, `libomx-clap-core-dev`, `libomx-clap-lv2-dev` | - |
| [omx-contract](https://github.com/FreeMixer/omx-contract) | `omx-contract` | `omx-contract-devel` | `libomx-contract-dev` | `@openmixer/omx-contract` |
| [omx-dsp](https://github.com/FreeMixer/omx-dsp) | `omxdsp` | `omx-dsp-devel` | `libomxdsp-dev` | - |
| [omx-plugins](https://github.com/FreeMixer/omx-plugins) | - | `omx-plugins`, `omx-plugins-clap`, `omx-plugins-lv2`, `omx-plugins-devel` | `omx-plugins`, `omx-plugins-clap`, `omx-plugins-lv2`, `omx-plugins-dev` | - |
| [plugin-hostd](https://github.com/FreeMixer/plugin-hostd) | - | `plugin-hostd`, `plugin-hostd-devel` | `plugin-hostd`, `plugin-hostd-dev` | - |
| [plugin-qualify](https://github.com/FreeMixer/plugin-qualify) | - | `plugin-qualify` | `plugin-qualify` | - |

Packages we build carry the suffix `fmx` after the release counter (`0.10.6-1-fmx`), never the word freemixer.

## Install

Fedora: `sudo dnf config-manager addrepo --from-repofile=https://freemixer.github.io/rpm/freemixer.repo`

Debian and Raspberry Pi OS: see https://freemixer.github.io
