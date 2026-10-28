"""Build the Russian text patch for ELDEN VINS NIGHTREIGN from EVN Russian (Nexus 447).

EVN Russian 1.3 ships pre-DLC base files (msg/rusru/item.msgbnd.dcx, menu.msgbnd.dcx). Vins 1.5.x and the
post-DLC game use item_dlc01/menu_dlc01.msgbnd.dcx, which hold the whole text set. This copies EVN's Russian
lines into Vins' rusru *_dlc01 files where Vins left English and the numbers in both texts agree, and writes
mods/EVN Russian for ELDEN VINS <version>.zip, which install.ps1 installs over that Vins version.

Run after a Vins or EVN update:  python -I tools/merge_evn_ru.py
Needs the game installed: the Oodle codec comes from its oo2core_9_win64.dll.
"""
import ctypes
import re
import struct
import sys
import winreg
import zipfile
from pathlib import Path

MODS = Path(__file__).resolve().parent.parent / "mods"
VINS_ZIP = re.compile(r"ELDEN VINS NIGHTREIGN-\d+-(.+)-\d+\.zip")  # same parse as install.ps1
CYR = re.compile("[Ѐ-ӿ]")
TAGS = re.compile(r"<\?[^>]*\?>|<[^>]+>")
WORD = re.compile(r"[A-Za-z]{3,}")
NUM = re.compile(r"\d+(?:[.,]\d+)?")
oodle = None


def newest(pattern):
    files = sorted(MODS.glob(pattern), key=lambda p: p.stat().st_mtime)  # newest wins, as in install.ps1
    if not files:
        sys.exit(f"no {pattern} in {MODS}")
    return files[-1]


def load_oodle():
    key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam")
    steam = winreg.QueryValueEx(key, "SteamPath")[0]
    vdf = Path(steam, "steamapps", "libraryfolders.vdf").read_text(encoding="utf-8", errors="replace")
    for lib in [steam] + [p.replace("\\\\", "\\") for p in re.findall(r'"path"\s+"([^"]+)"', vdf)]:
        dll = Path(lib, "steamapps", "common", "ELDEN RING NIGHTREIGN", "Game", "oo2core_9_win64.dll")
        if dll.exists():
            break
    else:
        sys.exit("ELDEN RING NIGHTREIGN not found in Steam libraries (its oo2core_9_win64.dll is needed)")
    lib = ctypes.WinDLL(str(dll))
    p, n, i = ctypes.c_void_p, ctypes.c_ssize_t, ctypes.c_int
    lib.OodleLZ_Decompress.restype = n
    lib.OodleLZ_Decompress.argtypes = [p, n, p, n, i, i, i, p, n, p, p, p, n, i]
    lib.OodleLZ_Compress.restype = n
    lib.OodleLZ_Compress.argtypes = [i, p, n, p, i, p, p, p, p, n]
    return lib


def utf16z(b, o):
    j = o
    while b[j:j + 2] != b"\0\0":
        j += 2
    return b[o:j].decode("utf-16-le")


# DCX (KRAK): 0x4C-byte header, big-endian sizes at 0x1C/0x20, level at 0x30, data padded to 16 bytes.
def dcx_unpack(b):
    assert b[:4] == b"DCX\0" and b[0x28:0x2C] == b"KRAK", "unexpected DCX format"
    raw_size, comp_size = struct.unpack_from(">II", b, 0x1C)
    out = ctypes.create_string_buffer(raw_size)
    n = oodle.OodleLZ_Decompress(b[0x4C:0x4C + comp_size], comp_size, out, raw_size,
                                 1, 0, 0, None, 0, None, None, None, 0, 3)
    assert n == raw_size, "Oodle decompression failed"
    return out.raw


def dcx_pack(orig, raw):
    out = ctypes.create_string_buffer(len(raw) + 274 * (len(raw) // 0x40000 + 1) + 0x10000)
    n = oodle.OodleLZ_Compress(8, raw, len(raw), out, orig[0x30], None, None, None, None, 0)  # 8 = Kraken
    assert n > 0, "Oodle compression failed"
    head = bytearray(orig[:0x4C])
    struct.pack_into(">II", head, 0x1C, len(raw), n)
    data = bytes(head) + out.raw[:n]
    return data + b"\0" * (-len(data) % 16)


# BND4 with 0x24-byte file headers: flags, -1, size, size, data offset (u32), id, name offset.
def bnd4_unpack(b):
    assert b[:4] == b"BND4" and struct.unpack_from("<q", b, 0x20)[0] == 0x24, "unexpected BND4 layout"
    files = []
    for i in range(struct.unpack_from("<i", b, 0x0C)[0]):
        o = 0x40 + i * 0x24
        size = struct.unpack_from("<q", b, o + 8)[0]
        off, _, name_off = struct.unpack_from("<Iii", b, o + 0x18)
        files.append((utf16z(b, name_off).split("\\")[-1], b[off:off + size]))
    return files


def bnd4_pack(orig, blobs):
    heads = [0x40 + i * 0x24 for i in range(len(blobs))]
    offs = [struct.unpack_from("<I", orig, h + 0x18)[0] for h in heads]
    out = bytearray(orig[:min(offs)])  # header, file headers and names stay as they are
    for i in sorted(range(len(blobs)), key=offs.__getitem__):
        out += b"\0" * (-len(out) % 16)
        struct.pack_into("<qqI", out, heads[i] + 8, len(blobs[i]), len(blobs[i]), len(out))
        out += blobs[i]
    return bytes(out)  # no padding after the last file


# FMG version 2: groups (index, first id, last id) map ids to string-table indices.
def fmg_unpack(b):
    assert b[:4] == b"\0\0\2\0", "unexpected FMG version"
    groups, count = struct.unpack_from("<ii", b, 0x0C)
    table = struct.unpack_from("<q", b, 0x18)[0]
    strings = [utf16z(b, o) if o > 0 else None for o in struct.unpack_from(f"<{count}q", b, table)]
    ids = {}
    for g in range(groups):
        idx, first, last = struct.unpack_from("<iii", b, 0x28 + g * 0x10)
        ids.update((first + k, idx + k) for k in range(last - first + 1))
    return strings, ids


def fmg_pack(orig, strings):
    table = struct.unpack_from("<q", orig, 0x18)[0]
    out = bytearray(orig[:table + len(strings) * 8])
    for i, s in enumerate(strings):
        if s is not None:
            struct.pack_into("<q", out, table + i * 8, len(out))
            out += s.encode("utf-16-le") + b"\0\0"
    struct.pack_into("<i", out, 4, len(out))  # file size; no trailing padding
    return bytes(out)


def english(t):
    return bool(t) and not CYR.search(t) and bool(WORD.search(TAGS.sub("", t)))


def numbers(t):
    return sorted(n.replace(",", ".") for n in NUM.findall(TAGS.sub("", t)))


def merge(vins_dcx, evn_dcx):
    vins = dcx_unpack(vins_dcx)
    files = bnd4_unpack(vins)
    # The writers must reproduce the untouched file byte for byte, or the output cannot be trusted.
    assert dcx_unpack(dcx_pack(vins_dcx, vins)) == vins, "DCX round trip differs"
    assert bnd4_pack(vins, [blob for _, blob in files]) == vins, "BND4 writer does not reproduce the original"
    evn = {}
    for name, blob in bnd4_unpack(dcx_unpack(evn_dcx)):
        strings, ids = fmg_unpack(blob)
        evn[name] = {i: strings[k] for i, k in ids.items()}

    blobs, used, skipped = [], 0, 0
    for name, blob in files:
        strings, ids = fmg_unpack(blob)
        assert fmg_pack(blob, strings) == blob, f"FMG writer does not reproduce {name}"
        ru = evn.get(name, {})
        for i, k in ids.items():
            r = ru.get(i)
            if english(strings[k]) and r and CYR.search(r):
                if numbers(strings[k]) == numbers(r):
                    strings[k], used = r, used + 1
                else:
                    skipped += 1  # Vins changed the values since EVN was made; English is the accurate text
        blobs.append(fmg_pack(blob, strings))
    new = bnd4_pack(vins, blobs)
    packed = dcx_pack(vins_dcx, new)
    assert dcx_unpack(packed) == new, "packed DCX does not decode back"
    return packed, used, skipped


def main():
    global oodle
    oodle = load_oodle()
    vins_zip, evn_zip = newest("ELDEN VINS NIGHTREIGN-*.zip"), newest("EVN Russian-*.zip")
    m = VINS_ZIP.fullmatch(vins_zip.name)
    if not m:
        sys.exit(f"cannot read the Vins version from {vins_zip.name}")
    ver = m.group(1)
    out = MODS / f"EVN Russian for ELDEN VINS {ver}.zip"
    tmp = out.with_suffix(".tmp")
    print(f"{vins_zip.name} + {evn_zip.name}")
    with zipfile.ZipFile(vins_zip) as vz, zipfile.ZipFile(evn_zip) as ez, \
            zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as oz:
        for kind in ("item", "menu"):
            data, used, skipped = merge(vz.read(f"ELDEN VINS NIGHTREIGN/mod/msg/rusru/{kind}_dlc01.msgbnd.dcx"),
                                        ez.read(f"msg/rusru/{kind}.msgbnd.dcx"))
            oz.writestr(f"msg/rusru/{kind}_dlc01.msgbnd.dcx", data)
            print(f"  {kind}: {used} lines translated, {skipped} kept in English (numbers differ)")
    tmp.replace(out)
    print(f"written {out}")


if __name__ == "__main__":
    main()
