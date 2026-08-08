# Syncing straight to a Lunii storyteller

[lunii-export.md](lunii-export.md) writes a STUdio archive that a grown-up then
transfers by hand. This document covers the other half: writing a pack **onto an
attached storyteller directly**, so the share menu can offer "send to the Lunii"
when one is plugged in.

Everything below was verified against a physical FW2 device, not taken on trust
— see [tool/lunii_probe.dart](../tool/lunii_probe.dart), which re-checks every
claim here against whatever device is attached and never opens it for writing.

## The device

A FW2 storyteller mounts as plain **USB mass storage**, FAT32, volume label
`LUNII` (`VID_0483&PID_A341`). No libusb, no driver, no vendor protocol — it is
ordinary file I/O, which is why this can live in pure Dart.

```
<drive>/
├── .md          512 B  device metadata; device key at 0x100
├── .pi          16 B per installed pack — the pack list
├── .cfg         device settings (volume, sleep timer); not ours to touch
├── version      firmware build date, e.g. "2020-11-27 14:51 UTC"
└── .content/
    └── <PACK>/  last 4 bytes of the pack uuid, uppercase hex
        ├── ni   node index — the story graph
        ├── li   list index — action-node options
        ├── ri   resource index — image asset paths
        ├── si   sound index — audio asset paths
        ├── bt   64 B boot file — ties the pack to this device
        ├── nm   empty
        ├── rf/000/XXXXXXXX   images
        └── sf/000/XXXXXXXX   audio
```

`.pi` is a flat run of 16-byte pack uuids. The `.content` directory name is the
**last 4 bytes of that uuid as uppercase hex** — so uuid `…B3941EE8` lives in
`.content/B3941EE8`.

## Ciphering

A modified XXTEA: rounds are `1 + 52/n`, where stock XXTEA uses `6 + 52/n`. At a
full 512-byte block that is exactly one round. Little-endian 32-bit words,
delta `0x9E3779B9`.

**Only the first 512 bytes of a file are ciphered** — one flash sector. The tail
is plaintext, which is why an MP3 on the device still shows readable frame
headers past byte 512.

| File | Ciphered with |
|------|---------------|
| `ri`, `si`, `li`, `rf/*`, `sf/*` | generic key |
| `bt` | device key |
| **`ni`** | **not ciphered** |
| `nm` | empty |

`ni` being plaintext is the trap: it is an index like the others, the
reverse-engineering notes list it among the encrypted files, and deciphering it
silently corrupts the header while leaving the node entries (past byte 512)
looking perfectly valid.

The generic key is the same on every device:

```
0x91BD7A0A, 0xA75440A9, 0xBBD49D6C, 0xE0DCC0E3
```

The **device key** is per-storyteller. Take the 0x100 bytes of `.md` at offset
0x100, decipher with the generic key, then read the first 16 bytes of the result
with its halves swapped — `plain[8:16] + plain[0:8]` — as four little-endian
words. The block length matters: at 0x100 bytes it is 64 words and so runs one
round, and deciphering a shorter slice runs a different number of rounds and
yields a wrong key with no error.

`bt` is then `cipher(ri[0:0x40], deviceKey)` over the **already-ciphered** `ri`,
so deciphering `bt` reproduces the head of `ri` exactly as stored on disk. That
identity is the cheapest way to prove a derived key is correct, and
`lunii_probe` checks it against every pack on the device.

## ni — the story graph

Plaintext. A 512-byte header, then one 44-byte entry per stage node.

| Offset | Size | Field |
|--------|------|-------|
| 0x00 | 2 | format version (1) |
| 0x02 | 2 | pack version (2) |
| 0x04 | 4 | header size (0x200) |
| 0x08 | 4 | node size (0x2C) |
| 0x0C | 4 | stage node count |
| 0x10 | 4 | image count — must equal `ri` entries |
| 0x14 | 4 | sound count — must equal `si` entries |
| 0x18 | 1 | control byte |

Each 44-byte node:

| Offset | Size | Field |
|--------|------|-------|
| 0x00 | 4 | image index, `-1` for none |
| 0x04 | 4 | audio index, `-1` for none |
| 0x08 | 12 | ok transition: list index, option count, option index |
| 0x14 | 12 | home transition, same triple, `-1,-1,-1` for none |
| 0x20 | 10 | five `uint16` flags: wheel, ok, home, pause, autoplay |
| 0x2A | 2 | padding |

`li` is a flat run of `int32` stage-node indices; a node's transition triple
slices into it at *list index* for *count* entries. `ri` and `si` are runs of
12-byte asset paths, `000\XXXXXXXX`, pointing into `rf/000/` and `sf/000/`.

## Asset formats

These are device requirements, not conveniences — both confirmed by decoding
assets off the attached device.

- **Images** — BMP, exactly **320×240**, **4-bit RLE4**, 16-level greyscale
  palette.
- **Audio** — **MP3, 44.1 kHz, mono**, no ID3 tags. A frame header read off the
  device decodes as MPEG-1 Layer III / 44100 / mono, tagged by LAME 3.99.5.

The audio requirement is the awkward one. Of the app's voices only ElevenLabs
(`mp3_44100_128`) already conforms; Gemini and the Windows voice produce 24 kHz
WAV and OpenAI produces 24 kHz MP3, so they need resampling and re-encoding.
See [decision-log.md](decision-log.md) for how that is handled.

## Writing safely

The nine packs already on a device are purchased content, and a botched `.pi`
is what loses them. So:

- Copy `.pi` and `.md` into the app's library folder before the first write.
- Write the new `.content/<PACK>/` tree fully, and only then append the uuid to
  `.pi` — a half-written pack that is not listed is invisible, whereas a listed
  pack that is half-written is not.
- Never touch `.cfg`.
