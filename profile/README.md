<img src="openmixer-logo.svg" alt="openmixer" width="330">

# FreeMixer

**openmixer** is a free, real-time digital mixing console for Linux: a live mixer
you run on a PC, with a web UI on any tablet and hardware control surfaces.
→ https://freemixer.github.io

## The pieces you can use on their own

- [plugin-hostd](https://github.com/FreeMixer/plugin-hostd) runs LV2 and CLAP plugins
  in separate worker processes behind one mod-host socket. If a plugin crashes,
  only its worker restarts and the others keep playing.
- [omx-clap-host](https://github.com/FreeMixer/omx-clap-host) is a headless CLAP host
  that speaks mod-host's protocol, one JACK client per plugin.
- **mod-host** with the protocol library: our changes are open pull requests upstream
  ([mod-audio/mod-host](https://github.com/mod-audio/mod-host/pulls)).

## Install

Fedora: `sudo dnf config-manager addrepo --from-repofile=https://freemixer.github.io/rpm/freemixer.repo`

Debian and Raspberry Pi OS: see https://freemixer.github.io
