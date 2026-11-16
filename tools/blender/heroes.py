"""Os 5 heróis do Arena Rift, modelados e animados por código no Blender."""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from humanoid import *

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")


def skin_mat(tone=(0.86, 0.66, 0.52)):
    return mat("Skin", tone, rough=0.6)


def kaelor():
    reset()
    S = 1.12
    J = skeleton(S, bulk=1.15)
    rig = Rig("kaelor", bones(J))
    m_skin = skin_mat((0.8, 0.6, 0.48))
    armor = mat("ArmorRed", (0.62, 0.08, 0.06), metallic=0.25, rough=0.35)
    dark = mat("Dark", (0.13, 0.11, 0.12), metallic=0.2, rough=0.5)
    gold = mat("Gold", (0.95, 0.7, 0.25), metallic=0.45, rough=0.3)
    steel = mat("Steel", (0.78, 0.8, 0.86), metallic=0.35, rough=0.25)
    glow = mat("Glow", (1.0, 0.3, 0.12), emit=(1.0, 0.3, 0.1), strength=2.5)
    cloth = mat("Cloth", (0.3, 0.02, 0.03), rough=0.8)
    b = body(J, dark, S, bulk=1.08, chest=1.15)
    hair = mat("Hair", (0.12, 0.08, 0.06), rough=0.7)
    parts = [(head(J, m_skin, S, size=1.15, brow=hair), "head"), (hand(J, "L", dark, S, 1.4), "hand.L"), (hand(J, "R", dark, S, 1.4), "hand.R")]
    ch = Vector(J["chest"])
    # Peitoral
    parts.append((prim("sphere", armor, loc=ch + Vector((0, -0.02, 0.02)), scale=(0.27 * S, 0.19 * S, 0.24 * S), name="breast"), "chest"))
    parts.append((prim("cube", gold, loc=ch + Vector((0, -0.2 * S, 0.0)), scale=(0.07, 0.03, 0.18), bevel=0.01, name="emblem"), "chest"))
    # Ombreiras com espinhos
    for side, sx in (("L", 1), ("R", -1)):
        sh = Vector(J["shoulder." + side])
        parts.append((prim("sphere", armor, loc=sh + Vector((sx * 0.05, 0, 0.06)), scale=(0.17 * S, 0.17 * S, 0.12 * S), name="pauldron" + side), "upper_arm." + side))
        parts.append((prim("cone", gold, loc=sh + Vector((sx * 0.12, 0, 0.18)), rot=(0, -sx * 35, 0), scale=(0.05, 0.05, 0.22), name="spike" + side), "upper_arm." + side))
        parts.append((prim("cyl", armor, loc=(Vector(J["elbow." + side]) + Vector(J["wrist." + side])) / 2, scale=(0.065 * S, 0.065 * S, 0.22 * S), name="bracer" + side, seg=12), "forearm." + side))
        parts.append((prim("cyl", armor, loc=(Vector(J["knee." + side]) + Vector(J["ankle." + side])) / 2, scale=(0.075 * S, 0.08 * S, 0.3 * S), name="greave" + side, seg=12), "shin." + side))
        parts.append((prim("sphere", gold, loc=Vector(J["knee." + side]) + Vector((0, -0.06, 0)), scale=(0.07, 0.06, 0.07), name="knee" + side), "shin." + side))
    # Elmo com crista
    hd = Vector(J["head"])
    parts.append((prim("sphere", armor, loc=hd + Vector((0, 0.025, 0.21 * S)), scale=(0.19 * S, 0.2 * S, 0.16 * S), name="helm"), "head"))
    for sx in (1, -1):
        parts.append((prim("sphere", armor, loc=hd + Vector((sx * 0.16 * S, 0.0, 0.1 * S)), scale=(0.06 * S, 0.12 * S, 0.12 * S), name="cheek"), "head"))
    parts.append((prim("cube", gold, loc=hd + Vector((0, -0.17 * S, 0.24 * S)), scale=(0.3, 0.04, 0.05), bevel=0.012, name="visor"), "head"))
    crest = curve_tube("crest", glow, [(0, -0.12, 0.3), (0, 0.0, 0.42), (0, 0.18, 0.4), (0, 0.32, 0.22)], radius=0.035, taper=[0.6, 1.0, 0.8, 0.2])
    crest.location = hd + Vector((0, 0, 0.0))
    activate(crest); bpy.ops.object.transform_apply(location=True)
    parts.append((crest, "head"))
    # Saiote e capa
    pel = Vector(J["pelvis"])
    parts.append((prim("cone", cloth, loc=pel + Vector((0, 0, -0.12)), scale=(0.25 * S, 0.2 * S, 0.4 * S), r1=1.0, r2=0.75, name="skirt", seg=16), "root"))
    parts.append((prim("cyl", gold, loc=pel + Vector((0, 0, 0.06)), scale=(0.2 * S, 0.16 * S, 0.06), name="belt", seg=16), "root"))
    cape = plane_shape("cape", cloth, [(-0.28, 0), (0.28, 0), (0.38, -1.0), (0.1, -1.1), (-0.1, -1.05), (-0.38, -1.0)], thickness=0.03,
                       loc=Vector(J["neck_base"]) + Vector((0, 0.2 * S, 0.0)), rot=(-8, 0, 0))
    parts.append((cape, "chest"))
    # Montante (espada grande) na mão direita, lâmina para frente/cima
    grip = prim("cyl", dark, loc=(0, 0, 0), scale=(0.032, 0.032, 0.34), name="grip", seg=10)
    guard = prim("cube", gold, loc=(0, 0, 0.18), scale=(0.38, 0.08, 0.07), bevel=0.02, name="guard")
    bl = blade("blade", steel, length=1.45 * S, width=0.12, thick=0.035, loc=(0, 0, 0.21))
    edge = blade("edge", glow, length=1.25 * S, width=0.035, thick=0.042, loc=(0, 0, 0.26))
    pommel = prim("sphere", glow, loc=(0, 0, -0.2), scale=(0.055, 0.055, 0.055), name="pommel")
    sword = join([grip, guard, bl, edge, pommel], "sword")
    place(sword, loc=Vector(J["hand.R"]), rot=(60, 0, 0))
    parts.append((sword, "hand.R"))
    mesh = build("Kaelor", J, b, parts, rig)
    standard_anims(rig, "sword")
    export_glb(os.path.join(OUT, "hero_kaelor.glb"))


def brontus():
    reset()
    S = 1.22
    J = skeleton(S, bulk=1.45, legs=0.92)
    rig = Rig("brontus", bones(J))
    m_skin = skin_mat((0.5, 0.58, 0.46))
    armor = mat("ArmorGreen", (0.16, 0.36, 0.2), metallic=0.25, rough=0.4)
    stone = mat("Stone", (0.45, 0.43, 0.4), rough=0.85)
    bronze = mat("Bronze", (0.72, 0.46, 0.2), metallic=0.4, rough=0.35)
    leather = mat("Leather", (0.25, 0.15, 0.09), rough=0.8)
    glow = mat("Glow", (0.35, 1.0, 0.45), emit=(0.3, 1.0, 0.4), strength=2.5)
    beard_m = mat("Beard", (0.3, 0.2, 0.12), rough=0.9)
    b = body(J, leather, S, bulk=1.45, chest=1.3, belly=1.25, limbs=1.2)
    parts = [(head(J, m_skin, S, size=1.05, brow=beard_m), "head"), (hand(J, "L", leather, S, 1.7), "hand.L"), (hand(J, "R", leather, S, 1.7), "hand.R")]
    ch = Vector(J["chest"])
    hd = Vector(J["head"])
    parts.append((prim("sphere", armor, loc=ch + Vector((0, -0.03, 0.03)), scale=(0.38 * S, 0.26 * S, 0.3 * S), name="breast"), "chest"))
    parts.append((prim("ico", glow, loc=ch + Vector((0, -0.31 * S, 0.05)), scale=(0.09, 0.05, 0.11), name="gem", sub=1), "chest"))
    # barba
    parts.append((prim("cone", beard_m, loc=hd + Vector((0, -0.13 * S, 0.0)), rot=(10, 0, 0), scale=(0.12 * S, 0.08 * S, 0.22 * S), r1=1, r2=0.2, name="beard"), "head"))
    # elmo com chifres
    parts.append((prim("sphere", bronze, loc=hd + Vector((0, 0.03, 0.22 * S)), scale=(0.19 * S, 0.2 * S, 0.14 * S), name="helm"), "head"))
    for sx in (1, -1):
        horn = curve_tube("horn", stone, [(sx * 0.14, 0, 0.25), (sx * 0.32, 0, 0.3), (sx * 0.42, -0.05, 0.48), (sx * 0.38, -0.12, 0.62)], radius=0.06, taper=[1, 0.8, 0.5, 0.1])
        place(horn, loc=hd * 1.0)
        parts.append((horn, "head"))
    for side, sx in (("L", 1), ("R", -1)):
        sh = Vector(J["shoulder." + side])
        for k in range(3):
            parts.append((prim("sphere", stone if k == 0 else armor, loc=sh + Vector((sx * (0.08 + k * 0.03), 0, 0.12 - k * 0.09)), scale=(0.24 * S - k * 0.04, 0.22 * S - k * 0.03, 0.13 * S), name="pad", seg=16, rings=10), "upper_arm." + side))
        parts.append((prim("cyl", bronze, loc=(Vector(J["elbow." + side]) + Vector(J["wrist." + side])) / 2, scale=(0.1 * S, 0.1 * S, 0.26 * S), name="bracer", seg=12), "forearm." + side))
        parts.append((prim("cyl", armor, loc=(Vector(J["knee." + side]) + Vector(J["ankle." + side])) / 2, scale=(0.11 * S, 0.12 * S, 0.3 * S), name="greave", seg=12), "shin." + side))
        parts.append((prim("cube", stone, loc=Vector(J["toe." + side]) + Vector((0, 0.06, 0.05)), scale=(0.17, 0.3, 0.12), bevel=0.04, name="boot"), "foot." + side))
    pel = Vector(J["pelvis"])
    parts.append((prim("cyl", bronze, loc=pel + Vector((0, 0, 0.1)), scale=(0.3 * S, 0.24 * S, 0.1), name="belt", seg=16), "root"))
    parts.append((prim("cone", leather, loc=pel + Vector((0, 0, -0.1)), scale=(0.33 * S, 0.27 * S, 0.34 * S), r1=1, r2=0.85, name="kilt"), "root"))
    # escudo-torre no braço esquerdo
    sh_c = (Vector(J["elbow.L"]) + Vector(J["wrist.L"])) / 2 + Vector((0.16, -0.12, 0))
    shield = prim("cube", stone, loc=(0, 0, 0), scale=(0.08, 0.75, 1.0), bevel=0.06, name="shield")
    rim = prim("cube", bronze, loc=(0, 0, 0), scale=(0.1, 0.8, 1.05), bevel=0.05, name="rim")
    emb = prim("ico", glow, loc=(0.06, 0, 0.05), scale=(0.05, 0.18, 0.2), name="emb", sub=1)
    shield_g = join([rim, shield, emb], "shieldg")
    place(shield_g, loc=sh_c, rot=(0, 0, 10))
    parts.append((shield_g, "forearm.L"))
    # maça na mão direita
    handle = prim("cyl", leather, loc=(0, 0, 0.3), scale=(0.04, 0.04, 0.8), name="handle", seg=10)
    mhead = prim("ico", stone, loc=(0, 0, 0.75), scale=(0.2, 0.2, 0.22), name="mhead", sub=2)
    spikes = [prim("cone", bronze, loc=(math.cos(i * 1.257) * 0.2, math.sin(i * 1.257) * 0.2, 0.75), rot=(90, 0, math.degrees(i * 1.257) + 90), scale=(0.05, 0.05, 0.18), name="sp") for i in range(5)]
    mace = join([handle, mhead] + spikes, "mace")
    place(mace, loc=Vector(J["hand.R"]), rot=(55, 0, 0))
    parts.append((mace, "hand.R"))
    build("Brontus", J, b, parts, rig)
    standard_anims(rig, "heavy", heavy=True)
    export_glb(os.path.join(OUT, "hero_brontus.glb"))


def nyxara():
    reset()
    S = 1.05
    J = skeleton(S, bulk=0.85)
    rig = Rig("nyxara", bones(J))
    m_skin = skin_mat((0.86, 0.76, 0.84))
    robe = mat("Robe", (0.2, 0.07, 0.35), rough=0.6)
    robe2 = mat("RobeDark", (0.06, 0.03, 0.1), rough=0.6)
    silver = mat("Silver", (0.8, 0.8, 0.92), metallic=0.4, rough=0.25)
    glow = mat("Glow", (0.75, 0.35, 1.0), emit=(0.7, 0.3, 1.0), strength=3.0)
    hair_m = mat("Hair", (0.85, 0.85, 0.95), rough=0.5)
    eye = mat("EyeGlow", (0.8, 0.5, 1.0), emit=(0.8, 0.4, 1.0), strength=3.0)
    b = body(J, robe2, S, bulk=0.85, chest=0.95, limbs=0.85)
    parts = [(head(J, m_skin, S, size=1.1, eyes=eye), "head"), (hand(J, "L", m_skin, S, 1.2), "hand.L"), (hand(J, "R", m_skin, S, 1.2), "hand.R")]
    hd = Vector(J["head"])
    ch = Vector(J["chest"])
    pel = Vector(J["pelvis"])
    # capuz
    parts.append((prim("sphere", robe, loc=hd + Vector((0, 0.05, 0.2 * S)), scale=(0.235 * S, 0.24 * S, 0.24 * S), name="hood"), "head"))
    parts.append((prim("cone", robe, loc=hd + Vector((0, 0.24, 0.12 * S)), rot=(-65, 0, 0), scale=(0.11, 0.11, 0.35), name="hoodtip"), "head"))
    # cabelo longo prateado saindo do capuz
    for sx in (1, -1):
        hair = curve_tube("hair", hair_m, [(sx * 0.12, -0.05, 0.12), (sx * 0.16, -0.02, -0.05), (sx * 0.17, 0.02, -0.25), (sx * 0.15, 0.05, -0.42)], radius=0.045, taper=[1, 1, 0.8, 0.2])
        place(hair, loc=hd)
        parts.append((hair, "head"))
    # túnica longa
    parts.append((prim("cone", robe, loc=pel + Vector((0, 0, -0.42)), scale=(0.42 * S, 0.36 * S, 0.95 * S), r1=1.0, r2=0.42, name="gown", seg=24), "root"))
    parts.append((prim("cone", glow, loc=pel + Vector((0, 0, -0.88)), scale=(0.425 * S, 0.365 * S, 0.04), r1=1.0, r2=0.97, name="hem", seg=24), "root"))
    parts.append((prim("sphere", robe, loc=ch, scale=(0.2 * S, 0.15 * S, 0.22 * S), name="torso"), "chest"))
    parts.append((prim("torus", silver, loc=ch + Vector((0, 0, 0.18)), scale=(0.17, 0.14, 0.4), name="collar", minor=0.12), "chest"))
    for side, sx in (("L", 1), ("R", -1)):
        sh = Vector(J["shoulder." + side])
        parts.append((prim("cone", robe, loc=(Vector(J["elbow." + side]) + Vector(J["wrist." + side])) / 2 + Vector((0, 0, -0.05)), scale=(0.11, 0.11, 0.3), r1=1, r2=0.45, name="sleeve"), "forearm." + side))
        parts.append((prim("sphere", silver, loc=sh + Vector((sx * 0.04, 0, 0.05)), scale=(0.11, 0.11, 0.07), name="sh"), "upper_arm." + side))
        # cristais flutuando nas costas
        for k in range(2):
            parts.append((prim("ico", glow, loc=ch + Vector((sx * (0.3 + k * 0.18), 0.28, 0.25 + k * 0.25)), scale=(0.05, 0.05, 0.12), name="crys", sub=1), "chest"))
    # cajado com orbe do vazio
    staff = prim("cyl", robe2, loc=(0, 0, 0.35), scale=(0.03, 0.03, 1.9), name="staff", seg=10)
    ring1 = prim("torus", silver, loc=(0, 0, 1.38), rot=(90, 0, 0), scale=(0.17, 0.17, 0.17), name="ring", minor=0.1)
    orb = prim("sphere", mat("Void", (0.02, 0.0, 0.05), rough=0.1), loc=(0, 0, 1.38), scale=(0.11, 0.11, 0.11), name="orb")
    halo = prim("torus", glow, loc=(0, 0, 1.38), rot=(20, 60, 0), scale=(0.15, 0.15, 0.15), name="halo", minor=0.06)
    st = join([staff, ring1, orb, halo], "staffg")
    place(st, loc=Vector(J["hand.R"]), rot=(12, 0, 0))
    parts.append((st, "hand.R"))
    build("Nyxara", J, b, parts, rig)
    standard_anims(rig, "staff")
    export_glb(os.path.join(OUT, "hero_nyxara.glb"))


def vesper():
    reset()
    S = 1.05
    J = skeleton(S, bulk=0.88, legs=1.04)
    rig = Rig("vesper", bones(J))
    m_skin = skin_mat((0.72, 0.52, 0.4))
    leather = mat("Leather", (0.45, 0.24, 0.1), rough=0.7)
    dark = mat("DarkLeather", (0.15, 0.08, 0.05), rough=0.75)
    cloth = mat("Cloth", (0.85, 0.5, 0.12), rough=0.75)
    gold = mat("Gold", (0.95, 0.72, 0.3), metallic=0.45, rough=0.3)
    glow = mat("Glow", (1.0, 0.75, 0.3), emit=(1.0, 0.7, 0.25), strength=2.5)
    hair_m = mat("Hair", (0.25, 0.08, 0.05), rough=0.6)
    b = body(J, dark, S, bulk=0.88, chest=0.95, limbs=0.9)
    parts = [(head(J, m_skin, S, size=1.12, brow=hair_m), "head"), (hand(J, "L", dark, S, 1.25), "hand.L"), (hand(J, "R", dark, S, 1.25), "hand.R")]
    hd = Vector(J["head"])
    ch = Vector(J["chest"])
    pel = Vector(J["pelvis"])
    parts.append((prim("sphere", leather, loc=ch + Vector((0, -0.01, 0.02)), scale=(0.22 * S, 0.16 * S, 0.22 * S), name="vest"), "chest"))
    strap = curve_tube("strap", gold, [(0.18, -0.16, 0.25), (0, -0.19, 0.0), (-0.2, -0.15, -0.22)], radius=0.022)
    place(strap, loc=ch)
    parts.append((strap, "chest"))
    # capuz baixo e rabo de cavalo
    parts.append((prim("sphere", hair_m, loc=hd + Vector((0, 0.035, 0.24 * S)), scale=(0.2 * S, 0.21 * S, 0.15 * S), name="hairtop"), "head"))
    pony = curve_tube("pony", hair_m, [(0, 0.15, 0.25), (0, 0.3, 0.22), (0, 0.38, 0.05), (0, 0.36, -0.18)], radius=0.06, taper=[1, 0.9, 0.6, 0.15])
    place(pony, loc=hd)
    parts.append((pony, "head"))
    parts.append((prim("torus", gold, loc=hd + Vector((0, 0.0, 0.2 * S)), rot=(8, 0, 0), scale=(0.2, 0.21, 0.3), name="band", minor=0.07), "head"))
    # capa curta
    cape = plane_shape("cape", cloth, [(-0.24, 0), (0.24, 0), (0.3, -0.7), (0.0, -0.8), (-0.3, -0.7)], thickness=0.025,
                       loc=Vector(J["neck_base"]) + Vector((0, 0.17, 0.02)), rot=(-12, 0, 0))
    parts.append((cape, "chest"))
    for side, sx in (("L", 1), ("R", -1)):
        parts.append((prim("cyl", leather, loc=(Vector(J["elbow." + side]) + Vector(J["wrist." + side])) / 2, scale=(0.06, 0.06, 0.2), name="bracer", seg=12), "forearm." + side))
        parts.append((prim("cyl", leather, loc=(Vector(J["knee." + side]) + Vector(J["ankle." + side])) / 2 + Vector((0, 0, -0.04)), scale=(0.07, 0.075, 0.24), name="boot", seg=12), "shin." + side))
        parts.append((prim("sphere", gold, loc=Vector(J["shoulder." + side]) + Vector((sx * 0.04, 0, 0.05)), scale=(0.1, 0.1, 0.06), name="sh"), "upper_arm." + side))
    parts.append((prim("cone", cloth, loc=pel + Vector((0, 0, -0.1)), scale=(0.2 * S, 0.17 * S, 0.3 * S), r1=1, r2=0.8, name="skirt"), "root"))
    # aljava nas costas
    quiver = prim("cyl", dark, loc=(0, 0, 0), scale=(0.08, 0.08, 0.55), name="quiver", seg=12)
    arrows = [prim("cone", glow, loc=(math.cos(i * 2.1) * 0.04, math.sin(i * 2.1) * 0.04, 0.33), scale=(0.025, 0.025, 0.12), name="ar") for i in range(3)]
    q = join([quiver] + arrows, "quiverg")
    place(q, loc=ch + Vector((0.08, 0.2, 0.0)), rot=(0, -25, 0))
    parts.append((q, "chest"))
    # arco longo na mão esquerda
    bowpts = [(0, 0, -0.72), (0, -0.16, -0.4), (0, -0.2, 0.0), (0, -0.16, 0.4), (0, 0, 0.72)]
    bow = curve_tube("bow", leather, bowpts, radius=0.03, taper=[0.5, 1, 1.3, 1, 0.5])
    tips = [prim("cone", gold, loc=(0, 0.0, sz * 0.78), rot=(0 if sz > 0 else 180, 0, 0), scale=(0.035, 0.035, 0.14), name="tip") for sz in (1, -1)]
    string = curve_tube("string", glow, [(0, 0, -0.72), (0, 0, 0.72)], radius=0.006)
    bowg = join([bow, string] + tips, "bowg")
    place(bowg, loc=Vector(J["hand.L"]) + Vector((0.0, 0.0, 0.05)), rot=(0, 0, 90))
    parts.append((bowg, "hand.L"))
    build("Vesper", J, b, parts, rig)
    standard_anims(rig, "bow")
    export_glb(os.path.join(OUT, "hero_vesper.glb"))


def aurelia():
    reset()
    S = 1.05
    J = skeleton(S, bulk=0.86)
    rig = Rig("aurelia", bones(J))
    m_skin = skin_mat((0.93, 0.78, 0.66))
    white = mat("White", (0.93, 0.91, 0.86), rough=0.5)
    gold = mat("Gold", (1.0, 0.76, 0.3), metallic=0.45, rough=0.25)
    glow = mat("Glow", (1.0, 0.85, 0.4), emit=(1.0, 0.75, 0.3), strength=1.8)
    feather = mat("Feather", (0.97, 0.93, 0.82), rough=0.6)
    hair_m = mat("Hair", (0.98, 0.78, 0.35), rough=0.45)
    b = body(J, white, S, bulk=0.86, chest=0.95, limbs=0.85)
    parts = [(head(J, m_skin, S, size=1.12), "head"), (hand(J, "L", m_skin, S, 1.2), "hand.L"), (hand(J, "R", m_skin, S, 1.2), "hand.R")]
    hd = Vector(J["head"])
    ch = Vector(J["chest"])
    pel = Vector(J["pelvis"])
    parts.append((prim("sphere", hair_m, loc=hd + Vector((0, 0.035, 0.24 * S)), scale=(0.2 * S, 0.21 * S, 0.15 * S), name="hairtop"), "head"))
    for k, sx in enumerate((1, -1, 0.5, -0.5)):
        hair = curve_tube("hair", hair_m, [(sx * 0.13, 0.04, 0.15), (sx * 0.17, 0.08, -0.05), (sx * 0.16, 0.12, -0.3), (sx * 0.12, 0.14, -0.5)], radius=0.055, taper=[1, 1, 0.7, 0.2])
        place(hair, loc=hd)
        parts.append((hair, "head"))
    halo = prim("torus", glow, loc=hd + Vector((0, 0.06, 0.48 * S)), rot=(15, 0, 0), scale=(0.22, 0.22, 0.22), name="halo", minor=0.09, seg=40)
    parts.append((halo, "head"))
    parts.append((prim("sphere", gold, loc=ch + Vector((0, -0.01, 0.03)), scale=(0.21 * S, 0.15 * S, 0.2 * S), name="corset"), "chest"))
    parts.append((prim("ico", glow, loc=ch + Vector((0, -0.16 * S, 0.06)), scale=(0.06, 0.03, 0.07), name="gem", sub=1), "chest"))
    parts.append((prim("cone", white, loc=pel + Vector((0, 0, -0.38)), scale=(0.4 * S, 0.34 * S, 0.85 * S), r1=1, r2=0.42, name="gown", seg=24), "root"))
    parts.append((prim("cone", gold, loc=pel + Vector((0, 0, -0.8)), scale=(0.405 * S, 0.345 * S, 0.05), r1=1, r2=0.96, name="hem", seg=24), "root"))
    for side, sx in (("L", 1), ("R", -1)):
        parts.append((prim("sphere", gold, loc=Vector(J["shoulder." + side]) + Vector((sx * 0.04, 0, 0.05)), scale=(0.11, 0.11, 0.07), name="sh"), "upper_arm." + side))
        parts.append((prim("cyl", gold, loc=Vector(J["wrist." + side]) + Vector((0, 0, 0.06)), scale=(0.055, 0.055, 0.07), name="cuff", seg=12), "forearm." + side))
        # asas de penas
        for k in range(4):
            ln = 0.95 - k * 0.15
            f = plane_shape("feather", feather, [(0, 0), (0.09, 0.05), (0.12, -ln * 0.5), (0.05, -ln), (-0.03, -ln * 0.6)], thickness=0.015,
                            loc=ch + Vector((sx * (0.16 + k * 0.08), 0.22, 0.28 - k * 0.02)), rot=(-15, sx * (60 - k * 12), sx * (35 + k * 18)), subdiv=1)
            parts.append((f, "chest"))
    staff = prim("cyl", gold, loc=(0, 0, 0.35), scale=(0.028, 0.028, 2.0), name="staff", seg=10)
    sun = prim("sphere", glow, loc=(0, 0, 1.45), scale=(0.1, 0.1, 0.1), name="sun")
    ring = prim("torus", gold, loc=(0, 0, 1.45), rot=(90, 0, 0), scale=(0.2, 0.2, 0.2), name="ring", minor=0.1)
    rays = [prim("cone", glow, loc=(math.cos(i * 0.785) * 0.27, 0, 1.45 + math.sin(i * 0.785) * 0.27), rot=(0, 90 - math.degrees(i * 0.785), 0), scale=(0.03, 0.03, 0.1), name="ray") for i in range(8)]
    st = join([staff, ring, sun] + rays, "staffg")
    place(st, loc=Vector(J["hand.R"]), rot=(10, 0, 0))
    parts.append((st, "hand.R"))
    build("Aurelia", J, b, parts, rig)
    standard_anims(rig, "staff")
    export_glb(os.path.join(OUT, "hero_aurelia.glb"))


BUILDERS = {"kaelor": kaelor, "brontus": brontus, "nyxara": nyxara, "vesper": vesper, "aurelia": aurelia}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(BUILDERS)
    for n in names:
        BUILDERS[n]()
        print("ok", n)
