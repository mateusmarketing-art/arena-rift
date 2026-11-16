"""Tropas, monstros, estruturas, vegetação e malhas de efeitos."""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from humanoid import *

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")

# "Team" e "TeamGlow" são recoloridos no Godot com a cor do time.


def team_mats():
    return (mat("Team", (0.85, 0.85, 0.9), rough=0.45),
            mat("TeamGlow", (1, 1, 1), emit=(1, 1, 1), strength=2.0))


# ---------------------------------------------------------------- tropas

def minion_melee():
    reset()
    S = 0.8
    J = skeleton(S, bulk=1.2, legs=0.95)
    rig = Rig("melee", bones(J))
    team, tglow = team_mats()
    metal = mat("Metal", (0.6, 0.62, 0.68), metallic=0.35, rough=0.3)
    dark = mat("Dark", (0.15, 0.13, 0.13), rough=0.6)
    skin_m = mat("Skin", (0.85, 0.68, 0.55))
    b = body(J, dark, S, bulk=1.2, chest=1.1)
    parts = [(head(J, skin_m, S, size=1.25), "head"), (hand(J, "L", dark, S, 1.4), "hand.L"), (hand(J, "R", dark, S, 1.4), "hand.R")]
    hd, ch, pel = Vector(J["head"]), Vector(J["chest"]), Vector(J["pelvis"])
    parts.append((prim("sphere", metal, loc=hd + Vector((0, 0.02, 0.2 * S)), scale=(0.21 * S, 0.22 * S, 0.17 * S), name="helm"), "head"))
    parts.append((prim("cone", team, loc=hd + Vector((0, 0.0, 0.42 * S)), scale=(0.05, 0.05, 0.16), name="plume"), "head"))
    parts.append((prim("sphere", team, loc=ch, scale=(0.24 * S, 0.17 * S, 0.22 * S), name="tabard"), "chest"))
    parts.append((prim("cone", team, loc=pel + Vector((0, 0, -0.08)), scale=(0.2 * S, 0.16 * S, 0.25), r1=1, r2=0.8, name="skirt"), "root"))
    sh = prim("cyl", metal, loc=(0, 0, 0), rot=(0, 90, 0), scale=(0.3, 0.3, 0.06), name="shield", seg=20)
    boss_ = prim("sphere", team, loc=(0.04, 0, 0), scale=(0.08, 0.14, 0.14), name="boss")
    shield = join([sh, boss_], "shieldg")
    place(shield, loc=(Vector(J["elbow.L"]) + Vector(J["wrist.L"])) / 2 + Vector((0.12, -0.05, 0)))
    parts.append((shield, "forearm.L"))
    grip = prim("cyl", dark, loc=(0, 0, 0), scale=(0.025, 0.025, 0.18), name="grip")
    bl = blade("blade", metal, length=0.6, width=0.07, thick=0.025, loc=(0, 0, 0.1))
    sword = join([grip, bl], "sword")
    place(sword, loc=Vector(J["hand.R"]), rot=(60, 0, 0))
    parts.append((sword, "hand.R"))
    build("Melee", J, b, parts, rig)
    standard_anims(rig, "sword")
    export_glb(os.path.join(OUT, "minion_melee.glb"))


def minion_ranged():
    reset()
    S = 0.8
    J = skeleton(S, bulk=1.0)
    rig = Rig("ranged", bones(J))
    team, tglow = team_mats()
    robe = mat("Robe", (0.25, 0.22, 0.28), rough=0.7)
    skin_m = mat("Skin", (0.85, 0.68, 0.55))
    wood = mat("Wood", (0.4, 0.26, 0.15), rough=0.8)
    b = body(J, robe, S, bulk=1.0)
    parts = [(head(J, skin_m, S, size=1.25), "head"), (hand(J, "L", skin_m, S, 1.3), "hand.L"), (hand(J, "R", skin_m, S, 1.3), "hand.R")]
    hd, pel = Vector(J["head"]), Vector(J["pelvis"])
    parts.append((prim("sphere", team, loc=hd + Vector((0, 0.04, 0.18 * S)), scale=(0.23 * S, 0.24 * S, 0.22 * S), name="hood"), "head"))
    parts.append((prim("cone", team, loc=hd + Vector((0, 0.04, 0.5 * S)), scale=(0.1, 0.1, 0.22), name="tip"), "head"))
    parts.append((prim("cone", robe, loc=pel + Vector((0, 0, -0.32)), scale=(0.3 * S, 0.26 * S, 0.75 * S), r1=1, r2=0.5, name="gown"), "root"))
    staff = prim("cyl", wood, loc=(0, 0, 0.3), scale=(0.025, 0.025, 1.3), name="staff")
    orb = prim("sphere", tglow, loc=(0, 0, 1.0), scale=(0.09, 0.09, 0.09), name="orb")
    st = join([staff, orb], "staffg")
    place(st, loc=Vector(J["hand.R"]), rot=(10, 0, 0))
    parts.append((st, "hand.R"))
    build("Ranged", J, b, parts, rig)
    standard_anims(rig, "staff")
    export_glb(os.path.join(OUT, "minion_ranged.glb"))


def minion_siege():
    reset()
    team, tglow = team_mats()
    wood = mat("Wood", (0.42, 0.27, 0.15), rough=0.8)
    metal = mat("Metal", (0.35, 0.36, 0.4), metallic=0.4, rough=0.35)
    parts = [prim("cube", wood, loc=(0, 0, 0.6), scale=(1.2, 1.7, 0.5), bevel=0.06, name="cart")]
    parts.append(prim("cube", team, loc=(0, 0, 0.88), scale=(1.25, 1.75, 0.08), bevel=0.03, name="trim"))
    for x in (-0.68, 0.68):
        for y in (-0.55, 0.55):
            parts.append(prim("cyl", metal, loc=(x, y, 0.38), rot=(0, 90, 0), scale=(0.36, 0.36, 0.14), name="wheel", seg=16))
            parts.append(prim("cyl", wood, loc=(x * 1.08, y, 0.38), rot=(0, 90, 0), scale=(0.12, 0.12, 0.08), name="hub", seg=10))
    barrel = prim("cyl", metal, loc=(0, -0.45, 1.25), rot=(-70, 0, 0), scale=(0.24, 0.24, 1.5), name="barrel", seg=18)
    mouth = prim("torus", metal, loc=(0, -1.15, 1.5), rot=(-70, 0, 0), scale=(0.28, 0.28, 0.28), name="mouth", minor=0.25)
    core = prim("sphere", tglow, loc=(0, 0.35, 1.05), scale=(0.2, 0.2, 0.2), name="core")
    parts += [barrel, mouth, core]
    join(parts, "Siege")
    export_glb(os.path.join(OUT, "minion_siege.glb"))


# ---------------------------------------------------------------- monstros

def quadruped(name, S, m_body, m_belly, m_horn, m_glow, spikes=0, big=False):
    reset()
    m_body = mat(*m_body)
    m_belly = mat(*m_belly)
    m_horn = mat(*m_horn)
    m_glow = mat(*m_glow[:2], emit=m_glow[1], strength=m_glow[2])
    s = S
    P = {
        "hips": (0, 0.55 * s, 0.95 * s), "back": (0, 0.0, 1.05 * s), "shoulders": (0, -0.55 * s, 1.1 * s),
        "neck": (0, -0.85 * s, 1.35 * s), "head": (0, -1.15 * s, 1.35 * s), "snout": (0, -1.5 * s, 1.2 * s),
        "tail1": (0, 0.95 * s, 1.0 * s), "tail2": (0, 1.4 * s, 1.1 * s), "tail3": (0, 1.8 * s, 1.35 * s),
    }
    for side, sx in (("L", 1), ("R", -1)):
        for fb, y in (("f", -0.55), ("b", 0.55)):
            P["%s_up.%s" % (fb, side)] = (sx * 0.32 * s, y * s, 0.9 * s)
            P["%s_knee.%s" % (fb, side)] = (sx * 0.36 * s, (y + (0.08 if fb == "f" else -0.1)) * s, 0.48 * s)
            P["%s_paw.%s" % (fb, side)] = (sx * 0.36 * s, (y - 0.05) * s, 0.08 * s)
    names = list(P)
    idx = {n: i for i, n in enumerate(names)}
    rad = {"hips": (0.36 * s, 0.32 * s), "back": (0.42 * s, 0.36 * s), "shoulders": (0.45 * s, 0.4 * s), "neck": 0.25 * s,
           "head": (0.27 * s, 0.25 * s), "snout": (0.15 * s, 0.13 * s), "tail1": 0.15 * s, "tail2": 0.1 * s, "tail3": 0.04 * s}
    for n in names:
        if n not in rad:
            rad[n] = (0.15 if "up" in n else 0.1 if "knee" in n else 0.12) * s
    edges = [("hips", "back"), ("back", "shoulders"), ("shoulders", "neck"), ("neck", "head"), ("head", "snout"),
             ("hips", "tail1"), ("tail1", "tail2"), ("tail2", "tail3")]
    for side in ("L", "R"):
        for fb in ("f", "b"):
            root = "shoulders" if fb == "f" else "hips"
            edges += [(root, "%s_up.%s" % (fb, side)), ("%s_up.%s" % (fb, side), "%s_knee.%s" % (fb, side)), ("%s_knee.%s" % (fb, side), "%s_paw.%s" % (fb, side))]
    body_ob = skin("body", [P[n] for n in names], [(idx[a], idx[b]) for a, b in edges], [rad[n] for n in names], root=idx["back"], subdiv=2, m=m_body)
    bones_ = [("root", P["hips"], P["back"], None), ("spine", P["back"], P["shoulders"], "root"),
              ("neck", P["shoulders"], P["neck"], "spine"), ("head", P["neck"], P["snout"], "neck"),
              ("tail1", P["hips"], P["tail2"], "root"), ("tail2", P["tail2"], P["tail3"], "tail1")]
    for side in ("L", "R"):
        for fb in ("f", "b"):
            par = "spine" if fb == "f" else "root"
            bones_ += [("%s_leg.%s" % (fb, side), P["%s_up.%s" % (fb, side)], P["%s_knee.%s" % (fb, side)], par),
                       ("%s_shin.%s" % (fb, side), P["%s_knee.%s" % (fb, side)], P["%s_paw.%s" % (fb, side)], "%s_leg.%s" % (fb, side))]
    rig = Rig(name, bones_)
    parts = []
    hd = Vector(P["head"])
    parts.append((prim("sphere", m_belly, loc=Vector(P["back"]) + Vector((0, 0, -0.22 * s)), scale=(0.33 * s, 0.75 * s, 0.25 * s), name="belly"), "root"))
    for sx in (1, -1):
        horn = curve_tube("horn", m_horn, [(sx * 0.12 * s, 0, 0.15 * s), (sx * 0.3 * s, 0.1 * s, 0.35 * s), (sx * 0.36 * s, 0.3 * s, 0.55 * s), (sx * 0.3 * s, 0.45 * s, 0.7 * s)], radius=0.07 * s, taper=[1, 0.8, 0.5, 0.1])
        place(horn, loc=hd)
        parts.append((horn, "head"))
        parts.append((prim("sphere", m_glow, loc=hd + Vector((sx * 0.14 * s, -0.2 * s, 0.07 * s)), scale=(0.05 * s, 0.04 * s, 0.035 * s), name="eye"), "head"))
        for k in range(2):
            parts.append((prim("cone", m_horn, loc=Vector(P["snout"]) + Vector((sx * 0.07 * s, -0.08 * s, -0.12 * s)), rot=(180, 0, 0), scale=(0.03 * s, 0.03 * s, 0.1 * s), name="tooth"), "head"))
    for k in range(spikes):
        t = k / max(spikes - 1, 1)
        p = Vector(P["hips"]).lerp(Vector(P["neck"]), t) + Vector((0, 0, 0.36 * s))
        parts.append((prim("cone", m_glow if big else m_horn, loc=p, rot=(-15, 0, 0), scale=(0.09 * s, 0.09 * s, (0.35 - abs(t - 0.5) * 0.3) * s), name="spike", seg=6), "spine" if t > 0.5 else "root"))
    rig.bind(body_ob)
    objs = [body_ob]
    for ob, bn in parts:
        Rig.rigid_part(ob, bn)
        objs.append(ob)
    join(objs, name)
    a = 30
    def run(sign):
        return {"f_leg.L": (-a * sign, 0, 0), "f_leg.R": (a * sign, 0, 0), "b_leg.L": (a * sign, 0, 0), "b_leg.R": (-a * sign, 0, 0),
                "f_shin.L": (20, 0, 0), "f_shin.R": (20, 0, 0), "spine": (4 * sign, 0, 0), "tail1": (0, 0, 12 * sign)}
    rig.anim("idle", 60, {1: {"neck": (0, 0, 0), "tail1": (0, 0, -8), "spine": (0, 0, 0)}, 31: {"neck": (-6, 0, 0), "tail1": (0, 0, 8), "spine": (-2, 0, 0)}, 61: {"neck": (0, 0, 0), "tail1": (0, 0, -8), "spine": (0, 0, 0)}})
    rig.anim("run", 18, {1: run(1), 10: run(-1), 19: run(1)})
    rig.anim("attack", 18, {1: {"neck": (0, 0, 0), "head": (0, 0, 0), "spine": (0, 0, 0)}, 7: {"neck": (25, 0, 0), "head": (-25, 0, 0), "spine": (-6, 0, 0)},
                            11: {"neck": (-30, 0, 0), "head": (20, 0, 0), "spine": (8, 0, 0)}, 19: {"neck": (0, 0, 0), "head": (0, 0, 0), "spine": (0, 0, 0)}}, loop=False)
    rig.anim("cast", 20, {1: {"neck": (0, 0, 0)}, 8: {"neck": (35, 0, 0)}, 21: {"neck": (0, 0, 0)}}, loop=False)
    rig.anim("death", 30, {1: {"root": (0, 0, 0), "root@loc": (0, 0, 0)}, 30: {"root": (0, 80, 0), "root@loc": (0.4 * s, 0, -0.5 * s)}}, loop=False)
    export_glb(os.path.join(OUT, name.lower() + ".glb"))


def monster():
    quadruped("Monster", 0.95, ("Fur", (0.35, 0.25, 0.42), 0, 0.8), ("Belly", (0.62, 0.5, 0.55), 0, 0.8),
              ("Horn", (0.9, 0.85, 0.72), 0, 0.4), ("MGlow", (1.0, 0.55, 0.15), 3.0), spikes=3)


def boss():
    quadruped("Boss", 2.1, ("Scale", (0.1, 0.32, 0.36), 0.2, 0.4), ("BellyB", (0.55, 0.75, 0.65), 0, 0.5),
              ("HornB", (0.88, 0.85, 0.75), 0, 0.35), ("BGlow", (0.3, 1.0, 0.9), 3.0), spikes=7, big=True)


# ---------------------------------------------------------------- estruturas

def tower():
    reset()
    team, tglow = team_mats()
    stone = mat("Stone", (0.42, 0.4, 0.44), rough=0.85)
    dark = mat("StoneDark", (0.24, 0.23, 0.27), rough=0.9)
    gold = mat("Gold", (0.9, 0.7, 0.3), metallic=0.45, rough=0.3)
    p = [prim("cyl", dark, loc=(0, 0, 0.5), scale=(1.9, 1.9, 1.0), bevel=0.06, name="base", seg=8)]
    p.append(prim("cyl", stone, loc=(0, 0, 1.3), scale=(1.55, 1.55, 0.7), bevel=0.05, name="b2", seg=8))
    p.append(prim("cone", stone, loc=(0, 0, 3.6), scale=(1.15, 1.15, 4.0), r1=1.0, r2=0.72, name="shaft", seg=8))
    p.append(prim("cyl", team, loc=(0, 0, 2.4), scale=(1.12, 1.12, 0.22), name="band", seg=8))
    p.append(prim("cyl", gold, loc=(0, 0, 5.75), scale=(1.15, 1.15, 0.35), bevel=0.04, name="cap", seg=8))
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        p.append(prim("cube", stone, loc=(math.cos(a) * 1.05, math.sin(a) * 1.05, 6.15), rot=(0, 0, math.degrees(a)), scale=(0.28, 0.4, 0.5), bevel=0.04, name="merlon"))
        p.append(prim("cube", dark, loc=(math.cos(a) * 1.95, math.sin(a) * 1.95, 0.6), rot=(0, 0, math.degrees(a)), scale=(0.35, 0.5, 1.1), bevel=0.05, name="buttress"))
    for a in (0, math.pi):
        p.append(prim("cube", team, loc=(math.cos(a + 1.57) * 0.95, math.sin(a + 1.57) * 0.95, 3.5), rot=(0, 0, math.degrees(a)), scale=(0.7, 0.05, 1.5), name="banner"))
    p.append(prim("ico", tglow, loc=(0, 0, 7.4), scale=(0.55, 0.55, 0.95), name="crystal", sub=1))
    for i in range(4):
        a = i * math.pi / 2
        p.append(prim("cone", gold, loc=(math.cos(a) * 0.55, math.sin(a) * 0.55, 6.6), rot=(math.degrees(math.sin(a)) * -0.4, math.degrees(math.cos(a)) * 0.4, 0), scale=(0.08, 0.08, 0.9), name="prong"))
    join(p, "Tower")
    export_glb(os.path.join(OUT, "tower.glb"))


def nexus():
    reset()
    team, tglow = team_mats()
    stone = mat("Stone", (0.42, 0.4, 0.44), rough=0.85)
    gold = mat("Gold", (0.9, 0.7, 0.3), metallic=0.45, rough=0.3)
    p = [prim("cyl", stone, loc=(0, 0, 0.4), scale=(3.6, 3.6, 0.8), bevel=0.08, name="plat", seg=12)]
    p.append(prim("cyl", team, loc=(0, 0, 0.85), scale=(3.0, 3.0, 0.15), name="ring", seg=12))
    p.append(prim("cyl", gold, loc=(0, 0, 1.1), scale=(2.4, 2.4, 0.4), bevel=0.05, name="ped", seg=12))
    for i in range(6):
        a = i * math.pi / 3
        arch = curve_tube("arch", stone, [(math.cos(a) * 3.0, math.sin(a) * 3.0, 0.8), (math.cos(a) * 2.9, math.sin(a) * 2.9, 3.5), (math.cos(a) * 2.2, math.sin(a) * 2.2, 5.5), (math.cos(a) * 1.4, math.sin(a) * 1.4, 6.6)], radius=0.28, taper=[1.2, 1.0, 0.8, 0.4])
        p.append(arch)
        p.append(prim("ico", tglow, loc=(math.cos(a) * 2.95, math.sin(a) * 2.95, 3.3), scale=(0.18, 0.18, 0.35), name="gem", sub=1))
    p.append(prim("ico", tglow, loc=(0, 0, 4.0), scale=(1.4, 1.4, 2.2), name="core", sub=1))
    p.append(prim("torus", gold, loc=(0, 0, 4.0), rot=(0, 0, 0), scale=(1.9, 1.9, 1.9), name="halo", minor=0.06, seg=40))
    join(p, "Nexus")
    export_glb(os.path.join(OUT, "nexus.glb"))


# ---------------------------------------------------------------- vegetação

def trees():
    import random
    for v in range(3):
        reset()
        random.seed(10 + v)
        bark = mat("Bark", (0.36, 0.24, 0.16), rough=0.9)
        leaf = mat("Leaf%d" % v, [(0.16, 0.42, 0.24), (0.12, 0.36, 0.3), (0.24, 0.46, 0.2)][v], rough=0.8)
        leaf2 = mat("Leaf2_%d" % v, [(0.2, 0.52, 0.28), (0.16, 0.45, 0.36), (0.32, 0.56, 0.24)][v], rough=0.8)
        trunk = skin("trunk", [(0, 0, 0), (0.05, 0.02, 1.0), (-0.05, 0.05, 2.0), (0.25, 0, 2.6), (-0.3, 0.05, 2.5)],
                     [(0, 1), (1, 2), (2, 3), (2, 4)], [(0.35, 0.35), 0.22, 0.17, 0.08, 0.08], subdiv=1, m=bark)
        parts = [trunk]
        for k in range(6):
            a = random.uniform(0, 6.28)
            r = random.uniform(0.2, 0.9)
            sz = random.uniform(0.75, 1.2)
            c = prim("ico", leaf if k % 2 else leaf2, loc=(math.cos(a) * r, math.sin(a) * r, 2.7 + random.uniform(-0.3, 0.7)), scale=(sz, sz, sz * 0.85), name="leaf", sub=2)
            displace(c, 0.25, 0.5, seed=v * 10 + k)
            parts.append(c)
        join(parts, "Tree%d" % v)
        export_glb(os.path.join(OUT, "tree_%d.glb" % v))
    for v in range(2):
        reset()
        rock = mat("Rock", (0.36, 0.35, 0.4), rough=0.9)
        moss = mat("Moss", (0.25, 0.42, 0.22), rough=0.9)
        r = prim("ico", rock, loc=(0, 0, 0.35), scale=(1.0, 0.85, 0.75), name="rock", sub=3)
        displace(r, 0.35, 0.8, seed=50 + v)
        r2 = prim("ico", rock, loc=(0.6, 0.3, 0.2), scale=(0.5, 0.45, 0.4), name="rock2", sub=2)
        displace(r2, 0.2, 0.6, seed=60 + v)
        m = prim("ico", moss, loc=(0, 0, 0.75), scale=(0.6, 0.5, 0.18), name="moss", sub=2)
        join([r, r2, m], "Rock%d" % v)
        export_glb(os.path.join(OUT, "rock_%d.glb" % v))


# ---------------------------------------------------------------- efeitos

def vfx():
    reset()
    white = mat("FX", (1, 1, 1), emit=(1, 1, 1), strength=1.0)
    # corte em meia-lua (deitado no chão, abre para -Y)
    bm = bmesh.new()
    n = 24
    outer, inner = [], []
    for i in range(n + 1):
        t = i / n
        a = math.pi * (0.15 + 0.7 * t)
        w = math.sin(t * math.pi)
        outer.append(bm.verts.new((math.cos(a) * 1.0, -math.sin(a) * 1.0, 0)))
        inner.append(bm.verts.new((math.cos(a) * (1.0 - 0.35 * w), -math.sin(a) * (1.0 - 0.35 * w), 0)))
    uv_layer = bm.loops.layers.uv.new()
    for i in range(n):
        f = bm.faces.new((inner[i], outer[i], outer[i + 1], inner[i + 1]))
        for loop, uv in zip(f.loops, [(i / n, 0), (i / n, 1), ((i + 1) / n, 1), ((i + 1) / n, 0)]):
            loop[uv_layer].uv = uv
    me = bpy.data.meshes.new("Slash")
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new("Slash", me))
    set_mat(ob, white)
    export_glb(os.path.join(OUT, "vfx_slash.glb"))


BUILDERS = {"melee": minion_melee, "ranged": minion_ranged, "siege": minion_siege, "monster": monster, "boss": boss,
            "tower": tower, "nexus": nexus, "trees": trees, "vfx": vfx}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(BUILDERS)
    for n in names:
        BUILDERS[n]()
        print("ok", n)
