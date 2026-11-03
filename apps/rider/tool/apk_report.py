#!/usr/bin/env python3
"""Ce qui pèse dans un APK : plus gros fichiers, poids par famille, poids à télécharger.

Usage : python3 tool/apk_report.py app-arm64-v8a-release.apk [...]

« Téléchargement estimé » : chaque fichier recompressé (zlib 9), comme le Play Store
compresse ce qu'il envoie au téléphone ; les bibliothèques natives sont stockées sans
compression dans l'APK pour être chargées sans extraction.
"""

import struct
import sys
import zipfile
import zlib


def ko(n: int) -> str:
    return f"{n / 1024:,.0f} Ko".replace(",", " ")


def family(name: str) -> str:
    if name.startswith("lib/"):
        return name.rsplit("/", 1)[-1]
    if name.endswith(".dex"):
        return "code Java/Kotlin (dex)"
    if name.startswith("assets/flutter_assets/"):
        return "ressources Flutter (polices, styles)"
    if name.startswith("res/") or name == "resources.arsc":
        return "ressources Android"
    return "autres"


def elf_debug_bytes(data: bytes) -> int:
    """Octets des sections .debug_* d'un ELF 64 ou 32 bits (0 si absent ou illisible)."""
    if data[:4] != b"\x7fELF":
        return 0
    is64 = data[4] == 2
    endian = "<" if data[5] == 1 else ">"
    try:
        if is64:
            shoff, = struct.unpack_from(endian + "Q", data, 0x28)
            shentsize, shnum, shstrndx = struct.unpack_from(endian + "HHH", data, 0x3A)
        else:
            shoff, = struct.unpack_from(endian + "I", data, 0x20)
            shentsize, shnum, shstrndx = struct.unpack_from(endian + "HHH", data, 0x2E)

        def section(i: int):
            base = shoff + i * shentsize
            if is64:
                name, _type, _flags, _addr, off, size = struct.unpack_from(endian + "IIQQQQ", data, base)
            else:
                name, _type, _flags, _addr, off, size = struct.unpack_from(endian + "IIIIII", data, base)
            return name, off, size

        _, str_off, _ = section(shstrndx)
        total = 0
        for i in range(shnum):
            name_off, _, size = section(i)
            end = data.index(b"\0", str_off + name_off)
            if data[str_off + name_off:end].startswith(b".debug"):
                total += size
        return total
    except (struct.error, ValueError):
        return 0


def report(path: str) -> None:
    with zipfile.ZipFile(path) as apk:
        rows = []
        for info in apk.infolist():
            if info.is_dir():
                continue
            data = apk.read(info)
            rows.append((info.filename, info.file_size, info.compress_size, len(zlib.compress(data, 9)), data))
    stored = sum(r[2] for r in rows)
    download = sum(r[3] for r in rows)
    print(f"== {path.rsplit('/', 1)[-1]} : {ko(stored)} dans l'APK, téléchargement estimé {ko(download)}")
    families: dict[str, list[int]] = {}
    for name, size, comp, z, _ in rows:
        f = families.setdefault(family(name), [0, 0, 0])
        f[0] += size
        f[1] += comp
        f[2] += z
    print(f"{'famille':45} {'décompressé':>12} {'dans l’APK':>12} {'à télécharger':>14}")
    for name, (size, comp, z) in sorted(families.items(), key=lambda kv: -kv[1][1]):
        print(f"{name:45} {ko(size):>12} {ko(comp):>12} {ko(z):>14}")
    for name, _, _, _, data in rows:
        if name.endswith(".so"):
            debug = elf_debug_bytes(data)
            if debug:
                print(f"  {name} : sections de débogage {ko(debug)}")


if __name__ == "__main__":
    for apk_path in sys.argv[1:]:
        report(apk_path)
