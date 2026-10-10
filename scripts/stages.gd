extends RefCounted

# Fichas de las etapas, en orden de juego. Cada etapa define su enemigo, sus muros y su ambientación;
# main.gd no conoce el número de etapas ni sus valores. Para añadir una etapa basta con otra entrada.
#
#   "id"           Identificador único y estable: clave de las medallas en la partida guardada.
#   "name", "hp"   Nombre (expediente y victoria) y vida del enemigo.
#   "motion"       0 = fijo, 1 = desplazamiento vertical, 2 = patrulla lenta.
#   "shield"       0 = sin escudo, 1 = intermitente, 2 = alta frecuencia.
#   "texture"      Sprite del enemigo; null = diana dibujada por código (usa "hit" como hitbox).
#   "hurt"/"death" Animaciones de dolor y muerte (formato abajo); null = sin animación.
#   "phases"       Opcional: jefes que entran, uno tras otro, al morir el anterior (misma partida,
#                  mismos muros y munición). Cada uno con name, hp, motion, shield, texture, hurt y death
#                  (y "hit" si no tiene sprite). Opcionales: "notice" (aviso al entrar; por defecto
#                  «¡NOMBRE ENTRA EN COMBATE!») y "add_walls" (muros que se levantan al entrar, mismo
#                  formato que "walls").
#   "zone"         Nombre del escenario en el expediente.
#   "color"        Color de fondo del escenario.
#   "music"        Tema de MUSIC (main.gd) durante la etapa.
#   "threat"       Franjas rojas de amenaza en el expediente (1–5).
#   "reloads"      Cargadores de reserva.
#   "walls"        Un muro por entrada, de izquierda a derecha:
#                  x (px), speed (rad/s), amp (recorrido vertical, px), gap (abertura, px),
#                  phase (rad), hp (impactos para romperlo) y breakable.
#
# Animaciones por sprite sheet. Por fotograma (px del PNG):
#   "src"     = región del fotograma en la hoja.
#   "anchors" = rectángulo que se hace coincidir con el sprite base dibujado (la cara), para que
#               el personaje no salte entre fotogramas aunque no esté centrado igual en cada uno.
# Las hojas pueden tener cualquier número de fotogramas (las de muerte nuevas tienen 5).
# Medidos sobre las hojas *_dolor.png y *_muerte.png (2172x724). Skullbit a mano; el resto
# por ajuste automático del sprite base sobre cada fotograma (escala fija por hoja, tools/anchors.py).
# En la hoja de muerte los fotogramas no tienen el mismo ancho (la explosión invade el hueco
# vecino) y desde el 2.º ya no hay cara: se anclan por el centro de masa de cada fotograma.

const LIST := [
	# Chile, entrenamiento: tres blancos seguidos; con cada uno se levanta un muro más.
	{"id":"sudamerica-1", "name":"Blanco de práctica", "hp":1, "motion":0, "shield":0, "hit":Vector2(62, 62),
		"texture":null, "hurt":null, "death":null,
		"zone":"Chile", "color":Color("#27425c"), "music":"levels_a", "threat":1, "reloads":1,
		"walls":[
			{"x":225.0, "speed":0.955, "amp":77.0, "gap":86.0, "phase":0.4, "hp":2, "breakable":true}
		],
		"phases":[
			{"name":"Blanco de práctica 2", "hp":1, "motion":0, "shield":0, "hit":Vector2(62, 62),
				"texture":null, "hurt":null, "death":null,
				"notice":"BLANCO 2: SE LEVANTA OTRO MURO",
				"add_walls":[{"x":450.0, "speed":1.15, "amp":77.0, "gap":86.0, "phase":1.85, "hp":3, "breakable":false}]},
			{"name":"Blanco de práctica 3", "hp":1, "motion":0, "shield":0, "hit":Vector2(62, 62),
				"texture":null, "hurt":null, "death":null,
				"notice":"BLANCO 3: SE LEVANTA OTRO MURO",
				"add_walls":[{"x":640.0, "speed":1.35, "amp":77.0, "gap":86.0, "phase":3.3, "hp":2, "breakable":true}]}
		]},
	{"id":"sudamerica-2", "name":"Jefe de Argentina", "hp":1, "motion":1, "shield":0,
		"texture":preload("res://assets/boss_argentina.png"),
		"hurt":{"texture":preload("res://assets/boss_argentina_dolor.png"), "fps":12.0,
			"src":[Rect2(0, 0, 555, 724), Rect2(555, 0, 539, 724), Rect2(1094, 0, 558, 724), Rect2(1652, 0, 520, 724)],
			"anchors":[Rect2(48, 88, 500, 592), Rect2(595, 88, 500, 592), Rect2(1094, 88, 500, 592), Rect2(1676, 88, 500, 592)]},
		"death":{"texture":preload("res://assets/boss_argentina_muerte.png"), "fps":8.0,
			"src":[Rect2(0, 0, 427, 724), Rect2(427, 0, 437, 724), Rect2(864, 0, 457, 724), Rect2(1321, 0, 476, 724), Rect2(1797, 0, 375, 724)],
			"anchors":[Rect2(44, 160, 384, 456), Rect2(459, 160, 384, 456), Rect2(872, 164, 384, 456), Rect2(1325, 164, 384, 456), Rect2(1780, 239, 384, 456)]},
		"zone":"Argentina", "color":Color("#375167"), "music":"levels_a", "threat":2, "reloads":1,
		"walls":[
			{"x":225.0, "speed":1.06, "amp":84.0, "gap":80.0, "phase":0.4, "hp":2, "breakable":true},
			{"x":472.5, "speed":1.34, "amp":84.0, "gap":80.0, "phase":1.85, "hp":3, "breakable":false}
		]},
	{"id":"sudamerica-3", "name":"Jefe de Colombia", "hp":2, "motion":1, "shield":1,
		"texture":preload("res://assets/boss_colombia.png"),
		"hurt":{"texture":preload("res://assets/boss_colombia_dolor.png"), "fps":12.0,
			"src":[Rect2(0, 0, 542, 724), Rect2(542, 0, 543, 724), Rect2(1085, 0, 544, 724), Rect2(1629, 0, 543, 724)],
			"anchors":[Rect2(-12, 80, 600, 604), Rect2(530, 80, 600, 604), Rect2(1073, 92, 600, 604), Rect2(1609, 76, 600, 604)]},
		"death":{"texture":preload("res://assets/boss_colombia_muerte.png"), "fps":8.0,
			"src":[Rect2(0, 0, 418, 724), Rect2(418, 0, 436, 724), Rect2(854, 0, 455, 724), Rect2(1309, 0, 487, 724), Rect2(1796, 0, 376, 724)],
			"anchors":[Rect2(-16, 184, 452, 456), Rect2(422, 184, 452, 456), Rect2(830, 184, 452, 456), Rect2(1293, 200, 452, 456), Rect2(1747, 251, 452, 456)]},
		"zone":"Colombia", "color":Color("#62413b"), "music":"levels_a", "threat":3, "reloads":1,
		"walls":[
			{"x":225.0, "speed":1.165, "amp":91.0, "gap":74.0, "phase":0.4, "hp":2, "breakable":true},
			{"x":390.0, "speed":1.445, "amp":91.0, "gap":74.0, "phase":1.85, "hp":3, "breakable":false},
			{"x":555.0, "speed":1.725, "amp":91.0, "gap":74.0, "phase":3.3, "hp":3, "breakable":true}
		]},
	{"id":"sudamerica-4", "name":"El General", "hp":2, "motion":2, "shield":1,
		"texture":preload("res://assets/boss_venezuela_1.png"),
		"hurt":{"texture":preload("res://assets/boss_venezuela_1_dolor.png"), "fps":12.0,
			"src":[Rect2(0, 0, 544, 724), Rect2(544, 0, 546, 724), Rect2(1090, 0, 552, 724), Rect2(1642, 0, 530, 724)],
			"anchors":[Rect2(0, 96, 536, 584), Rect2(548, 96, 536, 584), Rect2(1094, 92, 536, 584), Rect2(1654, 96, 536, 584)]},
		"death":{"texture":preload("res://assets/boss_venezuela_1_muerte.png"), "fps":8.0,
			"src":[Rect2(0, 0, 421, 724), Rect2(421, 0, 447, 724), Rect2(868, 0, 464, 724), Rect2(1332, 0, 453, 724), Rect2(1785, 0, 387, 724)],
			"anchors":[Rect2(4, 160, 416, 452), Rect2(457, 140, 416, 452), Rect2(868, 160, 416, 452), Rect2(1328, 160, 416, 452), Rect2(1762, 165, 416, 452)]},
		# Al morir El General entra El Mandatario, sin pasar por la victoria (ver "phases" arriba).
		"phases":[
			{"name":"El Mandatario", "hp":2, "motion":1, "shield":1,
				"texture":preload("res://assets/boss_venezuela_2.png"),
				"hurt":{"texture":preload("res://assets/boss_venezuela_2_dolor.png"), "fps":12.0,
					"src":[Rect2(0, 0, 543, 724), Rect2(543, 0, 542, 724), Rect2(1085, 0, 543, 724), Rect2(1628, 0, 544, 724)],
					"anchors":[Rect2(24, 112, 516, 604), Rect2(555, 112, 516, 604), Rect2(1097, 112, 516, 604), Rect2(1640, 100, 516, 604)]},
				"death":{"texture":preload("res://assets/boss_venezuela_2_muerte.png"), "fps":8.0,
					"src":[Rect2(0, 0, 407, 724), Rect2(407, 0, 463, 724), Rect2(870, 0, 450, 724), Rect2(1320, 0, 504, 724), Rect2(1824, 0, 348, 724)],
					"anchors":[Rect2(36, 176, 384, 448), Rect2(415, 156, 384, 448), Rect2(870, 176, 384, 448), Rect2(1356, 200, 384, 448), Rect2(1823, 203, 384, 448)]}}
		],
		"zone":"Venezuela", "color":Color("#1b254f"), "music":"levels_b", "threat":4, "reloads":2,
		"walls":[
			{"x":225.0, "speed":1.27, "amp":98.0, "gap":68.0, "phase":0.4, "hp":2, "breakable":true},
			{"x":348.75, "speed":1.55, "amp":98.0, "gap":68.0, "phase":1.85, "hp":3, "breakable":false},
			{"x":472.5, "speed":1.83, "amp":98.0, "gap":68.0, "phase":3.3, "hp":3, "breakable":true},
			{"x":596.25, "speed":2.11, "amp":98.0, "gap":68.0, "phase":4.75, "hp":3, "breakable":false}
		]},
	{"id":"sudamerica-5", "name":"Boss Retro Rojo", "hp":4, "motion":1, "shield":2,
		"texture":preload("res://assets/final_boss.png"),
		"hurt":{"texture":preload("res://assets/final_boss_dolor.png"), "fps":12.0,
			"src":[Rect2(0, 0, 554, 724), Rect2(554, 0, 529, 724), Rect2(1083, 0, 524, 724), Rect2(1607, 0, 565, 724)],
			"anchors":[Rect2(16, 108, 560, 540), Rect2(554, 108, 560, 540), Rect2(1063, 108, 560, 540), Rect2(1603, 108, 560, 540)]},
		"death":{"texture":preload("res://assets/final_boss_muerte.png"), "fps":8.0,
			"src":[Rect2(0, 0, 541, 724), Rect2(541, 0, 540, 724), Rect2(1081, 0, 544, 724), Rect2(1625, 0, 547, 724)],
			"anchors":[Rect2(44, 188, 452, 436), Rect2(557, 180, 452, 436), Rect2(1173, 156, 452, 436), Rect2(1621, 140, 452, 436)]},
		"zone":"Cuba", "color":Color("#3c103f"), "music":"boss", "threat":5, "reloads":2,
		"walls":[
			{"x":225.0, "speed":1.375, "amp":105.0, "gap":62.0, "phase":0.4, "hp":2, "breakable":true},
			{"x":324.0, "speed":1.655, "amp":105.0, "gap":62.0, "phase":1.85, "hp":3, "breakable":false},
			{"x":423.0, "speed":1.935, "amp":105.0, "gap":62.0, "phase":3.3, "hp":3, "breakable":true},
			{"x":522.0, "speed":2.215, "amp":105.0, "gap":62.0, "phase":4.75, "hp":3, "breakable":false},
			{"x":621.0, "speed":2.495, "amp":105.0, "gap":62.0, "phase":6.2, "hp":3, "breakable":true}
		]},
	# --- Mundo 2: Asia ---
	{"id":"asia-1", "name":"Mao Zedong", "hp":2, "motion":1, "shield":1,
		"texture":preload("res://assets/china_boss.png"),
		"hurt":{"texture":preload("res://assets/china_boss_pain.png"), "fps":12.0,
			"src":[Rect2(0, 0, 434, 724), Rect2(434, 0, 434, 724), Rect2(868, 0, 432, 724), Rect2(1300, 0, 435, 724), Rect2(1735, 0, 437, 724)],
			"anchors":[Rect2(8, 132, 420, 456), Rect2(442, 136, 420, 456), Rect2(852, 136, 420, 456), Rect2(1296, 136, 420, 456), Rect2(1735, 136, 420, 456)]},
		"death":{"texture":preload("res://assets/china_boss_muerte.png"), "fps":8.0,
			"src":[Rect2(0, 0, 417, 724), Rect2(417, 0, 435, 724), Rect2(852, 0, 439, 724), Rect2(1291, 0, 470, 724), Rect2(1761, 0, 411, 724)],
			"anchors":[Rect2(-4, 156, 412, 448), Rect2(413, 140, 412, 448), Rect2(864, 152, 412, 448), Rect2(1287, 148, 412, 448), Rect2(1739, 144, 412, 448)]},
		"zone":"China", "color":Color("#5a2a24"), "music":"levels_b", "threat":3, "reloads":1,
		"walls":[
			{"x":225.0, "speed":1.2, "amp":95.0, "gap":72.0, "phase":0.4, "hp":2, "breakable":true},
			{"x":400.0, "speed":1.5, "amp":95.0, "gap":72.0, "phase":1.85, "hp":3, "breakable":false},
			{"x":575.0, "speed":1.8, "amp":95.0, "gap":72.0, "phase":3.3, "hp":3, "breakable":true}
		]},
	{"id":"asia-2", "name":"Dinastía Kim", "hp":3, "motion":2, "shield":1,
		"texture":preload("res://assets/korea.png"),
		"hurt":{"texture":preload("res://assets/korea_dolor.png"), "fps":12.0,
			"src":[Rect2(0, 0, 444, 724), Rect2(444, 0, 427, 724), Rect2(871, 0, 426, 724), Rect2(1297, 0, 429, 724), Rect2(1726, 0, 446, 724)],
			"anchors":[Rect2(12, 148, 424, 456), Rect2(460, 148, 424, 456), Rect2(891, 148, 424, 456), Rect2(1305, 148, 424, 456), Rect2(1734, 144, 424, 456)]},
		"death":{"texture":preload("res://assets/korea_muerte.png"), "fps":8.0,
			"src":[Rect2(0, 0, 406, 724), Rect2(406, 0, 445, 724), Rect2(851, 0, 452, 724), Rect2(1303, 0, 508, 724), Rect2(1811, 0, 361, 724)],
			"anchors":[Rect2(48, 204, 348, 372), Rect2(446, 184, 348, 372), Rect2(863, 224, 348, 372), Rect2(1355, 180, 348, 372), Rect2(1824, 170, 348, 372)]},
		"zone":"Corea del Norte", "color":Color("#24324a"), "music":"levels_b", "threat":3, "reloads":2,
		"walls":[
			{"x":225.0, "speed":1.3, "amp":98.0, "gap":70.0, "phase":0.4, "hp":2, "breakable":true},
			{"x":400.0, "speed":1.6, "amp":98.0, "gap":70.0, "phase":1.85, "hp":3, "breakable":false},
			{"x":575.0, "speed":1.9, "amp":98.0, "gap":70.0, "phase":3.3, "hp":3, "breakable":true}
		]},
	{"id":"asia-3", "name":"Ho Chi Minh", "hp":3, "motion":1, "shield":1,
		"texture":preload("res://assets/vietnam.png"),
		"hurt":{"texture":preload("res://assets/vietnam_dolor.png"), "fps":12.0,
			"src":[Rect2(0, 0, 434, 724), Rect2(434, 0, 434, 724), Rect2(868, 0, 434, 724), Rect2(1302, 0, 435, 724), Rect2(1737, 0, 435, 724)],
			"anchors":[Rect2(16, 116, 400, 516), Rect2(462, 112, 400, 516), Rect2(912, 116, 400, 516), Rect2(1318, 124, 400, 516), Rect2(1761, 112, 400, 516)]},
		"death":{"texture":preload("res://assets/vietnam_muerte.png"), "fps":8.0,
			"src":[Rect2(0, 0, 383, 724), Rect2(383, 0, 462, 724), Rect2(845, 0, 452, 724), Rect2(1297, 0, 511, 724), Rect2(1808, 0, 364, 724)],
			"anchors":[Rect2(0, 160, 364, 468), Rect2(403, 156, 364, 468), Rect2(849, 156, 364, 468), Rect2(1365, 165, 364, 468), Rect2(1795, 244, 364, 468)]},
		"zone":"Vietnam", "color":Color("#2d4a2a"), "music":"levels_b", "threat":4, "reloads":2,
		"walls":[
			{"x":225.0, "speed":1.3, "amp":100.0, "gap":68.0, "phase":0.4, "hp":2, "breakable":true},
			{"x":350.0, "speed":1.55, "amp":100.0, "gap":68.0, "phase":1.85, "hp":3, "breakable":false},
			{"x":475.0, "speed":1.8, "amp":100.0, "gap":68.0, "phase":3.3, "hp":3, "breakable":true},
			{"x":600.0, "speed":2.05, "amp":100.0, "gap":68.0, "phase":4.75, "hp":3, "breakable":false}
		]},
	{"id":"asia-4", "name":"Kaysone Phomvihane", "hp":3, "motion":1, "shield":2,
		"texture":preload("res://assets/laos.png"),
		"hurt":{"texture":preload("res://assets/laos_dolor.png"), "fps":12.0,
			"src":[Rect2(0, 0, 437, 724), Rect2(437, 0, 432, 724), Rect2(869, 0, 433, 724), Rect2(1302, 0, 435, 724), Rect2(1737, 0, 435, 724)],
			"anchors":[Rect2(12, 144, 424, 488), Rect2(445, 144, 424, 488), Rect2(833, 144, 424, 488), Rect2(1290, 144, 424, 488), Rect2(1737, 144, 424, 488)]},
		"death":{"texture":preload("res://assets/laos_muerte.png"), "fps":8.0,
			"src":[Rect2(0, 0, 417, 724), Rect2(417, 0, 454, 724), Rect2(871, 0, 414, 724), Rect2(1285, 0, 483, 724), Rect2(1768, 0, 404, 724)],
			"anchors":[Rect2(12, 192, 372, 428), Rect2(405, 172, 372, 428), Rect2(855, 196, 372, 428), Rect2(1297, 168, 372, 428), Rect2(1769, 172, 372, 428)]},
		"zone":"Laos", "color":Color("#4a3a1e"), "music":"levels_b", "threat":4, "reloads":2,
		"walls":[
			{"x":225.0, "speed":1.35, "amp":100.0, "gap":66.0, "phase":0.4, "hp":2, "breakable":true},
			{"x":350.0, "speed":1.6, "amp":100.0, "gap":66.0, "phase":1.85, "hp":3, "breakable":false},
			{"x":475.0, "speed":1.85, "amp":100.0, "gap":66.0, "phase":3.3, "hp":3, "breakable":true},
			{"x":600.0, "speed":2.1, "amp":100.0, "gap":66.0, "phase":4.75, "hp":3, "breakable":false}
		]},
	{"id":"asia-5", "name":"Pol Pot", "hp":4, "motion":1, "shield":2,
		"texture":preload("res://assets/camboya.png"),
		"hurt":{"texture":preload("res://assets/camboya_dolor.png"), "fps":12.0,
			"src":[Rect2(0, 0, 453, 724), Rect2(453, 0, 422, 724), Rect2(875, 0, 424, 724), Rect2(1299, 0, 424, 724), Rect2(1723, 0, 449, 724)],
			"anchors":[Rect2(16, 192, 432, 456), Rect2(457, 192, 432, 456), Rect2(883, 192, 432, 456), Rect2(1307, 196, 432, 456), Rect2(1751, 196, 432, 456)]},
		"death":{"texture":preload("res://assets/camboya_muerte.png"), "fps":8.0,
			"src":[Rect2(0, 0, 381, 724), Rect2(381, 0, 476, 724), Rect2(857, 0, 437, 724), Rect2(1294, 0, 481, 724), Rect2(1775, 0, 397, 724)],
			"anchors":[Rect2(32, 216, 348, 368), Rect2(489, 200, 348, 368), Rect2(861, 204, 348, 368), Rect2(1354, 220, 348, 368), Rect2(1796, 279, 348, 368)]},
		"zone":"Camboya", "color":Color("#3a1218"), "music":"boss", "threat":5, "reloads":2,
		"walls":[
			{"x":225.0, "speed":1.375, "amp":105.0, "gap":64.0, "phase":0.4, "hp":2, "breakable":true},
			{"x":324.0, "speed":1.655, "amp":105.0, "gap":64.0, "phase":1.85, "hp":3, "breakable":false},
			{"x":423.0, "speed":1.935, "amp":105.0, "gap":64.0, "phase":3.3, "hp":3, "breakable":true},
			{"x":522.0, "speed":2.215, "amp":105.0, "gap":64.0, "phase":4.75, "hp":3, "breakable":false},
			{"x":621.0, "speed":2.495, "amp":105.0, "gap":64.0, "phase":6.2, "hp":3, "breakable":true}
		]}
]

# Mundos del mapa (scripts/world_map.gd), en orden; se pasa de uno al siguiente al ganar su última
# etapa. "background" es la imagen del mundo; "view" (opcional) la parte que se muestra, en px de la
# imagen (por defecto, entera; se escala para caber en el cuadrado del mapa). La imagen
# ya trae dibujados la ruta, los puntos y sus nombres. Cada nodo es una etapa de LIST:
#   "stage"  = nivel (índice 1.. de LIST)        "label"  = nombre del punto en el panel
#   "pos"    = centro del punto en la imagen (px) "radius" = radio del punto en la imagen (px)
#   "via"    = recodos de la ruta que llega desde el nodo anterior, en px de la imagen (opcional)
# Chile (diana de práctica) y Cuba (Boss Retro Rojo) conservan sus jefes provisionales.
const WORLDS := [
	{"id":"sudamerica", "name":"Mundo 1 · Campaña Sudamérica", "background":preload("res://assets/map_word_1.png"),
		"nodes":[
			{"stage":1, "label":"Chile", "pos":Vector2(450, 872), "radius":20.0},
			{"stage":2, "label":"Argentina", "pos":Vector2(554, 740), "radius":20.0,
				"via":[Vector2(500, 800)]},
			{"stage":3, "label":"Colombia", "pos":Vector2(493, 465), "radius":20.0,
				"via":[Vector2(555, 700), Vector2(540, 640), Vector2(518, 580), Vector2(498, 525)]},
			{"stage":4, "label":"Venezuela", "pos":Vector2(615, 385), "radius":20.0,
				"via":[Vector2(510, 440), Vector2(545, 410), Vector2(580, 392)]},
			{"stage":5, "label":"Cuba", "pos":Vector2(650, 240), "radius":30.0,
				"via":[Vector2(628, 340), Vector2(640, 290)]}
		]},
	{"id":"asia", "name":"Mundo 2 · Asia", "background":preload("res://assets/map_word_2.png"),
		# Sin la columna derecha (repite la lista de etapas del panel) ni la consola inferior.
		"view":Rect2(50, 25, 1050, 905),
		"nodes":[
			{"stage":6, "label":"China", "pos":Vector2(662, 285), "radius":22.0},
			{"stage":7, "label":"Corea del Norte", "pos":Vector2(902, 347), "radius":22.0,
				"via":[Vector2(760, 290), Vector2(812, 312), Vector2(855, 343)]},
			{"stage":8, "label":"Vietnam", "pos":Vector2(890, 672), "radius":22.0,
				"via":[Vector2(900, 392), Vector2(872, 440), Vector2(855, 500), Vector2(845, 570), Vector2(842, 645)]},
			# De Vietnam a Laos y de Laos a Camboya la ruta pasa por el cruce (punto 3 del mapa).
			{"stage":9, "label":"Laos", "pos":Vector2(700, 615), "radius":22.0,
				"via":[Vector2(842, 645), Vector2(790, 620), Vector2(735, 617)]},
			{"stage":10, "label":"Camboya", "pos":Vector2(738, 775), "radius":18.0,
				"via":[Vector2(735, 617), Vector2(790, 620), Vector2(842, 645), Vector2(870, 700), Vector2(812, 735), Vector2(772, 752)]}
		]}
]
