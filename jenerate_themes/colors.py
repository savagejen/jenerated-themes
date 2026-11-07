"""Colors: the forms templates use, luminance and contrast, and blending."""

import colorsys
import re

HEX = re.compile(r"#[0-9a-fA-F]{6}")


def srgb_to_linear(channel):
    """An sRGB channel (0-255) in linear light (0-1), by the sRGB curve."""
    c = channel / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def color_formats(key, value):
    """The other forms of a #rrggbb color that templates can use."""
    r, g, b = (int(value[i:i + 2], 16) for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return {
        f"{key}_hex": value[1:],
        f"{key}_rgb": f"{r}, {g}, {b}",
        f"{key}_rgb_csv": f"{r},{g},{b}",
        f"{key}_rgb_spaced": f"{r} {g} {b}",
        f"{key}_rgb16": f"{r * 257},{g * 257},{b * 257}",
        f"{key}_int": str((r << 16) | (g << 8) | b),
        f"{key}_float": f"{r / 255:.4f}, {g / 255:.4f}, {b / 255:.4f}",
        f"{key}_float_spaced": f"{r / 255:.4f} {g / 255:.4f} {b / 255:.4f}",
        f"{key}_linear_r": f"{srgb_to_linear(r):.6f}",
        f"{key}_linear_g": f"{srgb_to_linear(g):.6f}",
        f"{key}_linear_b": f"{srgb_to_linear(b):.6f}",
        f"{key}_h": str(round(h * 360) % 360),
        f"{key}_s": str(round(s * 100)),
        f"{key}_l": str(round(l * 100)),
    }


def luminance(color):
    """A #rrggbb color's relative luminance, as WCAG defines it: 0 for black
    to 1 for white."""
    channels = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
              for c in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(a, b):
    """The WCAG contrast ratio of two #rrggbb colors, from 1 (the same) to 21
    (black and white)."""
    light, dark = sorted((luminance(a), luminance(b)), reverse=True)
    return (light + 0.05) / (dark + 0.05)


def scheme_of(color):
    """ "light" for a background black text reads better on, else "dark"."""
    # The contrast with black beats the contrast with white.
    return "light" if contrast(color, "#000000") > contrast(color, "#ffffff") else "dark"


def blend(top, bottom, percent):
    """#rrggbb for the color `top` laid over `bottom` at `percent` (0-100),
    as it looks with that much opacity."""
    channels = [round(int(t, 16) * percent / 100 + int(b, 16) * (100 - percent) / 100)
                for t, b in ((top[i:i + 2], bottom[i:i + 2]) for i in (1, 3, 5))]
    return "#" + "".join(f"{c:02x}" for c in channels)
