"""Biblioteca para gerar os modelos do Arena Rift no Blender (bpy).

Convenções: Blender Z para cima, personagem olhando para -Y (vira +Z no Godot).
Cada personagem é UMA malha com esqueleto e várias animações (glTF/.glb).
"""
import math
import bpy
import bmesh
from mathutils import Vector, Matrix, Euler

R = math.radians


# ---------------------------------------------------------------- cena

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def activate(ob):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)


# ---------------------------------------------------------------- materiais

def lin(c):
    """Cor em sRGB (como num editor de imagem) para o espaço linear do Blender."""
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def mat(name, color, metallic=0.0, rough=0.55, emit=None, strength=0.0, alpha=1.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    color = lin(color)
    if emit is not None:
        emit = lin(emit)
    m = bpy.data.materials.new(name)
    if hasattr(m, "use_nodes"):
        m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1.0)
        b.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            m.blend_method = "BLEND"
    return m


def set_mat(ob, m):
    ob.data.materials.clear()
    ob.data.materials.append(m)
    return ob


# ---------------------------------------------------------------- malhas

def finalize(ob, smooth=True):
    """Aplica todos os modificadores e deixa a malha suave."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    ob.modifiers.clear()
    old = ob.data
    ob.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    for p in me.polygons:
        p.use_smooth = smooth
    return ob


def skin(name, verts, edges, radii, root=0, subdiv=2, m=None):
    """Forma orgânica a partir de um 'esqueleto' de pontos com raios."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([Vector(v) for v in verts], edges, [])
    ob = link(bpy.data.objects.new(name, me))
    ob.modifiers.new("Skin", "SKIN")
    sv = me.skin_vertices[0].data
    for i, r in enumerate(radii):
        sv[i].radius = r if isinstance(r, (tuple, list)) else (r, r)
    sv[root].use_root = True
    if subdiv:
        s = ob.modifiers.new("Sub", "SUBSURF")
        s.levels = subdiv
        s.render_levels = subdiv
    finalize(ob)
    if m:
        set_mat(ob, m)
    return ob


def prim(kind, m, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), name="p", bevel=0.0, subdiv=0, smooth=True, **kw):
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1.0)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=kw.get("seg", 20), ring_count=kw.get("rings", 12), radius=1.0)
    elif kind == "ico":
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=kw.get("sub", 2), radius=1.0)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("seg", 16), radius=1.0, depth=1.0)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=kw.get("seg", 16), radius1=kw.get("r1", 1.0), radius2=kw.get("r2", 0.0), depth=1.0)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_segments=kw.get("seg", 32), minor_segments=kw.get("mseg", 8),
                                         major_radius=1.0, minor_radius=kw.get("minor", 0.15))
    ob = bpy.context.active_object
    ob.name = name
    ob.location = loc
    ob.rotation_euler = Euler([R(a) for a in rot])
    ob.scale = scale
    if bevel > 0:
        b = ob.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
    if subdiv:
        s = ob.modifiers.new("Sub", "SUBSURF")
        s.levels = subdiv
    if kind in ("cube",) and not bevel and not subdiv:
        smooth = False
    # aplica transformações
    activate(ob)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    finalize(ob, smooth)
    set_mat(ob, m)
    return ob


def blade(name, m, length=1.6, width=0.18, thick=0.04, loc=(0, 0, 0), rot=(0, 0, 0), curve=0.0):
    """Lâmina afiada (losango achatado com ponta)."""
    bm = bmesh.new()
    n = 8
    verts_l, verts_r = [], []
    for i in range(n + 1):
        t = i / n
        w = width * (1.0 - t ** 2.5) if t < 1 else 0.0
        y = t * length
        x_off = curve * math.sin(t * math.pi * 0.5)
        verts_l.append(bm.verts.new((x_off - w, 0, y)))
        verts_r.append(bm.verts.new((x_off + w, 0, y)))
    front = [bm.verts.new((curve * math.sin(i / n * math.pi * 0.5), -thick * (1 - i / n), i / n * length)) for i in range(n + 1)]
    back = [bm.verts.new((curve * math.sin(i / n * math.pi * 0.5), thick * (1 - i / n), i / n * length)) for i in range(n + 1)]
    for i in range(n):
        for side, mid in ((verts_l, front), (verts_r, front), (verts_l, back), (verts_r, back)):
            try:
                bm.faces.new((side[i], side[i + 1], mid[i + 1], mid[i]))
            except ValueError:
                pass
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    activate(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    ob.location = loc
    ob.rotation_euler = Euler([R(a) for a in rot])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for p in me.polygons:
        p.use_smooth = False
    set_mat(ob, m)
    return ob


def curve_tube(name, m, points, radius=0.03, taper=None, res=12):
    """Tubo ao longo de pontos (arcos, chifres, cabelo, cordas)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 3
    cu.resolution_u = res
    sp = cu.splines.new("POLY" if len(points) < 3 else "NURBS")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (*p, 1.0)
        if taper:
            sp.points[i].radius = taper[i]
    if sp.type == "NURBS":
        sp.use_endpoint_u = True
        sp.order_u = 3
    ob = link(bpy.data.objects.new(name, cu))
    activate(ob)
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.active_object
    for p in ob.data.polygons:
        p.use_smooth = True
    set_mat(ob, m)
    return ob


def plane_shape(name, m, outline, thickness=0.02, loc=(0, 0, 0), rot=(0, 0, 0), subdiv=1):
    """Placa a partir de um contorno 2D (asas, capas, penas)."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, 0, y)) for x, y in outline]
    bm.faces.new(vs)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    sol = ob.modifiers.new("Solid", "SOLIDIFY")
    sol.thickness = thickness
    if subdiv:
        s = ob.modifiers.new("Sub", "SUBSURF")
        s.levels = subdiv
    ob.location = loc
    ob.rotation_euler = Euler([R(a) for a in rot])
    activate(ob)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    finalize(ob)
    set_mat(ob, m)
    return ob


def displace(ob, strength=0.15, size=0.6, seed=0):
    tex = bpy.data.textures.new("noise%d" % seed, "VORONOI")
    tex.noise_scale = size
    d = ob.modifiers.new("Disp", "DISPLACE")
    d.texture = tex
    d.strength = strength
    finalize(ob, smooth=False)
    return ob


def join(objs, name):
    activate(objs[0])
    for o in objs[1:]:
        o.select_set(True)
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    return ob


# ---------------------------------------------------------------- esqueleto

class Rig:
    """Esqueleto humanoide simples + pesos automáticos por distância aos ossos."""

    def __init__(self, name, bones):
        # bones: lista de (nome, cabeça, cauda, pai)
        self.bones = bones
        arm = bpy.data.armatures.new(name + "_rig")
        self.ob = link(bpy.data.objects.new(name + "_rig", arm))
        activate(self.ob)
        bpy.ops.object.mode_set(mode="EDIT")
        for n, h, t, p in bones:
            b = arm.edit_bones.new(n)
            b.head = h
            b.tail = t
            b.roll = 0.0
            if p:
                b.parent = arm.edit_bones[p]
                b.use_connect = False
        bpy.ops.object.mode_set(mode="OBJECT")
        self.seg = {n: (Vector(h), Vector(t)) for n, h, t, p in bones}

    def bind(self, ob, rigid=None, exclude=()):
        """rigid: dict nome_do_objeto -> osso (peças duras presas a um osso)."""
        for n in self.seg:
            if n not in ob.vertex_groups:
                ob.vertex_groups.new(name=n)
        groups = {g.name: g for g in ob.vertex_groups}
        me = ob.data
        for v in me.verts if hasattr(me, "verts") else me.vertices:
            p = v.co
            ds = []
            for n, (a, b) in self.seg.items():
                if n in exclude:
                    continue
                ab = b - a
                t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-6)))
                d = (p - (a + ab * t)).length
                ds.append((d, n))
            ds.sort()
            (d0, n0), (d1, n1) = ds[0], ds[1]
            w0 = 1.0 / (d0 + 0.02) ** 4
            w1 = 1.0 / (d1 + 0.02) ** 4
            if d1 > d0 * 1.8:
                w1 = 0.0
            s = w0 + w1
            groups[n0].add([v.index], w0 / s, "REPLACE")
            if w1 > 0:
                groups[n1].add([v.index], w1 / s, "REPLACE")
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = self.ob
        ob.parent = self.ob
        return ob

    @staticmethod
    def rigid_part(ob, bone):
        """Marca todos os vértices de uma peça para um único osso."""
        g = ob.vertex_groups.new(name=bone)
        g.add([v.index for v in ob.data.vertices], 1.0, "REPLACE")
        return ob

    def anim(self, name, frames, keys, loop=True):
        """keys: {quadro: {osso: (rx, ry, rz) em graus, ou osso+'@loc': (x,y,z)}}"""
        ob = self.ob
        if ob.animation_data is None:
            ob.animation_data_create()
        ob.animation_data.action = None
        for pb in ob.pose.bones:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
        used = set()
        for f, pose in keys.items():
            used.update(pose.keys())
        for f in sorted(keys):
            for pb in ob.pose.bones:
                pb.rotation_euler = (0, 0, 0)
                pb.location = (0, 0, 0)
            for bn, val in keys[f].items():
                if bn.endswith("@loc"):
                    pb = ob.pose.bones[bn[:-4]]
                    pb.location = val
                else:
                    ob.pose.bones[bn].rotation_euler = [R(a) for a in val]
            for bn in used:
                if bn.endswith("@loc"):
                    ob.pose.bones[bn[:-4]].keyframe_insert("location", frame=f)
                else:
                    ob.pose.bones[bn].keyframe_insert("rotation_euler", frame=f)
        act = ob.animation_data.action
        act.name = name
        act.use_fake_user = True
        track = ob.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 1, act)
        strip.name = name
        ob.animation_data.action = None
        return act


def export_glb(path, objs=None):
    for o in bpy.context.view_layer.objects:
        o.select_set(objs is None or o in objs)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=objs is not None,
        export_apply=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_yup=True,
        export_skins=True,
        export_morph=False,
    )


def place(ob, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Move/gira uma peça montada na origem e aplica a transformação."""
    ob.location = loc
    ob.rotation_euler = Euler([R(a) for a in rot])
    ob.scale = scale
    activate(ob)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob
