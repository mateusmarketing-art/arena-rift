"""Corpo humanoide com esqueleto e animações padrão."""
from lib import *

# Lado esquerdo do personagem = +X (ele olha para -Y)


def skeleton(s=1.0, bulk=1.0, legs=1.0):
    """Pontos das juntas. s = escala geral, bulk = largura, legs = altura das pernas."""
    z = lambda v: v * s
    hip_z = 0.98 * legs
    J = {
        "pelvis": (0, 0, z(hip_z + 0.02)),
        "belly": (0, 0.01, z(hip_z + 0.24)),
        "chest": (0, 0, z(hip_z + 0.5)),
        "neck_base": (0, 0, z(hip_z + 0.72)),
        "neck": (0, 0, z(hip_z + 0.86)),
        "head": (0, 0, z(hip_z + 1.0)),
        "head_top": (0, 0, z(hip_z + 1.3)),
    }
    for side, sx in (("L", 1), ("R", -1)):
        w = bulk
        J["shoulder." + side] = (sx * 0.24 * w * s, 0, z(hip_z + 0.66))
        J["elbow." + side] = (sx * 0.34 * w * s, 0.03 * s, z(hip_z + 0.38))
        J["wrist." + side] = (sx * 0.4 * w * s, -0.03 * s, z(hip_z + 0.12))
        J["hand." + side] = (sx * 0.42 * w * s, -0.06 * s, z(hip_z + 0.0))
        J["hip." + side] = (sx * 0.12 * w * s, 0, z(hip_z - 0.02))
        J["knee." + side] = (sx * 0.14 * w * s, -0.04 * s, z(hip_z * 0.56))
        J["ankle." + side] = (sx * 0.14 * w * s, 0.02 * s, z(0.1))
        J["toe." + side] = (sx * 0.15 * w * s, -0.17 * s, z(0.03))
    return J


def bones(J):
    b = [
        ("root", J["pelvis"], J["belly"], None),
        ("spine", J["belly"], J["chest"], "root"),
        ("chest", J["chest"], J["neck_base"], "spine"),
        ("neck", J["neck_base"], J["neck"], "chest"),
        ("head", J["neck"], J["head_top"], "neck"),
    ]
    for side in ("L", "R"):
        b += [
            ("upper_arm." + side, J["shoulder." + side], J["elbow." + side], "chest"),
            ("forearm." + side, J["elbow." + side], J["wrist." + side], "upper_arm." + side),
            ("hand." + side, J["wrist." + side], J["hand." + side], "forearm." + side),
            ("thigh." + side, J["hip." + side], J["knee." + side], "root"),
            ("shin." + side, J["knee." + side], J["ankle." + side], "thigh." + side),
            ("foot." + side, J["ankle." + side], J["toe." + side], "shin." + side),
        ]
    return b


def body(J, m, s=1.0, bulk=1.0, chest=1.0, limbs=1.0, belly=1.0):
    names = ["pelvis", "belly", "chest", "neck_base", "neck",
             "shoulder.L", "elbow.L", "wrist.L", "shoulder.R", "elbow.R", "wrist.R",
             "hip.L", "knee.L", "ankle.L", "toe.L", "hip.R", "knee.R", "ankle.R", "toe.R"]
    idx = {n: i for i, n in enumerate(names)}
    verts = [J[n] for n in names]
    k = s * bulk
    radii = {
        "pelvis": (0.17 * k, 0.12 * k), "belly": (0.15 * k * belly, 0.12 * k * belly), "chest": (0.21 * k * chest, 0.14 * k * chest),
        "neck_base": (0.12 * k, 0.1 * k), "neck": (0.065 * s, 0.065 * s),
    }
    for side in ("L", "R"):
        radii["shoulder." + side] = 0.085 * k * limbs
        radii["elbow." + side] = 0.06 * k * limbs
        radii["wrist." + side] = 0.045 * k * limbs
        radii["hip." + side] = 0.1 * k * limbs
        radii["knee." + side] = 0.075 * k * limbs
        radii["ankle." + side] = 0.055 * k * limbs
        radii["toe." + side] = (0.055 * k, 0.04 * k)
    edges = [("pelvis", "belly"), ("belly", "chest"), ("chest", "neck_base"), ("neck_base", "neck")]
    for side in ("L", "R"):
        edges += [("neck_base", "shoulder." + side), ("shoulder." + side, "elbow." + side), ("elbow." + side, "wrist." + side),
                  ("pelvis", "hip." + side), ("hip." + side, "knee." + side), ("knee." + side, "ankle." + side), ("ankle." + side, "toe." + side)]
    return skin("body", verts, [(idx[a], idx[b]) for a, b in edges], [radii[n] for n in names], root=0, subdiv=2, m=m)


def head(J, m_skin, s=1.0, size=1.0, eyes=None, brow=None):
    """Cabeça estilizada (um pouco grande, estilo herói de MOBA) com olhos."""
    h = Vector(J["head"])
    k = s * size
    c = h + Vector((0, -0.01, 0.13 * k))
    parts = [prim("sphere", m_skin, loc=c, scale=(0.15 * k, 0.155 * k, 0.175 * k), name="head", seg=28, rings=16)]
    # queixo
    parts.append(prim("sphere", m_skin, loc=c + Vector((0, -0.05 * k, -0.09 * k)), scale=(0.1 * k, 0.1 * k, 0.09 * k), name="jaw", seg=16, rings=10))
    # nariz
    parts.append(prim("sphere", m_skin, loc=c + Vector((0, -0.15 * k, -0.01 * k)), scale=(0.025 * k, 0.03 * k, 0.04 * k), name="nose", seg=10, rings=6))
    m_eye = eyes or mat("Eye", (0.1, 0.12, 0.18), rough=0.2)
    for sx in (1, -1):
        parts.append(prim("sphere", m_eye, loc=c + Vector((sx * 0.055 * k, -0.13 * k, 0.025 * k)), scale=(0.03 * k, 0.018 * k, 0.022 * k), name="eye", seg=10, rings=6))
        if brow:
            parts.append(prim("cube", brow, loc=c + Vector((sx * 0.058 * k, -0.138 * k, 0.065 * k)), rot=(0, sx * 12, 0), scale=(0.065 * k, 0.02 * k, 0.016 * k), bevel=0.005, name="brow"))
    return join(parts, "headgroup")


def hand(J, side, m, s=1.0, size=1.0):
    p = (Vector(J["wrist." + side]) + Vector(J["hand." + side])) / 2
    return prim("sphere", m, loc=p, scale=(0.055 * s * size, 0.05 * s * size, 0.075 * s * size), name="hand" + side, seg=12, rings=8)


# ---------------------------------------------------------------- animações

def standard_anims(rig, style="sword", heavy=False):
    """style: sword | heavy | bow | staff | fist"""
    sp = 0.85 if heavy else 1.0
    # Parado (respiração)
    rig.anim("idle", 60, {
        1: {"chest": (0, 0, 0), "upper_arm.L": (0, 0, -6), "upper_arm.R": (0, 0, 6), "root@loc": (0, 0, 0), "forearm.L": (-10, 0, 0), "forearm.R": (-10, 0, 0)},
        31: {"chest": (-3, 0, 0), "upper_arm.L": (3, 0, -9), "upper_arm.R": (3, 0, 9), "root@loc": (0, 0.015, 0), "forearm.L": (-14, 0, 0), "forearm.R": (-14, 0, 0)},
        61: {"chest": (0, 0, 0), "upper_arm.L": (0, 0, -6), "upper_arm.R": (0, 0, 6), "root@loc": (0, 0, 0), "forearm.L": (-10, 0, 0), "forearm.R": (-10, 0, 0)},
    })
    # Correr
    a = 38 * sp
    def run_pose(sign, bob):
        return {
            "thigh.L": (-a * sign, 0, 0), "thigh.R": (a * sign, 0, 0),
            "shin.L": (25 if sign > 0 else 70, 0, 0), "shin.R": (70 if sign > 0 else 25, 0, 0),
            "foot.L": (-10 * sign, 0, 0), "foot.R": (10 * sign, 0, 0),
            "upper_arm.L": (32 * sign, 0, -8), "upper_arm.R": (-32 * sign, 0, 8),
            "forearm.L": (-45, 0, 0), "forearm.R": (-45, 0, 0),
            "spine": (-10, 0, 0), "chest": (0, 7 * sign, 0), "root@loc": (0, bob, 0),
        }
    rig.anim("run", 20, {1: run_pose(1, 0.0), 6: run_pose(0.0001, 0.05), 11: run_pose(-1, 0.0), 16: run_pose(-0.0001, 0.05), 21: run_pose(1, 0.0)})
    # Ataque básico
    if style in ("sword", "heavy", "fist"):
        rig.anim("attack", 18, {
            1: {"upper_arm.R": (0, 0, 6), "forearm.R": (-10, 0, 0), "chest": (0, 0, 0), "spine": (0, 0, 0)},
            7: {"upper_arm.R": (-150, 0, 20), "forearm.R": (-30, 0, 0), "chest": (0, -25, 0), "spine": (5, 0, 0)},
            11: {"upper_arm.R": (-35, 0, -25), "forearm.R": (-5, 0, 0), "chest": (0, 30, 0), "spine": (-15, 0, 0)},
            19: {"upper_arm.R": (0, 0, 6), "forearm.R": (-10, 0, 0), "chest": (0, 0, 0), "spine": (0, 0, 0)},
        }, loop=False)
    elif style == "bow":
        rig.anim("attack", 16, {
            1: {"upper_arm.L": (0, 0, -6), "upper_arm.R": (0, 0, 6), "forearm.R": (-10, 0, 0), "chest": (0, 0, 0)},
            6: {"upper_arm.L": (-90, 0, -10), "upper_arm.R": (-85, 0, 30), "forearm.R": (-110, 0, 0), "chest": (0, -20, 0)},
            10: {"upper_arm.L": (-90, 0, -10), "upper_arm.R": (-70, 0, 50), "forearm.R": (-60, 0, 0), "chest": (0, -15, 0)},
            17: {"upper_arm.L": (0, 0, -6), "upper_arm.R": (0, 0, 6), "forearm.R": (-10, 0, 0), "chest": (0, 0, 0)},
        }, loop=False)
    else:  # staff
        rig.anim("attack", 16, {
            1: {"upper_arm.R": (0, 0, 6), "forearm.R": (-10, 0, 0), "chest": (0, 0, 0)},
            6: {"upper_arm.R": (-60, 0, 15), "forearm.R": (-60, 0, 0), "chest": (0, -15, 0)},
            10: {"upper_arm.R": (-95, 0, 0), "forearm.R": (-5, 0, 0), "chest": (0, 10, 0)},
            17: {"upper_arm.R": (0, 0, 6), "forearm.R": (-10, 0, 0), "chest": (0, 0, 0)},
        }, loop=False)
    # Lançar habilidade
    rig.anim("cast", 20, {
        1: {"upper_arm.L": (0, 0, -6), "upper_arm.R": (0, 0, 6), "chest": (0, 0, 0), "spine": (0, 0, 0), "root@loc": (0, 0, 0)},
        6: {"upper_arm.L": (-150, 0, -25), "upper_arm.R": (-150, 0, 25), "chest": (12, 0, 0), "spine": (8, 0, 0), "root@loc": (0, 0.06, 0)},
        11: {"upper_arm.L": (-80, 0, 10), "upper_arm.R": (-80, 0, -10), "chest": (-15, 0, 0), "spine": (-10, 0, 0), "root@loc": (0, -0.04, 0)},
        21: {"upper_arm.L": (0, 0, -6), "upper_arm.R": (0, 0, 6), "chest": (0, 0, 0), "spine": (0, 0, 0), "root@loc": (0, 0, 0)},
    }, loop=False)
    # Morrer
    rig.anim("death", 30, {
        1: {"root": (0, 0, 0), "root@loc": (0, 0, 0), "spine": (0, 0, 0), "thigh.L": (0, 0, 0), "thigh.R": (0, 0, 0)},
        12: {"root": (35, 0, 0), "root@loc": (0, -0.3, 0.05), "spine": (15, 0, 0), "thigh.L": (-30, 0, 0), "thigh.R": (-20, 0, 0)},
        30: {"root": (85, 0, 0), "root@loc": (0, -0.85, 0.25), "spine": (10, 0, 0), "thigh.L": (-80, 0, 0), "thigh.R": (-70, 0, 0)},
    }, loop=False)


def build(name, J, body_ob, parts, rig):
    """parts: lista de (objeto, osso). Junta tudo numa malha com esqueleto."""
    rig.bind(body_ob)
    objs = [body_ob]
    for ob, bone in parts:
        Rig.rigid_part(ob, bone)
        objs.append(ob)
    mesh = join(objs, name)
    return mesh
