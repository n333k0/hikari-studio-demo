"""Shared Blender helpers for the Hikari 3D/AR model pipeline.

Imported by the sibling scripts via sys.path insertion — see pendant_hang.py.
Blender is Z-up; the glTF/USD importers and exporters handle the conversion to
and from glTF's Y-up, so everything in here works in Blender's Z-up space.
"""

import os
import tempfile

import bpy
from mathutils import Vector


# ---------------------------------------------------------------- scene i/o

def reset_and_import(glb_path):
    """Wipe the default scene and import a .glb."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    return [ob for ob in bpy.data.objects if ob.type == 'MESH']


def sync():
    """Flush pending transforms into matrix_world.

    Assigning `ob.location` does not update `ob.matrix_world` until the depsgraph
    re-evaluates, so any measurement taken right after a move silently reads the
    *old* position. Every bbox helper below calls this first.
    """
    bpy.context.view_layer.update()


def world_bbox(objects=None):
    """World-space bounding box over the given (or all visible) mesh objects."""
    sync()
    if objects is None:
        objects = [ob for ob in bpy.data.objects
                   if ob.type == 'MESH' and ob.visible_get()]
    corners = [ob.matrix_world @ Vector(c) for ob in objects for c in ob.bound_box]
    if not corners:
        raise RuntimeError('no mesh geometry to measure')
    mn = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    mx = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    return mn, mx


def obj_bbox(ob):
    sync()
    corners = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    mn = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    mx = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    return mn, mx


def report_bbox(label, objects=None):
    mn, mx = world_bbox(objects)
    size = mx - mn
    print(f'[bbox] {label}: min=({mn.x:.4f}, {mn.y:.4f}, {mn.z:.4f}) '
          f'max=({mx.x:.4f}, {mx.y:.4f}, {mx.z:.4f}) '
          f'size=({size.x:.4f}, {size.y:.4f}, {size.z:.4f})')
    return mn, mx


# ------------------------------------------------------------ the AR anchor

def add_floor_anchor(size=0.001, name='ar_floor_anchor'):
    """Add the tiny mesh that tells every AR runtime where this model's floor is.

    Every AR runtime we ship to (iOS Quick Look, Android Scene Viewer, WebXR)
    rests the *lowest point of the bounding box* on the detected plane — there is
    no ceiling anchor and no height offset API anywhere in web AR. So a pendant
    lamp only appears to hang if the model itself carries an empty gap from z=0
    up to the shade, held open by a marker at the origin.

    Two traps this deliberately avoids:
      * The marker must be VISIBLE. model-viewer measures the bounding box with
        three.js `traverseVisible()`, so a hidden node is not counted and the
        whole trick silently collapses back to a floor-resting lamp.
      * The marker must NOT be a flat transparent plane. model-viewer's
        `findBakedShadows()` treats any transparent mesh flatter than
        MIN_SHADOW_RATIO (100:1) as a baked floor shadow and *excludes it from
        the bounding box*. A tiny opaque cube fails that test and survives.
    """
    mesh = bpy.data.meshes.new(name)
    half = size / 2.0
    verts = [(-half, -half, 0.0), (half, -half, 0.0), (half, half, 0.0), (-half, half, 0.0),
             (-half, -half, size), (half, -half, size), (half, half, size), (-half, half, size)]
    faces = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    mesh.from_pydata(verts, [], faces)
    mesh.update()

    mat = bpy.data.materials.new(name + '_mat')
    mat.use_nodes = True
    mat.blend_method = 'OPAQUE'
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.0, 0.0, 0.0, 1.0)
        bsdf.inputs['Alpha'].default_value = 1.0
    mesh.materials.append(mat)

    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = (0.0, 0.0, 0.0)
    return ob


# ------------------------------------------------------- texture conversion

def images_to_png(tmpdir=None):
    """Re-encode every image datablock to PNG and relink the material nodes.

    This is the fix from commit 4ccdcc5, generalised. Blender's USD exporter
    preserves the source glTF's texture codec, and our GLBs come out of
    `gltf-transform optimize --texture-compress webp`. AR Quick Look / RealityKit
    cannot decode WebP inside a .usdz and falls back to its missing-texture
    magenta placeholder — the "solid violet lamp" bug.

    Rather than unpacking in place (which writes the original WebP bytes back to
    disk), this loads a fresh PNG datablock and swaps the node references, so
    there is no way for a stale WebP to survive into the export.
    """
    # A real temp dir, never a sibling of the models — these are throwaway
    # intermediates and must not land in the repo.
    tmpdir = tmpdir or tempfile.mkdtemp(prefix='hikari-png-')
    os.makedirs(tmpdir, exist_ok=True)
    swapped = {}

    for img in list(bpy.data.images):
        if img.type != 'IMAGE' or img.size[0] == 0:
            continue
        if img.file_format == 'PNG' and not img.packed_file:
            continue

        safe = ''.join(ch if ch.isalnum() or ch in '-_' else '_' for ch in img.name)
        out_path = os.path.join(tmpdir, safe + '.png')
        colorspace = img.colorspace_settings.name

        img.filepath_raw = out_path
        img.file_format = 'PNG'
        img.save()

        fresh = bpy.data.images.load(out_path, check_existing=False)
        fresh.colorspace_settings.name = colorspace
        swapped[img.name] = fresh
        print(f'[tex] {img.name}: {colorspace} -> {out_path}')

    if not swapped:
        print('[tex] nothing to convert (already PNG)')
        return 0

    relinked = 0
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        for node in mat.node_tree.nodes:
            if node.type == 'TEX_IMAGE' and node.image is not None:
                fresh = swapped.get(node.image.name)
                if fresh is not None:
                    node.image = fresh
                    relinked += 1
    print(f'[tex] relinked {relinked} texture node(s) across {len(bpy.data.materials)} material(s)')
    return relinked


# ------------------------------------------------------------------ exports

def _filtered_kwargs(op, kwargs):
    """Drop kwargs the installed Blender's operator does not define."""
    props = op.get_rna_type().properties.keys()
    kept, dropped = {}, []
    for key, value in kwargs.items():
        if key in props:
            kept[key] = value
        else:
            dropped.append(key)
    if dropped:
        print(f'[export] skipping unsupported options for this Blender: {dropped}')
    return kept


def export_glb(path, keep_webp=True):
    """Export the scene as .glb, keeping WebP textures so the web payload stays small.

    WebP is *correct* for the GLB (browsers and three.js read EXT_texture_webp
    fine, and it is ~10x smaller than PNG here) and *wrong* for the USDZ. That
    asymmetry is the whole reason this pipeline exports the two formats in
    separate passes.
    """
    kwargs = dict(
        filepath=path,
        export_format='GLB',
        export_image_format='WEBP' if keep_webp else 'AUTO',
        export_image_quality=85,
        export_yup=True,
        export_apply=True,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    bpy.ops.export_scene.gltf(**_filtered_kwargs(bpy.ops.export_scene.gltf, kwargs))
    print(f'[export] glb -> {path} ({os.path.getsize(path)} bytes)')


def export_usdz(path):
    """Export the scene as .usdz for iOS AR Quick Look."""
    kwargs = dict(
        filepath=path,
        selected_objects_only=False,
        export_materials=True,
        export_textures=True,
        generate_preview_surface=True,
        export_animation=False,
        export_cameras=False,
        export_lights=False,
        relative_paths=False,
        usdz_downscale_size='KEEP',
    )
    bpy.ops.wm.usd_export(**_filtered_kwargs(bpy.ops.wm.usd_export, kwargs))
    print(f'[export] usdz -> {path} ({os.path.getsize(path)} bytes)')
