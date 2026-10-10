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
# Medidos sobre las hojas *_dolor.png y *_muerte.png (2172x724). Skullbit a mano; el resto
# por ajuste automático del sprite base sobre cada fotograma (escala fija por hoja, tools/anchors.py).
# En la hoja de muerte los fotogramas no tienen el mismo ancho (la explosión invade el hueco
# vecino) y desde el 2.º ya no hay cara: se anclan por el centro de masa de cada fotograma.

const LIST := [
	{"id":"sudamerica-1", "name":"Blanco clásico", "hp":1, "motion":0, "shield":0, "hit":Vector2(62, 62),
		"texture":null, "hurt":null, "death":null,
		"zone":"Chile", "color":Color("#27425c"), "music":"levels_a", "threat":1, "reloads":1,
		"walls":[
			{"x":225.0, "speed":0.955, "amp":77.0, "gap":86.0, "phase":0.4, "hp":2, "breakable":true}
		]},
	{"id":"sudamerica-2", "name":"Drone visor", "hp":1, "motion":1, "shield":0,
		"texture":preload("res://assets/enemy.png"),
		"hurt":{"texture":preload("res://assets/enemy_dolor.png"), "fps":12.0,
			"src":[Rect2(0, 0, 563, 724), Rect2(563, 0, 521, 724), Rect2(1084, 0, 565, 724), Rect2(1649, 0, 523, 724)],
			"anchors":[Rect2(84, 188, 460, 436), Rect2(607, 188, 460, 436), Rect2(1156, 204, 460, 436), Rect2(1681, 196, 460, 436)]},
		"death":{"texture":preload("res://assets/enemy_muerte.png"), "fps":8.0,
			"src":[Rect2(0, 0, 532, 724), Rect2(532, 0, 553, 724), Rect2(1085, 0, 535, 724), Rect2(1620, 0, 552, 724)],
			"anchors":[Rect2(48, 212, 444, 420), Rect2(564, 216, 444, 420), Rect2(1089, 232, 444, 420), Rect2(1696, 288, 444, 420)]},
		"zone":"Argentina", "color":Color("#375167"), "music":"levels_a", "threat":2, "reloads":1,
		"walls":[
			{"x":225.0, "speed":1.06, "amp":84.0, "gap":80.0, "phase":0.4, "hp":2, "breakable":true},
			{"x":472.5, "speed":1.34, "amp":84.0, "gap":80.0, "phase":1.85, "hp":3, "breakable":false}
		]},
	{"id":"sudamerica-3", "name":"Mini-boss Skullbit", "hp":2, "motion":1, "shield":1,
		"texture":preload("res://assets/level_3_boss.png"),
		"hurt":{"texture":preload("res://assets/level_3_boss_dolor.png"), "fps":12.0,
			"src":[Rect2(0, 0, 543, 724), Rect2(543, 0, 543, 724), Rect2(1086, 0, 543, 724), Rect2(1629, 0, 543, 724)],
			"anchors":[Rect2(102, 71, 385, 589), Rect2(627, 71, 383, 590), Rect2(1148, 70, 387, 589), Rect2(1688, 71, 385, 589)]},
		"death":{"texture":preload("res://assets/level_3_boss_muerte.png"), "fps":8.0,
			"src":[Rect2(0, 0, 470, 724), Rect2(470, 0, 510, 724), Rect2(980, 0, 618, 724), Rect2(1598, 0, 574, 724)],
			"anchors":[Rect2(92, 140, 310, 483), Rect2(578, 152, 310, 483), Rect2(1128, 153, 310, 483), Rect2(1738, 152, 310, 483)]},
		"zone":"Colombia", "color":Color("#62413b"), "music":"levels_a", "threat":3, "reloads":1,
		"walls":[
			{"x":225.0, "speed":1.165, "amp":91.0, "gap":74.0, "phase":0.4, "hp":2, "breakable":true},
			{"x":390.0, "speed":1.445, "amp":91.0, "gap":74.0, "phase":1.85, "hp":3, "breakable":false},
			{"x":555.0, "speed":1.725, "amp":91.0, "gap":74.0, "phase":3.3, "hp":3, "breakable":true}
		]},
	{"id":"sudamerica-4", "name":"Centinela blindado", "hp":3, "motion":2, "shield":1,
		"texture":preload("res://assets/level_4_boss.png"),
		"hurt":{"texture":preload("res://assets/level_4_boss_dolor.png"), "fps":12.0,
			"src":[Rect2(0, 0, 579, 724), Rect2(579, 0, 518, 724), Rect2(1097, 0, 538, 724), Rect2(1635, 0, 537, 724)],
			"anchors":[Rect2(64, 104, 552, 568), Rect2(615, 104, 552, 568), Rect2(1113, 108, 552, 568), Rect2(1667, 108, 552, 568)]},
		"death":{"texture":preload("res://assets/level_4_boss_muerte.png"), "fps":8.0,
			"src":[Rect2(0, 0, 517, 724), Rect2(517, 0, 571, 724), Rect2(1088, 0, 548, 724), Rect2(1636, 0, 536, 724)],
			"anchors":[Rect2(32, 188, 452, 464), Rect2(621, 192, 452, 464), Rect2(1176, 184, 452, 464), Rect2(1685, 251, 452, 464)]},
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
		]}
]

# Mundos del mapa (scripts/world_map.gd), en orden. "background" es la imagen del mundo (cuadrada;
# ya trae dibujados la ruta, los puntos y sus nombres). Cada nodo es una etapa de LIST:
#   "stage"  = nivel (índice 1.. de LIST)        "label"  = nombre del punto en el panel
#   "pos"    = centro del punto en la imagen (px) "radius" = radio del punto en la imagen (px)
#   "via"    = recodos de la ruta que llega desde el nodo anterior, en px de la imagen (opcional)
# Provisional: las etapas de Sudamérica usan aún los cinco jefes originales.
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
		]}
]
