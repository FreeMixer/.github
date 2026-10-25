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
- [omx-panel](https://github.com/FreeMixer/omx-panel) gives any LV2 or CLAP plugin a panel without
  drawing one: a MOD GUI for MOD and Zynthian, controller pages and a host layout, all generated from
  what the plugin itself declares, in the omx look.
  Install: `dnf install omx-panel`, `apt install omx-panel` or `npm install @openmixer/omx-panel`.
- **mod-host** with the protocol library: our changes are open pull requests upstream
  ([mod-audio/mod-host](https://github.com/mod-audio/mod-host/pulls)).

## Install

Fedora: `sudo dnf config-manager addrepo --from-repofile=https://freemixer.github.io/rpm/freemixer.repo`

Debian and Raspberry Pi OS: see https://freemixer.github.io

Repository, package and pkg-config names of every piece:
https://freemixer.github.io/docs/plugins-names/
