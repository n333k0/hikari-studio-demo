"""Re-export a .glb as a .usdz with PNG textures, without touching its geometry.

    blender --background --python scripts/3d/export_usdz.py -- --glb models/ensui-d50.glb

This is the standalone fix for the "solid violet lamp in Quick Look" bug: our
GLBs carry WebP textures (from `gltf-transform optimize --texture-compress webp`),
Blender's USD exporter preserves the source codec, and RealityKit cannot decode
WebP inside a .usdz — so it renders the missing-texture magenta placeholder.

Use this for any product whose USDZ needs regenerating but whose model is
otherwise fine. Pendant lamps that also need the hang offset go through
pendant_hang.py instead, which ends with this same conversion.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _common as C  # noqa: E402


def parse_args():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--glb', required=True, help='input .glb (never modified)')
    p.add_argument('--usdz', help='output .usdz (default: sibling of --glb)')
    return p.parse_args(argv)


def main():
    args = parse_args()
    glb_in = os.path.abspath(args.glb)
    usdz_out = os.path.abspath(args.usdz or os.path.splitext(glb_in)[0] + '.usdz')

    C.reset_and_import(glb_in)
    C.report_bbox('imported')
    C.images_to_png()
    C.export_usdz(usdz_out)


if __name__ == '__main__':
    main()
