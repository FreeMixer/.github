# NanoVG, the vector drawing of the panel renderer's window (omx-panel docs/renderer.md), which neither Fedora nor
# Debian package. Upstream ships a premake file and no library; overlay/meson.build, the same file the DEB builds
# with, builds src/nanovg.c into libnanovg.so.0 and installs its headers, the GL backend headers among them, under
# include/nanovg with a pkg-config file. Built from the commit of .github/pins.txt: upstream tags no release.

%global commit0 ce3bf745eb2d2dbc14a50bf2446783f691ac4353
%global shortcommit0 %(c=%{commit0}; echo ${c:0:7})
%global snapdate 20260219

Name: nanovg
Version: 0^%{snapdate}git%{shortcommit0}
Release: 1.omx%{?dist}
Summary: Antialiased 2D vector drawing on OpenGL
License: Zlib
URL: https://github.com/memononen/nanovg
Source0: https://github.com/memononen/nanovg/archive/%{commit0}.tar.gz#/nanovg-%{commit0}.tar.gz
Source1: meson.build

BuildRequires: gcc
BuildRequires: meson >= 0.56
BuildRequires: ninja-build

%description
NanoVG is a small antialiased vector graphics rendering library for OpenGL,
with an API modelled on the HTML5 canvas: paths, fills, strokes, gradients,
images and text from TrueType fonts.

%package devel
Summary: Development files for NanoVG
Requires: %{name}%{?_isa} = %{version}-%{release}
Requires: pkgconfig(gl)

%description devel
The headers of NanoVG, its OpenGL backend (nanovg_gl.h, compiled into the
program that includes it) and the pkg-config file nanovg.

%prep
%autosetup -n nanovg-%{commit0}
cp %{SOURCE1} .

%build
%meson
%meson_build

%install
%meson_install

%files
%license LICENSE.txt
%doc README.md
%{_libdir}/libnanovg.so.0*

%files devel
%{_includedir}/nanovg/
%{_libdir}/libnanovg.so
%{_libdir}/pkgconfig/nanovg.pc

%changelog
* Wed Nov 04 2026 Pau Aliagas <linuxnow@gmail.com> - 0^20260219gitce3bf74-1.omx
- First package, for the panel renderer's window
