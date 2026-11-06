"""Blender (headless) pipeline: MihaM's "Walther PPK" (Sketchfab, CC BY 4.0) -> Project Zomboid B42 assets.

Run:
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup \
      --python tools/build_model.py -- [--src assets/source/walther_ppk.glb] [--target-verts 1000]

Input : assets/source/walther_ppk.glb (falls back to any .glb/.gltf/.dae in assets/source/).
Output (mod root workshop/WaltherPPKS/Contents/mods/WaltherPPKS/42/media):
  models_X/weapons/PPKS.fbx      reduced mesh, PZ weapon layout
  textures/weapons/PPKS.png      256x256 diffuse (base colour x ambient occlusion from the source textures)
  textures/Item_PPKS.png         32x32 inventory icon (rendered)

What it does to the source model:
  * removes the suppressor (everything in front of the slide, --cut-y in source units),
  * reduces polygons to about --target-verts game vertices (UV seams counted),
  * scales it to real PPK proportions relative to the vanilla M9 (PZ pistols are ~0.69 of real size),
  * places it in the PZ firearm layout used by vanilla/Marz pistols: X = width, +Y = muzzle, +Z = up,
    origin at the back of the frame above the grip, and writes the FBX the same way Blender-made
    PZ weapon FBX files are written (Y-up file, unit scale 1, identity node transforms).
It prints the muzzle attachment offset to use in the `model PPKS` script block.
"""
import argparse
import glob
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEDIA = os.path.join(ROOT, "workshop", "WaltherPPKS", "Contents", "mods", "WaltherPPKS", "42", "media")
OUT_FBX = os.path.join(MEDIA, "models_X", "weapons", "PPKS.fbx")
OUT_TEX = os.path.join(MEDIA, "textures", "weapons", "PPKS.png")
OUT_ICON = os.path.join(MEDIA, "textures", "Item_PPKS.png")

# Vanilla/Marz M9-class pistol in PZ units: rear of frame y=-0.0075, muzzle y~0.142, slide top z~0.039.
M9_GAME_LENGTH = 0.1494
M9_REAL_MM = 217.0
PPK_REAL_MM = 155.0
TARGET_LENGTH = M9_GAME_LENGTH * PPK_REAL_MM / M9_REAL_MM
REAR_Y = -0.0075
TOP_Z = 0.034


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=None)
    ap.add_argument("--cut-y", type=float, default=0.395,
                    help="source-space Y (after applying transforms) in front of which geometry is removed (suppressor)")
    ap.add_argument("--target-verts", type=int, default=1000)
    ap.add_argument("--tex-size", type=int, default=256)
    return ap.parse_args(argv)


def find_source(arg):
    if arg:
        return os.path.abspath(arg)
    src_dir = os.path.join(ROOT, "assets", "source")
    preferred = os.path.join(src_dir, "walther_ppk.glb")
    if os.path.exists(preferred):
        return preferred
    for ext in ("glb", "gltf", "dae"):
        found = sorted(glob.glob(os.path.join(src_dir, "*." + ext)))
        if found:
            return found[0]
    sys.exit("No source model in %s (expected walther_ppk.glb, or any .glb/.gltf/.dae)" % src_dir)


def import_source(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ext = os.path.splitext(path)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".dae":
        if not hasattr(bpy.ops.wm, "collada_import"):
            sys.exit("This Blender has no Collada importer; use the .glb download instead")
        bpy.ops.wm.collada_import(filepath=path)
    else:
        sys.exit("Unsupported source format: " + ext)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in bpy.data.objects:
        o.select_set(o.type == "MESH")
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    for o in [o for o in bpy.data.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o)
    obj = bpy.context.view_layer.objects.active
    obj.name = "PPKS"
    obj.data.name = "PPKS"
    return obj


def channel_source(mat, to_socket_name):
    """(image, channel) feeding a socket through a Separate Color node, or None."""
    for link in mat.node_tree.links:
        if link.to_socket.name == to_socket_name and link.from_node.type == "SEPARATE_COLOR":
            sep = link.from_node
            ch = {"Red": 0, "Green": 1, "Blue": 2}[link.from_socket.name]
            for l2 in mat.node_tree.links:
                if l2.to_node == sep and l2.from_node.type == "TEX_IMAGE":
                    return (l2.from_node.image, ch)
    return None


def base_color_and_ao(obj):
    """Return (base colour image, ao (image, channel) or None, metallic (image, channel) or None)."""
    mat = obj.material_slots[0].material
    base = None
    for link in mat.node_tree.links:
        n, sock = link.from_node, link.to_socket
        if n.type == "TEX_IMAGE" and sock.name == "Base Color":
            base = n.image
    if base is None:
        sys.exit("No base colour texture found on the source material")
    return base, channel_source(mat, "Occlusion"), channel_source(mat, "Metallic")


def strip_suppressor(obj, cut_y):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=(0, cut_y, 0), plane_no=(0, 1, 0), clear_outer=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(obj.data)
    bm.free()


def game_vertex_count(me):
    """Vertices after splitting on UV seams (what the game loads)."""
    uv = me.uv_layers.active.data
    keys = set()
    for loop in me.loops:
        u = uv[loop.index].uv
        keys.add((loop.vertex_index, round(u.x, 4), round(u.y, 4)))
    return len(keys)


def decimate(obj, target):
    original = obj.data.copy()
    lo, hi = 0.01, 1.0
    best = None
    for _ in range(14):
        ratio = (lo + hi) / 2
        obj.data = original.copy()
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
        n = game_vertex_count(obj.data)
        if n <= target:
            best = (ratio, obj.data.copy(), n)
            lo = ratio
        else:
            hi = ratio
    obj.data = best[1]
    obj.data.name = "PPKS"
    print("DECIMATE ratio %.3f -> %d game verts, %d tris" % (best[0], best[2], len(obj.data.polygons)))


def normalize(obj):
    """Scale/translate into the PZ pistol layout (meters, +Y muzzle, +Z up)."""
    me = obj.data
    co = np.array([v.co[:] for v in me.vertices])
    mn, mx = co.min(0), co.max(0)
    s = TARGET_LENGTH / (mx[1] - mn[1])
    off = Vector((-(mn[0] + mx[0]) / 2 * s, REAR_Y - mn[1] * s, TOP_Z - mx[2] * s))
    me.transform(Matrix.Translation(off) @ Matrix.Scale(s, 4))
    me.update()
    co = np.array([v.co[:] for v in me.vertices])
    # bore height: mid of the barrel verts at the very front
    front = co[co[:, 1] > co[:, 1].max() - 0.002]
    front = front[np.abs(front[:, 0]) < 0.004]
    bore_z = (front[:, 2].min() + front[:, 2].max()) / 2 if len(front) else co[:, 2].max() - 0.008
    print("LAYOUT min", np.round(co.min(0), 4), "max", np.round(co.max(0), 4), "scale %.5f" % s)
    print("ATTACH muzzle offset = 0.0 %.4f %.4f  (script z = -mesh z)" % (co[:, 1].max(), -bore_z))
    print("ATTACH world offset y ~ %.4f (lengthwise centre)" % ((co[:, 1].min() + co[:, 1].max()) / 2))
    return co


def _channel(src, w, h):
    if src is None or tuple(src[0].size) != (w, h):
        return None
    return np.array(src[0].pixels[:], dtype=np.float32).reshape(h, w, 4)[:, :, src[1]]


def bake_texture(base, ao, metal, size, path):
    """PZ shades with a diffuse texture only, so fold the PBR look into it:
    metallic areas (PBR albedo = dark specular tint) are lifted to read as polished steel,
    and ambient occlusion is applied at half strength."""
    w, h = base.size
    px = np.array(base.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = px[:, :, :3]
    m = _channel(metal, w, h)
    if m is not None:
        lifted = np.clip(rgb * 1.5 + 0.18, 0.0, 1.0)
        rgb = rgb * (1 - m[:, :, None]) + lifted * m[:, :, None]
    a = _channel(ao, w, h)
    if a is not None:
        rgb = rgb * (0.5 + 0.5 * a[:, :, None])
    px[:, :, :3] = rgb
    px[:, :, 3] = 1.0
    out = bpy.data.images.new("PPKS_tex", w, h, alpha=False)
    out.pixels[:] = px.ravel()
    out.scale(size, size)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    print("wrote", path)
    return out


def set_material(obj, img):
    mat = bpy.data.materials.new("PPKS")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def export_fbx(obj, path):
    # PZ reads raw FBX vertex coordinates. Blender's FBX writer converts Z-up -> Y-up (x, y, z) -> (x, z, -y)
    # and FBX_SCALE_NONE writes centimetres; so pre-transform Blender coords = 0.01 * (x, -z, y).
    me = obj.data.copy()
    to_blender = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1))) @ Matrix.Scale(0.01, 4)
    me.transform(to_blender)
    exp = bpy.data.objects.new("PPKS_export", me)
    bpy.context.scene.collection.objects.link(exp)
    for o in bpy.context.scene.objects:
        o.select_set(o == exp)
    exp.name = "PPKS"
    obj.name = "PPKS_work"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"},
                             axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_NONE",
                             bake_space_transform=True, global_scale=1.0, mesh_smooth_type="FACE",
                             use_mesh_modifiers=False, add_leaf_bones=False, bake_anim=False,
                             path_mode="STRIP", embed_textures=False)
    bpy.data.objects.remove(exp)
    print("wrote", path)


def render_icon(obj, path, size=32):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = 256
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.6, 0.62, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.4
    sc.world = world
    co = np.array([v.co[:] for v in obj.data.vertices])
    centre = Vector(((co.min(0) + co.max(0)) / 2).tolist())
    span = float((co.max(0) - co.min(0)).max())
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = span * 1.08
    # right side of the gun, muzzle to the right, slightly from above
    d = Vector((1.0, 0.0, 0.25)).normalized()
    cam.location = centre + d * span * 4
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), math.radians(-30), math.radians(-60))
    sc.collection.objects.link(sun)
    tmp = path + ".big.png"
    sc.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    big = bpy.data.images.load(tmp)
    big.scale(size, size)
    px = np.array(big.pixels[:], dtype=np.float32).reshape(size, size, 4)
    # PZ-style dark 1px outline around the silhouette
    a = px[:, :, 3] > 0.35
    px[:, :, 3] = np.where(a, 1.0, 0.0)
    grown = a.copy()
    grown[1:, :] |= a[:-1, :]
    grown[:-1, :] |= a[1:, :]
    grown[:, 1:] |= a[:, :-1]
    grown[:, :-1] |= a[:, 1:]
    edge = grown & ~a
    px[edge] = (0.08, 0.07, 0.07, 1.0)
    out = bpy.data.images.new("icon", size, size, alpha=True)
    out.pixels[:] = px.ravel()
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    os.remove(tmp)
    print("wrote", path)


def main():
    a = parse_args()
    src = find_source(a.src)
    print("SOURCE", src)
    obj = import_source(src)
    base, ao, metal = base_color_and_ao(obj)
    print("SOURCE verts", len(obj.data.vertices), "base", base.name, tuple(base.size),
          "ao", ao and ao[0].name, "metal", metal and metal[0].name)
    strip_suppressor(obj, a.cut_y)
    decimate(obj, a.target_verts)
    normalize(obj)
    tex = bake_texture(base, ao, metal, a.tex_size, OUT_TEX)
    set_material(obj, tex)
    export_fbx(obj, OUT_FBX)
    obj.name = "PPKS"
    render_icon(obj, OUT_ICON)


main()
