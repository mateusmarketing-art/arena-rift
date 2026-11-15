class_name Data
extends RefCounted
## Dados fixos do jogo: times, mapa, heróis, itens e tropas.

const VERSION := "1.0"
const PORT := 27450
const DISCOVERY_PORT := 27451

const TEAM_BLUE := 0
const TEAM_RED := 1
const TEAM_NEUTRAL := 2
const TEAM_COLORS := [Color(0.22, 0.55, 1.0), Color(1.0, 0.28, 0.22), Color(0.95, 0.75, 0.25)]
const TEAM_NAMES := ["Azul", "Vermelho", "Neutro"]

const MAP_HALF := 74.0
const NEXUS_POS := [Vector2(-62, 62), Vector2(62, -62)]
const FOUNTAIN_POS := [Vector2(-70, 70), Vector2(70, -70)]
const FOUNTAIN_RADIUS := 11.0

# Rotas do Azul até o Vermelho (top, meio, bot)
const LANES := [
	[Vector2(-62, 62), Vector2(-66, 34), Vector2(-66, -66), Vector2(-34, -66), Vector2(62, -62)],
	[Vector2(-62, 62), Vector2(62, -62)],
	[Vector2(-62, 62), Vector2(-34, 66), Vector2(66, 66), Vector2(66, -34), Vector2(62, -62)],
]
const LANE_NAMES := ["Rota Superior", "Rota do Meio", "Rota Inferior"]
# Distância das torres ao longo da rota, a partir do próprio Nexus
const TOWER_DIST := [26.0, 58.0]

const CAMPS := [
	# [posição, tipo]  tipo 0 = monstro da selva, 1 = guardião do rio
	[Vector2(-38, 8), 0], [Vector2(-8, 38), 0], [Vector2(-46, -14), 0], [Vector2(14, 46), 0],
	[Vector2(38, -8), 0], [Vector2(8, -38), 0], [Vector2(46, 14), 0], [Vector2(-14, -46), 0],
	[Vector2(-34, -34), 1], [Vector2(34, 34), 1],
]

const ROLE_LANE := {"top": 0, "jungle": -1, "mid": 1, "adc": 2, "sup": 2}

# Habilidades: tipos skillshot, dash, blink, nova, blast, buff, heal
# d = dano base, dl = dano por nível, r = proporção do bônus de itens
const HEROES := [
	{
		"name": "Kaelor", "title": "a Lâmina Rubra", "role": "top", "role_name": "Lutador",
		"desc": "Avança sobre os inimigos, aguenta a pancada e finaliza de cima.",
		"color": Color(0.85, 0.2, 0.15), "shape": "warrior",
		"hp": 680, "hp_lvl": 95, "atk": 62, "atk_lvl": 4.5, "armor": 32, "aspd": 0.8,
		"range": 1.9, "speed": 7.4, "ranged": false,
		"abilities": [
			{"key": "Q", "name": "Investida", "type": "dash", "cd": 7.0, "dist": 7.5, "d": 70, "dl": 14, "r": 0.9, "range": 7.5},
			{"key": "W", "name": "Postura de Ferro", "type": "buff", "cd": 14.0, "shield": 110, "sl": 22, "dur": 3.0, "haste": 1.25, "range": 0},
			{"key": "E", "name": "Redemoinho", "type": "nova", "cd": 9.0, "radius": 4.0, "d": 80, "dl": 15, "r": 0.8, "range": 4.0},
			{"key": "R", "name": "Execução Celeste", "type": "blast", "cd": 55.0, "radius": 3.8, "d": 230, "dl": 30, "r": 1.2, "range": 9.0, "delay": 0.45, "leap": true, "stun": 1.0},
		],
	},
	{
		"name": "Brontus", "title": "o Bastião", "role": "jungle", "role_name": "Tanque",
		"desc": "Domina a selva, prende inimigos e protege o time.",
		"color": Color(0.35, 0.6, 0.3), "shape": "tank",
		"hp": 780, "hp_lvl": 115, "atk": 54, "atk_lvl": 3.5, "armor": 42, "aspd": 0.72,
		"range": 2.0, "speed": 7.1, "ranged": false,
		"abilities": [
			{"key": "Q", "name": "Avanço do Colosso", "type": "dash", "cd": 9.0, "dist": 8.0, "d": 60, "dl": 12, "r": 0.6, "range": 8.0, "stun": 0.8},
			{"key": "W", "name": "Couraça Viva", "type": "buff", "cd": 16.0, "shield": 170, "sl": 30, "dur": 4.0, "range": 0},
			{"key": "E", "name": "Tremor", "type": "nova", "cd": 8.0, "radius": 5.0, "d": 55, "dl": 11, "r": 0.6, "range": 5.0, "slow": 0.45, "slow_dur": 1.8},
			{"key": "R", "name": "Fortaleza Inabalável", "type": "nova", "cd": 60.0, "radius": 6.5, "d": 160, "dl": 22, "r": 0.8, "range": 6.5, "stun": 1.3},
		],
	},
	{
		"name": "Nyxara", "title": "a Tecelã do Vazio", "role": "mid", "role_name": "Maga",
		"desc": "Dano explosivo à distância e controle de área.",
		"color": Color(0.55, 0.3, 0.95), "shape": "mage",
		"hp": 560, "hp_lvl": 80, "atk": 48, "atk_lvl": 3.0, "armor": 22, "aspd": 0.7,
		"range": 7.5, "speed": 7.2, "ranged": true,
		"abilities": [
			{"key": "Q", "name": "Orbe do Vazio", "type": "skillshot", "cd": 4.5, "d": 95, "dl": 20, "r": 1.0, "range": 15.0, "speed": 26.0, "width": 1.6},
			{"key": "W", "name": "Poço Gravitacional", "type": "blast", "cd": 11.0, "radius": 3.6, "d": 70, "dl": 15, "r": 0.7, "range": 12.0, "delay": 0.6, "slow": 0.5, "slow_dur": 2.0},
			{"key": "E", "name": "Passo Sombrio", "type": "blink", "cd": 14.0, "dist": 7.0, "range": 7.0},
			{"key": "R", "name": "Colapso Estelar", "type": "blast", "cd": 50.0, "radius": 5.2, "d": 300, "dl": 40, "r": 1.5, "range": 13.0, "delay": 0.8},
		],
	},
	{
		"name": "Vesper", "title": "a Caçadora do Crepúsculo", "role": "adc", "role_name": "Atiradora",
		"desc": "Ataques rápidos à distância e uma flecha que cruza o mapa.",
		"color": Color(0.95, 0.65, 0.15), "shape": "marksman",
		"hp": 590, "hp_lvl": 85, "atk": 60, "atk_lvl": 5.0, "armor": 24, "aspd": 0.85,
		"range": 9.0, "speed": 7.3, "ranged": true,
		"abilities": [
			{"key": "Q", "name": "Tiro Perfurante", "type": "skillshot", "cd": 6.0, "d": 85, "dl": 18, "r": 1.1, "range": 16.0, "speed": 34.0, "width": 1.3, "pierce": true},
			{"key": "W", "name": "Frenesi", "type": "buff", "cd": 15.0, "dur": 4.0, "aspd": 1.6, "haste": 1.2, "range": 0},
			{"key": "E", "name": "Rolamento", "type": "dash", "cd": 9.0, "dist": 5.5, "d": 0, "range": 5.5},
			{"key": "R", "name": "Flecha do Crepúsculo", "type": "skillshot", "cd": 60.0, "d": 260, "dl": 35, "r": 1.4, "range": 60.0, "speed": 42.0, "width": 2.2, "stun": 1.0},
		],
	},
	{
		"name": "Aurelia", "title": "a Guardiã Solar", "role": "sup", "role_name": "Suporte",
		"desc": "Cura, protege e atordoa para salvar os aliados.",
		"color": Color(1.0, 0.9, 0.45), "shape": "support",
		"hp": 600, "hp_lvl": 88, "atk": 46, "atk_lvl": 3.0, "armor": 28, "aspd": 0.7,
		"range": 7.0, "speed": 7.2, "ranged": true,
		"abilities": [
			{"key": "Q", "name": "Raio Solar", "type": "skillshot", "cd": 8.0, "d": 70, "dl": 14, "r": 0.8, "range": 13.0, "speed": 28.0, "width": 1.5, "stun": 1.1},
			{"key": "W", "name": "Bênção", "type": "heal", "cd": 12.0, "heal": 90, "hl": 18, "radius": 8.0, "range": 0},
			{"key": "E", "name": "Égide", "type": "buff", "cd": 14.0, "shield": 100, "sl": 20, "dur": 3.0, "allies": 8.0, "range": 0},
			{"key": "R", "name": "Aurora", "type": "heal", "cd": 70.0, "heal": 260, "hl": 35, "radius": 14.0, "range": 0,
				"then": {"type": "nova", "radius": 6.0, "d": 140, "dl": 20, "r": 0.8, "slow": 0.4, "slow_dur": 2.0}},
		],
	},
]

const ITEMS := [
	{"name": "Lâmina Afiada", "cost": 900, "atk": 25},
	{"name": "Cajado Arcano", "cost": 900, "pw": 40},
	{"name": "Coração de Pedra", "cost": 800, "hp": 300},
	{"name": "Placa de Guardião", "cost": 800, "armor": 30},
	{"name": "Botas Ligeiras", "cost": 600, "speed": 0.9},
	{"name": "Arco Ágil", "cost": 950, "aspd": 0.35},
	{"name": "Gume do Crepúsculo", "cost": 1800, "atk": 45, "aspd": 0.2},
	{"name": "Orbe Celestial", "cost": 1800, "pw": 85},
	{"name": "Égide do Titã", "cost": 1800, "hp": 450, "armor": 35},
]

const BUILDS := {
	"top": [4, 0, 2, 6, 3, 8],
	"jungle": [4, 2, 3, 8, 2, 0],
	"mid": [4, 1, 7, 1, 2, 7],
	"adc": [4, 5, 0, 6, 6, 2],
	"sup": [4, 2, 1, 8, 3, 7],
}

const MINIONS := {
	"melee": {"hp": 430, "atk": 20, "aspd": 0.8, "range": 1.6, "speed": 6.0, "armor": 10, "gold": 22, "xp": 32, "radius": 0.55, "ranged": false},
	"ranged": {"hp": 290, "atk": 30, "aspd": 0.7, "range": 6.0, "speed": 6.0, "armor": 0, "gold": 16, "xp": 26, "radius": 0.5, "ranged": true},
	"siege": {"hp": 900, "atk": 45, "aspd": 0.6, "range": 7.5, "speed": 5.6, "armor": 25, "gold": 50, "xp": 60, "radius": 0.9, "ranged": true},
}

const KIND_CODE := {"hero": 0, "melee": 1, "ranged": 2, "siege": 3, "tower": 4, "nexus": 5, "monster": 6, "boss": 7}


static func lane_path(lane: int, team: int) -> PackedVector2Array:
	var p := PackedVector2Array(LANES[lane])
	if team == TEAM_RED:
		p.reverse()
	return p


static func point_along(path: PackedVector2Array, dist: float) -> Vector2:
	var left := dist
	for i in range(path.size() - 1):
		var seg := path[i].distance_to(path[i + 1])
		if left <= seg:
			return path[i].lerp(path[i + 1], left / seg)
		left -= seg
	return path[path.size() - 1]


static func dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func dist_to_lanes(p: Vector2) -> float:
	var best := 1e9
	for lane in LANES:
		for i in range(lane.size() - 1):
			best = minf(best, dist_to_segment(p, lane[i], lane[i + 1]))
	return best


## Árvores e rochas da selva, iguais em todos os aparelhos (semente fixa).
static func gen_obstacles() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var out := []
	var tries := 0
	while out.size() < 70 and tries < 4000:
		tries += 1
		var p := Vector2(rng.randf_range(-70, 70), rng.randf_range(-70, 70))
		if dist_to_lanes(p) < 9.0:
			continue
		if absf(p.x - p.y) / sqrt(2.0) < 5.5:
			continue  # rio
		if p.distance_to(NEXUS_POS[0]) < 22.0 or p.distance_to(NEXUS_POS[1]) < 22.0:
			continue
		var ok := true
		for c in CAMPS:
			if p.distance_to(c[0]) < 8.5:
				ok = false
				break
		for o in out:
			if p.distance_to(Vector2(o.x, o.y)) < 6.0:
				ok = false
				break
		if not ok:
			continue
		# Mantém espelhado para o mapa ser justo
		var r := rng.randf_range(1.3, 2.2)
		out.append(Vector3(p.x, p.y, r))
		out.append(Vector3(-p.x, -p.y, r))
	return out


static func xp_to_next(level: int) -> float:
	return 100.0 + 55.0 * (level - 1)
