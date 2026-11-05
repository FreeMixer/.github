# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
# SPDX-License-Identifier: Zlib
# The build of NanoVG as the channel packages it (packaging/nanovg/nanovg.spec and the DEB both lay this file at the
# top of the upstream source): src/nanovg.c as libnanovg.so.0, the headers under include/nanovg, a pkg-config file.
project('nanovg', 'c', version: '0.0.0', license: 'Zlib', meson_version: '>= 0.56.0', default_options: ['c_std=c99'])

m = meson.get_compiler('c').find_library('m', required: false)
nanovg = library('nanovg', 'src/nanovg.c', version: '0.0.0', soversion: '0', dependencies: m,
                 c_args: ['-Wno-unused-result', '-Wno-misleading-indentation'], install: true)
install_headers('src/nanovg.h', 'src/nanovg_gl.h', 'src/nanovg_gl_utils.h', subdir: 'nanovg')
import('pkgconfig').generate(nanovg, name: 'nanovg', description: 'Antialiased 2D vector drawing on OpenGL',
                             subdirs: 'nanovg', libraries_private: m)
