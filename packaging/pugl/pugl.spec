# pugl, the window and event library of the panel renderer (omx-panel docs/renderer.md), which neither Fedora nor
# Debian package. Built from the commit of .github/pins.txt (upstream publishes no release tarball), with every
# backend but Vulkan: X11 with the GL and Cairo backends. The package carries the suffix omx after its
# Release, as every package the channel rebuilds does.

%global commit0 e6e7f24d09fb528e697817300b60ca0afe19e2b6
%global shortcommit0 %(c=%{commit0}; echo ${c:0:7})
%global snapdate 20261102

Name: pugl
Version: 0.5.9^%{snapdate}git%{shortcommit0}
Release: 1.omx%{?dist}
Summary: A minimal portable API for embeddable GUIs
License: ISC
URL: https://gitlab.com/lv2/pugl
Source0: https://gitlab.com/lv2/pugl/-/archive/%{commit0}/pugl-%{commit0}.tar.gz

BuildRequires: gcc
BuildRequires: meson >= 0.56
BuildRequires: ninja-build
BuildRequires: pkgconfig(x11)
BuildRequires: pkgconfig(xext)
BuildRequires: pkgconfig(xrandr)
BuildRequires: pkgconfig(xcursor)
BuildRequires: pkgconfig(gl)
BuildRequires: pkgconfig(cairo)

%description
Pugl is a minimal portable API for GUIs which is suitable for use in plugins
and applications. It opens a window, embedded in a host's or on its own, and
delivers its events; drawing is left to a backend: OpenGL, Cairo or none.

%package devel
Summary: Development files for pugl
Requires: %{name}%{?_isa} = %{version}-%{release}

%description devel
The headers and the pkg-config files of pugl (pugl-0, pugl-gl-0, pugl-cairo-0),
for building against it.

%prep
%autosetup -n pugl-%{commit0}

%build
%meson -Ddocs=disabled -Dexamples=disabled -Dtests=disabled -Dlint=false -Dvulkan=disabled -Dbindings_cpp=disabled \
  -Dopengl=enabled -Dcairo=enabled -Dstub=false
%meson_build

%install
%meson_install

%files
%license COPYING
%doc README.md
%{_libdir}/libpugl_*-0.so.*

%files devel
%{_includedir}/pugl-0/
%{_libdir}/libpugl_*-0.so
%{_libdir}/pkgconfig/pugl-*.pc

%changelog
* Wed Nov 04 2026 Pau Aliagas <linuxnow@gmail.com> - 0.5.9^20261102gite6e7f24-1.omx
- First package, for the panel renderer's window
