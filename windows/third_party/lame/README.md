# libmp3lame — vendored

A Lunii storyteller only plays **MPEG-1 Layer III, 44.1 kHz, mono** audio, and
most of the app's voices hand back 24 kHz. LAME does the resampling and the
encoding; `lib/adapters/audio/lame.dart` binds to this DLL over FFI. See
[docs/lunii-sync.md](../../../docs/lunii-sync.md).

## What is here

| File | |
|------|--|
| `libmp3lame.dll` | LAME 3.100, x64, unmodified upstream source |
| `COPYING` | GNU LGPL v2 — the licence LAME is under |
| `LICENSE` | LAME's own note on commercial use |

```
lame-3.100.tar.gz  sha256 ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e
libmp3lame.dll     sha256 edb14418d34d3821e858c4fca284b9c1d2a4607455727a8b77ca9d2eabbd8052
```

That tarball hash is the one published for the official 3.100 release at
<https://lame.sourceforge.io/>.

## Rebuilding it

From a **x64 Native Tools** developer prompt, in the unpacked tarball:

```
nmake -f Makefile.MSVC MSVCVER=Win64 libmp3lame.dll
```

Output lands in `output\`. Copy `output\libmp3lame.dll` here. Nothing else from
the build tree is needed — not the import library, since the DLL is loaded at
run time rather than linked.

## Licensing

LAME is LGPL v2 and the source is **not** modified. The app links to it as a
separate shared library loaded at run time, which is the arrangement the LGPL
asks for: anyone can drop in their own build of `libmp3lame.dll` without
touching the app. Shipping requires that `COPYING` travels with the binary, so
`windows/CMakeLists.txt` installs the licence next to the DLL in the bundle.

**Still owed before release:** the app has no About screen yet, so LAME is not
yet credited in the UI. Add that when one exists — LAME's `LICENSE` asks for an
acknowledgement and a link to the project.
