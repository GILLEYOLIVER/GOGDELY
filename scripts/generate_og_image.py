"""Pure-Python generator for the GOGDELY og:image placeholder.

Creates a valid 1200x630 PNG in the approved electric-blue brand color
(DESIGN_SYSTEM.md `brandPrimary` #2563EB) with a graphite band, without any
external image dependency. The final brand artwork depends on the pending
visual identity decision (GOG-088) and replaces this placeholder later.
"""
import struct
import sys
import zlib
from pathlib import Path

WIDTH, HEIGHT = 1200, 630
BLUE = (0x25, 0x63, 0xEB)
GRAPHITE = (0x15, 0x1B, 0x2B)
BAND_HEIGHT = 90


def _chunk(kind: bytes, data: bytes) -> bytes:
    return (struct.pack(">I", len(data)) + kind + data +
            struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))


def build_png() -> bytes:
    rows = []
    for y in range(HEIGHT):
        color = GRAPHITE if y < BAND_HEIGHT else BLUE
        rows.append(b"\x00" + bytes(color) * WIDTH)
    raw = b"".join(rows)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 2, 0, 0, 0))
        + _chunk(b"IDAT", zlib.compress(raw, 9))
        + _chunk(b"IEND", b"")
    )


def main() -> None:
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("gogdely_api/static/og-image.png")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(build_png())
    print(f"og-image.png gerado: {target} ({target.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
