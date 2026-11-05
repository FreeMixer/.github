# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
# Surge XT, the hybrid synthesizer of the Surge Synth Team, as the CLAP and the LV2 that Zynthian and the MOD
# hosts load, built for x86_64 and aarch64 from the commit of .github/pins.txt. Neither Fedora nor Debian package it.
#
# 1.4.0 is the floor: upstream has tagged nothing from 1.4.0 on (the last tag is release_xt_1.3.4) while its main
# has called itself 1.4.0 since, so the pin is a commit of main, as pugl and nanovg are. 1.3.x is not packaged,
# and no patch is carried: the one a 1.3 build needed is part of 1.4.0. The next package bumps the pin and the
# Version with it.
#
# The source is not a GitHub archive: Surge builds from JUCE, the CLAP wrapper and the sst libraries, all
# submodules, so make-source.sh lays the commit out with them at the commits it records. The build and the install
# are overlay/surge-xt-build.sh, which the DEB runs too. The files go to /usr/lib/clap and /usr/lib/lv2 on both
# architectures, where the hosts look, not to %%{_libdir}.

%global commit0 72a602284b7a599ee3a93d7a830236776e0abb2b
%global shortcommit0 %(c=%{commit0}; echo ${c:0:7})
%global snapdate 20261103

# the CLAP and the LV2 are plugins: nothing links to them, and debuginfo for a JUCE plugin is the size of the plugin
%global debug_package %{nil}

Name: surge-xt
Version: 1.4.0^%{snapdate}git%{shortcommit0}
Release: 1.omx%{?dist}
Summary: Hybrid synthesizer, as CLAP and LV2 plugins
License: GPL-3.0-or-later
URL: https://surge-synthesizer.github.io/
# made by make-source.sh from the commit above, not a download
Source0: surge-xt-%{commit0}.tar.gz
Source1: surge-xt-build.sh

BuildRequires: gcc-c++
BuildRequires: cmake >= 3.22
BuildRequires: ninja-build
BuildRequires: pkgconfig(alsa)
BuildRequires: pkgconfig(jack)
BuildRequires: pkgconfig(x11)
BuildRequires: pkgconfig(xrandr)
BuildRequires: pkgconfig(xinerama)
BuildRequires: pkgconfig(xcursor)
BuildRequires: pkgconfig(xext)
BuildRequires: pkgconfig(freetype2)
BuildRequires: pkgconfig(fontconfig)
BuildRequires: pkgconfig(libcurl)
BuildRequires: pkgconfig(cairo)
BuildRequires: pkgconfig(xkbcommon-x11)
BuildRequires: pkgconfig(xcb-cursor)
BuildRequires: pkgconfig(xcb-keysyms)
BuildRequires: pkgconfig(xcb-util)
BuildRequires: pkgconfig(gl)
Requires: %{name}-clap = %{version}-%{release}
Requires: %{name}-lv2 = %{version}-%{release}

%description
Surge XT is a hybrid synthesizer: three oscillators per scene with wavetable, FM, ring modulation and the
classic waveforms, two filters, a modulation matrix, and effects. This package installs both of its plugin
formats; surge-xt-clap and surge-xt-lv2 install one each.

%package data
Summary: Factory patches, wavetables and skins of Surge XT
BuildArch: noarch

%description data
The data both Surge XT plugins read at start: the factory patches, the wavetables, the tuning files and the
skins, in /usr/share/surge-xt.

%package clap
Summary: Surge XT as a CLAP plugin
Requires: %{name}-data = %{version}-%{release}

%description clap
Surge XT as a CLAP instrument, installed in /usr/lib/clap where CLAP hosts, omx-clap-host among them, look.

%package lv2
Summary: Surge XT as an LV2 plugin
Requires: %{name}-data = %{version}-%{release}
Requires: lv2

%description lv2
Surge XT as an LV2 instrument, installed in /usr/lib/lv2 where LV2 hosts look.

%prep
%autosetup -n surge-xt-%{commit0}
install -m 0755 %{SOURCE1} .

%build
SURGE_JOBS=%{_smp_build_ncpus} ./surge-xt-build.sh build "$PWD" "$PWD/build"

%install
./surge-xt-build.sh install "$PWD" "$PWD/build" %{buildroot}

%check
# the CLAP is loaded the way Zynthian's host loads it: omx-clap-scan, when it is installed, lists the plugin
if command -v omx-clap-scan >/dev/null; then
    out=$(omx-clap-scan --json "%{buildroot}/usr/lib/clap/Surge XT.clap")
    echo "$out" | grep -q '"id":"org.surge-synth-team.surge-xt"'
fi

%files

%files data
%license LICENSE
%{_datadir}/surge-xt/

%files clap
/usr/lib/clap/Surge XT.clap

%files lv2
/usr/lib/lv2/Surge XT.lv2/

%changelog
* Wed Nov 04 2026 Pau Aliagas <linuxnow@gmail.com> - 1.4.0^20261103git72a6022-1.omx
- First package, Surge XT 1.4.0 as a CLAP and an LV2 for Zynthian, in place of a build kept in /usr/local/lib/clap
