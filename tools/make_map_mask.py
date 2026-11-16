"""Gera a máscara do mapa (assets/textures/map_mask.png).

R = estrada (rotas), G = rio, B = piso das bases, A = 1.
Mesmos números de scripts/data.gd.
"""
import os
import numpy as np
from PIL import Image

HALF = 74.0
EXT = 15.0  # borda extra além do mapa
SIZE = 1024
LANES = [
    [(-62, 62), (-66, 34), (-66, -66), (-34, -66), (62, -62)],
    [(-62, 62), (62, -62)],
    [(-62, 62), (-34, 66), (66, 66), (66, -34), (62, -62)],
]
NEXUS = [(-62, 62), (62, -62)]

span = (HALF + EXT) * 2
xs = (np.arange(SIZE) + 0.5) / SIZE * span - (HALF + EXT)
X, Z = np.meshgrid(xs, xs)  # linhas = z, colunas = x


def seg_dist(ax, az, bx, bz):
    abx, abz = bx - ax, bz - az
    t = np.clip(((X - ax) * abx + (Z - az) * abz) / (abx * abx + abz * abz), 0, 1)
    return np.hypot(X - (ax + abx * t), Z - (az + abz * t))


d = np.full(X.shape, 1e9)
for lane in LANES:
    for (ax, az), (bx, bz) in zip(lane[:-1], lane[1:]):
        d = np.minimum(d, seg_dist(ax, az, bx, bz))
rng = np.random.default_rng(7)
noise = np.zeros_like(X)
for f, a in ((0.08, 1.0), (0.2, 0.5), (0.5, 0.25)):
    ph = rng.uniform(0, 6.28, 4)
    noise += a * (np.sin(X * f + ph[0]) * np.cos(Z * f * 1.3 + ph[1]) + np.sin((X + Z) * f * 0.7 + ph[2]))
road = np.clip((4.6 + noise * 0.6 - d) / 1.6, 0, 1)
river_d = np.abs(X - Z) / np.sqrt(2)
river = np.clip((5.5 + noise * 0.8 - river_d) / 1.5, 0, 1)
river *= np.clip((np.abs(X + Z) / np.sqrt(2) - 4) / 3, 0, 1) * 0.0 + 1  # o rio cruza a rota do meio
base = np.zeros_like(X)
for nx, nz in NEXUS:
    base = np.maximum(base, np.clip((19 + noise - np.hypot(X - nx, Z - nz)) / 2.0, 0, 1))
outside = np.clip((np.maximum(np.abs(X), np.abs(Z)) - HALF) / 3.0, 0, 1)
road = road * (1 - outside)
river = river * (1 - outside) * (1 - base)
img = np.stack([road, river, base, 1 - outside], axis=-1)
os.makedirs("assets/textures", exist_ok=True)
Image.fromarray((img * 255).astype(np.uint8), "RGBA").save("assets/textures/map_mask.png")
print("mascara ok", img.shape)
