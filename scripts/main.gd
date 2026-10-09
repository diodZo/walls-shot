extends Control

# WALLSHOT - primera migración nativa de HTML5 a Godot 4.
# Lógica de juego a 1000x470; panel UI bajo el escenario.
const WIDTH := 1000.0
const HEIGHT := 470.0
const LINE_Y := 235.0
const SAVE_PATH := "user://wallshot_save.json"
const WALL_TEXTURE := preload("res://assets/wall.png")
const PISTOL_TEXTURE := preload("res://assets/pistol.png")
const SHOTGUN_TEXTURE := preload("res://assets/shotgun.png")
const PLASMA_TEXTURE := preload("res://assets/plasma.png")
const BOSS_TEXTURE := preload("res://assets/enemy.png")
const LEVEL_3_BOSS_TEXTURE := preload("res://assets/level_3_boss.png")
const LEVEL_4_BOSS_TEXTURE := preload("res://assets/level_4_boss.png")
const FINAL_BOSS_TEXTURE := preload("res://assets/final_boss.png")
# Sprite por nivel; null = enemigo dibujado por código en draw_enemy().
const ENEMY_TEXTURES := [null, BOSS_TEXTURE, LEVEL_3_BOSS_TEXTURE, LEVEL_4_BOSS_TEXTURE, FINAL_BOSS_TEXTURE]
const ENEMY_SPRITE_BOX := 130.0
const SPRITE_HITBOX_FILL := 0.85
# Ancho en pantalla de cada sprite de arma (índice "sprite" de WEAPONS).
const GUN_WIDTHS := [111.0, 152.0, 140.0]
const RELOAD_DURATION := 1.1
# Animaciones de arma por índice "sprite" de WEAPONS (mismo formato que HURT_ANIMATIONS).
# "fire" se reproduce al disparar; "reload" reparte sus fotogramas a lo largo de la recarga.
# Anclas = posición del sprite base del arma en cada fotograma, por ajuste automático de silueta.
const WEAPON_ANIMATIONS := {
	0: {
		"fire": {"texture":preload("res://assets/pistol_firing.png"), "fps":16.0,
			"src":[Rect2(0, 0, 540, 724), Rect2(540, 0, 520, 724), Rect2(1060, 0, 612, 724), Rect2(1672, 0, 500, 724)],
			"anchors":[Rect2(60, 244, 432, 308), Rect2(592, 248, 432, 308), Rect2(1092, 244, 432, 308), Rect2(1680, 244, 432, 308)]},
		"reload": {"texture":preload("res://assets/pistol_reloading.png"), "fps":0.0,
			"src":[Rect2(0, 0, 564, 724), Rect2(564, 0, 514, 724), Rect2(1078, 0, 525, 724), Rect2(1603, 0, 569, 724)],
			"anchors":[Rect2(52, 172, 472, 336), Rect2(588, 172, 472, 336), Rect2(1114, 172, 472, 336), Rect2(1667, 172, 472, 336)]}
	},
	1: {
		"fire": {"texture":preload("res://assets/shotgun_firing.png"), "fps":16.0,
			"src":[Rect2(0, 0, 530, 724), Rect2(530, 0, 529, 724), Rect2(1059, 0, 587, 724), Rect2(1646, 0, 526, 724)],
			"anchors":[Rect2(20, 308, 468, 128), Rect2(570, 308, 468, 128), Rect2(1079, 304, 468, 128), Rect2(1646, 308, 468, 128)]},
		"reload": {"texture":preload("res://assets/shotgun_reloading.png"), "fps":0.0,
			"src":[Rect2(0, 0, 541, 724), Rect2(541, 0, 544, 724), Rect2(1085, 0, 544, 724), Rect2(1629, 0, 543, 724)],
			"anchors":[Rect2(16, 284, 484, 132), Rect2(557, 284, 484, 132), Rect2(1101, 284, 484, 132), Rect2(1645, 284, 484, 132)]}
	},
	2: {
		"fire": {"texture":preload("res://assets/plasma_firing.png"), "fps":16.0,
			"src":[Rect2(0, 0, 552, 724), Rect2(552, 0, 518, 724), Rect2(1070, 0, 604, 724), Rect2(1674, 0, 498, 724)],
			"anchors":[Rect2(32, 308, 484, 200), Rect2(588, 308, 484, 200), Rect2(1090, 304, 484, 200), Rect2(1686, 308, 484, 200)]},
		"reload": {"texture":preload("res://assets/plasma_reloading.png"), "fps":0.0,
			"src":[Rect2(0, 0, 551, 724), Rect2(551, 0, 537, 724), Rect2(1088, 0, 536, 724), Rect2(1624, 0, 548, 724)],
			"anchors":[Rect2(32, 252, 500, 208), Rect2(571, 252, 500, 208), Rect2(1108, 248, 500, 208), Rect2(1644, 252, 500, 208)]}
	}
}
# Animaciones por sprite sheet, por nivel. Por fotograma (px del PNG):
#   "src"     = región del fotograma en la hoja.
#   "anchors" = rectángulo que se hace coincidir con el sprite base dibujado (la cara), para que
#               el personaje no salte entre fotogramas aunque no esté centrado igual en cada uno.
# Medidos sobre las hojas *_dolor.png y *_muerte.png (2172x724). Nivel 3 a mano; niveles 2, 4 y 5
# por ajuste automático del sprite base sobre cada fotograma (escala fija por hoja).
const HURT_ANIMATIONS := {
	2: {"texture":preload("res://assets/enemy_dolor.png"), "fps":12.0,
		"src":[Rect2(0, 0, 563, 724), Rect2(563, 0, 521, 724), Rect2(1084, 0, 565, 724), Rect2(1649, 0, 523, 724)],
		"anchors":[Rect2(84, 188, 460, 436), Rect2(607, 188, 460, 436), Rect2(1156, 204, 460, 436), Rect2(1681, 196, 460, 436)]},
	3: {"texture":preload("res://assets/level_3_boss_dolor.png"), "fps":12.0,
		"src":[Rect2(0, 0, 543, 724), Rect2(543, 0, 543, 724), Rect2(1086, 0, 543, 724), Rect2(1629, 0, 543, 724)],
		"anchors":[Rect2(102, 71, 385, 589), Rect2(627, 71, 383, 590), Rect2(1148, 70, 387, 589), Rect2(1688, 71, 385, 589)]},
	4: {"texture":preload("res://assets/level_4_boss_dolor.png"), "fps":12.0,
		"src":[Rect2(0, 0, 579, 724), Rect2(579, 0, 518, 724), Rect2(1097, 0, 538, 724), Rect2(1635, 0, 537, 724)],
		"anchors":[Rect2(64, 104, 552, 568), Rect2(615, 104, 552, 568), Rect2(1113, 108, 552, 568), Rect2(1667, 108, 552, 568)]},
	5: {"texture":preload("res://assets/final_boss_dolor.png"), "fps":12.0,
		"src":[Rect2(0, 0, 554, 724), Rect2(554, 0, 529, 724), Rect2(1083, 0, 524, 724), Rect2(1607, 0, 565, 724)],
		"anchors":[Rect2(16, 108, 560, 540), Rect2(554, 108, 560, 540), Rect2(1063, 108, 560, 540), Rect2(1603, 108, 560, 540)]}
}
# En la hoja de muerte los fotogramas no tienen el mismo ancho (la explosión invade el hueco
# vecino) y desde el 2.º ya no hay cara: se anclan por el centro de masa de cada fotograma.
const DEATH_ANIMATIONS := {
	2: {"texture":preload("res://assets/enemy_muerte.png"), "fps":8.0,
		"src":[Rect2(0, 0, 532, 724), Rect2(532, 0, 553, 724), Rect2(1085, 0, 535, 724), Rect2(1620, 0, 552, 724)],
		"anchors":[Rect2(48, 212, 444, 420), Rect2(564, 216, 444, 420), Rect2(1089, 232, 444, 420), Rect2(1696, 288, 444, 420)]},
	3: {"texture":preload("res://assets/level_3_boss_muerte.png"), "fps":8.0,
		"src":[Rect2(0, 0, 470, 724), Rect2(470, 0, 510, 724), Rect2(980, 0, 618, 724), Rect2(1598, 0, 574, 724)],
		"anchors":[Rect2(92, 140, 310, 483), Rect2(578, 152, 310, 483), Rect2(1128, 153, 310, 483), Rect2(1738, 152, 310, 483)]},
	4: {"texture":preload("res://assets/level_4_boss_muerte.png"), "fps":8.0,
		"src":[Rect2(0, 0, 517, 724), Rect2(517, 0, 571, 724), Rect2(1088, 0, 548, 724), Rect2(1636, 0, 536, 724)],
		"anchors":[Rect2(32, 188, 452, 464), Rect2(621, 192, 452, 464), Rect2(1176, 184, 452, 464), Rect2(1685, 251, 452, 464)]},
	5: {"texture":preload("res://assets/final_boss_muerte.png"), "fps":8.0,
		"src":[Rect2(0, 0, 541, 724), Rect2(541, 0, 540, 724), Rect2(1081, 0, 544, 724), Rect2(1625, 0, 547, 724)],
		"anchors":[Rect2(44, 188, 452, 436), Rect2(557, 180, 452, 436), Rect2(1173, 156, 452, 436), Rect2(1621, 140, 452, 436)]}
}
const ENEMY_X := 916.0
const BULLET_RADIUS := 5.0
const MAX_PARTICLES := 240
const PARTICLE_GRAVITY := 520.0
const WEAPONS := [
	{"name":"Pistola básica","price":0,"speed":660.0,"ammo":8,"damage":1,"ability":"none","sprite":0},
	{"name":"Pistola mejorada","price":250,"speed":920.0,"ammo":10,"damage":1,"ability":"slow","sprite":0},
	{"name":"Rifle de precisión","price":650,"speed":1250.0,"ammo":14,"damage":1,"ability":"pierce","sprite":1},
	{"name":"Cañón de plasma","price":1600,"speed":1090.0,"ammo":12,"damage":2,"ability":"double_pierce","sprite":2}
]
const ENEMIES := [
	# "hit": semiejes de la hitbox de los enemigos dibujados por código.
	# Los jefes con sprite (ENEMY_TEXTURES) calculan la suya a partir del sprite visible.
	{"name":"Blanco clásico","hp":1,"motion":0,"shield":0,"hit":Vector2(62, 62)},
	{"name":"Drone visor","hp":1,"motion":1,"shield":0},
	{"name":"Mini-boss Skullbit","hp":2,"motion":1,"shield":1},
	{"name":"Centinela blindado","hp":3,"motion":2,"shield":1},
	{"name":"Boss Retro Rojo","hp":4,"motion":1,"shield":2}
]
const COLORS := [Color("#27425c"),Color("#375167"),Color("#62413b"),Color("#1b254f"),Color("#3c103f")]
const WORLD_NAMES := ["Campo de tiro", "Taller industrial", "Fábrica al atardecer", "Laboratorio nocturno", "Arena neón"]

var coins := 0
var score := 0
var level := 1
var unlocked := 1
var owned := [0]
var equipped := 0
var stars := {}
var walls: Array[Dictionary] = []
var bullet := {}
var particles: Array[Dictionary] = []
var shots := 0
var reloads_left := 1
var reload_time := 0.0
var elapsed := 0.0
var focus_time := 0.0
var pierce_next := 0
var abilities_left := 2
var kick := 0.0
var status := "menu" # menu / play / dying / lose / win
var enemy_hp := 1
var enemy_max_hp := 1
var enemy_y := LINE_Y
var shield_open := true
var notice := ""
var notice_time := 0.0
var fire_button: Button
var reload_button: Button
var ability_button: Button
var overlay_panel: PanelContainer
var overlay_title: Label
var overlay_message: Label
var overlay_start: Button
var overlay_menu: Button
var hud: Label
var weapon_box: OptionButton
var level_box: OptionButton
var sound_enabled := true
var sprite_regions := {}
var hurt_time := 0.0 # tiempo transcurrido de la animación de dolor; < 0 = inactiva
var fire_time := -1.0 # tiempo transcurrido de la animación de disparo del arma; < 0 = inactiva
var death_time := -1.0 # tiempo transcurrido de la animación de muerte (status "dying"); < 0 = inactiva
var enemy_defeated := false # la animación de muerte terminó: el jefe ya no se dibuja

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	# draw_wall_rect() muestrea una región mayor que la textura del muro: necesita repetición.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	load_game()
	build_ui()
	reset_stage()
	show_overlay("WALLSHOT GODOT", "Migración nativa. Atraviesa los muros móviles y vence cinco enemigos.", "JUGAR", false)
	set_process(true)

func build_ui() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(15, 479)
	bar.size = Vector2(970, 42)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	fire_button = make_button("DISPARAR", Callable(self, "fire"), bar)
	reload_button = make_button("RECARGAR (R)", Callable(self, "reload_weapon"), bar)
	ability_button = make_button("HABILIDAD (E)", Callable(self, "special"), bar)
	make_button("REINICIAR", Callable(self, "start_stage"), bar)
	make_button("MENÚ", Callable(self, "go_menu"), bar)
	hud = Label.new()
	hud.position = Vector2(15, 531)
	hud.size = Vector2(970, 23)
	hud.add_theme_font_size_override("font_size", 17)
	add_child(hud)
	var selectors := HBoxContainer.new()
	selectors.position = Vector2(15, 571)
	selectors.size = Vector2(970, 52)
	selectors.add_theme_constant_override("separation", 18)
	add_child(selectors)
	var weapons_label := Label.new()
	weapons_label.text = "ARSENAL"
	selectors.add_child(weapons_label)
	weapon_box = OptionButton.new()
	weapon_box.custom_minimum_size = Vector2(325, 36)
	weapon_box.focus_mode = Control.FOCUS_NONE
	selectors.add_child(weapon_box)
	weapon_box.item_selected.connect(choose_weapon)
	var levels_label := Label.new()
	levels_label.text = "NIVEL"
	selectors.add_child(levels_label)
	level_box = OptionButton.new()
	level_box.custom_minimum_size = Vector2(240, 36)
	level_box.focus_mode = Control.FOCUS_NONE
	selectors.add_child(level_box)
	level_box.item_selected.connect(choose_level)
	overlay_panel = PanelContainer.new()
	overlay_panel.position = Vector2(210, 70)
	overlay_panel.size = Vector2(580, 315)
	add_child(overlay_panel)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 15)
	overlay_panel.add_child(layout)
	overlay_title = Label.new()
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 33)
	layout.add_child(overlay_title)
	overlay_message = Label.new()
	overlay_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_message.custom_minimum_size = Vector2(540, 100)
	layout.add_child(overlay_message)
	overlay_start = make_button("JUGAR", Callable(self, "start_stage"), layout, true)
	overlay_menu = make_button("MENÚ PRINCIPAL", Callable(self, "go_menu"), layout, true)
	refresh_ui()

func make_button(label: String, fn: Callable, parent: Node, focusable: bool = false) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(112, 40)
	# Sin foco, ESPACIO no activa el último botón pulsado (p. ej. REINICIAR) en lugar de disparar.
	if not focusable:
		button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(fn)
	parent.add_child(button)
	return button

func refresh_ui() -> void:
	if hud == null:
		return
	var weapon: Dictionary = WEAPONS[equipped]
	var ammo_left: int = maxi(0, int(weapon["ammo"]) - shots)
	hud.text = "NIVEL %d/5   MONEDAS %d   PUNTOS %d   BALAS %d   CARGADORES %d   HABILIDADES %d   ENEMIGO %d/%d" % [level, coins, score, ammo_left, reloads_left, abilities_left, enemy_hp, enemy_max_hp]
	fire_button.disabled = status != "play" or not bullet.is_empty() or reload_time > 0.0
	reload_button.disabled = status != "play" or reload_time > 0.0 or reloads_left <= 0 or not bullet.is_empty()
	ability_button.disabled = status != "play" or abilities_left <= 0 or weapon["ability"] == "none" or not bullet.is_empty()
	weapon_box.clear()
	for i in range(WEAPONS.size()):
		var info: Dictionary = WEAPONS[i]
		var label: String = str(info["name"])
		if not owned.has(i):
			label += " — COMPRAR %d monedas" % int(info["price"])
		weapon_box.add_item(label, i)
	weapon_box.select(equipped)
	level_box.clear()
	for i in range(1, 6):
		level_box.add_item("Nivel %d %s" % [i, "✓" if i < unlocked else ("🔒" if i > unlocked else "")], i)
		level_box.set_item_disabled(i - 1, i > unlocked)
	level_box.select(level - 1)

func reset_stage() -> void:
	walls.clear()
	particles.clear()
	bullet.clear()
	shots = 0
	reloads_left = 2 if level >= 4 else 1
	reload_time = 0.0
	elapsed = 0.0
	focus_time = 0.0
	pierce_next = 0
	abilities_left = 0 if WEAPONS[equipped]["ability"] == "none" else 2
	enemy_hp = int(ENEMIES[level - 1]["hp"])
	enemy_max_hp = enemy_hp
	hurt_time = -1.0
	death_time = -1.0
	enemy_defeated = false
	fire_time = -1.0
	enemy_y = LINE_Y
	shield_open = true
	for i in range(level):
		walls.append({"x":225.0 + float(i) * 495.0 / float(max(level, 2)), "w":31.0, "center":LINE_Y, "phase":float(i) * 1.45 + 0.4, "clock":0.0, "speed":0.85 + float(i) * 0.28 + float(level) * 0.105, "amp":70.0 + float(level) * 7.0, "gap":86.0 - float(level - 1) * 6.0, "hp":2 if i == 0 else 3, "breakable":i == 0 or (level >= 3 and i % 2 == 0), "broken":false})
	refresh_ui()
	queue_redraw()

func start_stage() -> void:
	if overlay_start.pressed.is_connected(next_stage):
		overlay_start.pressed.disconnect(next_stage)
	if not overlay_start.pressed.is_connected(start_stage):
		overlay_start.pressed.connect(start_stage)
	status = "play"
	reset_stage()
	overlay_panel.hide()

func go_menu() -> void:
	status = "menu"
	reset_stage()
	show_overlay("WALLSHOT GODOT", "Elige nivel y arma. Gana monedas para desbloquear el arsenal.", "JUGAR", false)

func show_overlay(title: String, message: String, button_text: String, show_menu: bool = true) -> void:
	if overlay_start.pressed.is_connected(next_stage):
		overlay_start.pressed.disconnect(next_stage)
	if not overlay_start.pressed.is_connected(start_stage):
		overlay_start.pressed.connect(start_stage)
	overlay_panel.show()
	overlay_title.text = title
	overlay_message.text = message
	overlay_start.text = button_text
	overlay_menu.visible = show_menu
	refresh_ui()

func choose_weapon(index: int) -> void:
	if index == equipped:
		return
	var info: Dictionary = WEAPONS[index]
	if not owned.has(index):
		if coins < int(info["price"]):
			notify("Monedas insuficientes")
			refresh_ui()
			return
		coins -= int(info["price"])
		owned.append(index)
	equipped = index
	# Equipar está permitido entre partidas; en plena partida reiniciamos el nivel para evitar recargas gratuitas.
	if status == "play":
		reset_stage()
	save_game()
	refresh_ui()

func choose_level(index: int) -> void:
	var candidate := index + 1
	if candidate > unlocked:
		refresh_ui()
		return
	level = candidate
	save_game()
	start_stage()

func fire() -> void:
	if status != "play" or not bullet.is_empty() or reload_time > 0.0:
		return
	var w: Dictionary = WEAPONS[equipped]
	if shots >= int(w["ammo"]):
		reload_weapon()
		return
	shots += 1
	bullet = {"x":125.0, "y":LINE_Y, "speed":float(w["speed"]), "damage":int(w["damage"]), "pierce":pierce_next, "ignored":[]}
	pierce_next = 0
	kick = 1.0
	fire_time = 0.0
	refresh_ui()

func reload_weapon() -> void:
	if status != "play" or reload_time > 0.0 or reloads_left <= 0 or not bullet.is_empty():
		return
	reloads_left -= 1
	reload_time = RELOAD_DURATION
	notify("RECARGANDO...")
	refresh_ui()

func special() -> void:
	if status != "play" or not bullet.is_empty() or abilities_left <= 0 or reload_time > 0.0:
		return
	var ability: String = str(WEAPONS[equipped]["ability"])
	if ability == "none":
		return
	abilities_left -= 1
	if ability == "slow":
		focus_time = 3.0
		notify("TIEMPO LENTO")
	else:
		pierce_next = 2 if ability == "double_pierce" else 1
		notify("PERFORACIÓN PREPARADA")
	refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			fire()
		elif event.keycode == KEY_R:
			reload_weapon()
		elif event.keycode == KEY_E:
			special()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.position.y < HEIGHT:
		fire()

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.033)
	kick = maxf(0.0, kick - dt * 6.0)
	if hurt_time >= 0.0:
		hurt_time += dt
		if hurt_frame() < 0:
			hurt_time = -1.0
	if fire_time >= 0.0:
		fire_time += dt
		if weapon_fire_frame() < 0:
			fire_time = -1.0
	if status == "dying":
		# Pausa dramática: el escenario se congela mientras el jefe explota.
		death_time += dt
		if death_frame() < 0:
			death_time = -1.0
			enemy_defeated = true
			win_stage()
	notice_time = maxf(0.0, notice_time - dt)
	if reload_time > 0.0:
		reload_time = maxf(0.0, reload_time - dt)
		if reload_time <= 0.0:
			shots = 0
			notify("RECARGA COMPLETA")
			refresh_ui()
	if status == "play":
		elapsed += dt
		focus_time = maxf(0.0, focus_time - dt)
		var profile: Dictionary = ENEMIES[level - 1]
		var motion: int = int(profile["motion"])
		enemy_y = LINE_Y + (sin(elapsed * 2.2) * 36.0 if motion == 1 else (sin(elapsed * 1.2) * 18.0 if motion == 2 else 0.0))
		var shield: int = int(profile["shield"])
		shield_open = shield == 0 or (sin(elapsed * (1.65 if shield == 2 else 2.0)) > -0.15)
		for i in range(walls.size()):
			if bool(walls[i]["broken"]):
				continue
			walls[i]["clock"] = float(walls[i]["clock"]) + dt * float(walls[i]["speed"]) * (0.22 if focus_time > 0.0 else 1.0)
			walls[i]["center"] = LINE_Y + sin(float(walls[i]["clock"]) + float(walls[i]["phase"])) * float(walls[i]["amp"])
		if not bullet.is_empty():
			move_bullet(dt)
	update_particles(dt)
	queue_redraw()

func move_bullet(dt: float) -> void:
	var from_x: float = float(bullet["x"])
	var to_x: float = from_x + float(bullet["speed"]) * dt
	var bullet_y: float = float(bullet["y"])
	# Segment sweep: evita saltos a través de paredes delgadas a gran velocidad.
	for i in range(walls.size()):
		var wall: Dictionary = walls[i]
		if bool(wall["broken"]) or bullet["ignored"].has(i):
			continue
		var wx: float = float(wall["x"])
		if to_x + 5.0 < wx or from_x - 5.0 > wx + float(wall["w"]):
			continue
		var top: float = float(wall["center"]) - float(wall["gap"]) * 0.5
		var bottom: float = float(wall["center"]) + float(wall["gap"]) * 0.5
		if bullet_y - 5.0 < top or bullet_y + 5.0 > bottom:
			spawn_particles(Vector2(maxf(from_x, wx), bullet_y), Color("#ffbf81"), 12)
			if bool(wall["breakable"]):
				walls[i]["hp"] = int(wall["hp"]) - int(bullet["damage"])
				if int(walls[i]["hp"]) <= 0:
					walls[i]["broken"] = true
					notify("MURO DESTRUIDO")
			if int(bullet["pierce"]) > 0:
				bullet["pierce"] = int(bullet["pierce"]) - 1
				bullet["ignored"].append(i)
			else:
				bullet.clear()
				check_out_of_ammo()
				return
	bullet["x"] = to_x
	# El objetivo se mueve: solo hay impacto si el barrido de la bala intersecta su hitbox real.
	var hit: Rect2 = enemy_hitbox()
	var touches_x: bool = to_x + BULLET_RADIUS >= hit.position.x and from_x - BULLET_RADIUS <= hit.end.x
	var touches_y: bool = bullet_y + BULLET_RADIUS >= hit.position.y and bullet_y - BULLET_RADIUS <= hit.end.y
	if touches_x and touches_y:
		if shield_open:
			enemy_hp = maxi(0, enemy_hp - int(bullet["damage"]))
			if HURT_ANIMATIONS.has(level):
				hurt_time = 0.0
			spawn_particles(Vector2(maxf(from_x, hit.position.x), bullet_y), Color("#ffe39d"), 22)
			if enemy_hp <= 0:
				bullet.clear()
				if DEATH_ANIMATIONS.has(level):
					start_death()
				else:
					win_stage()
				return
		else:
			spawn_particles(Vector2(ENEMY_X - 75.0, bullet_y), Color("#87e4ff"), 10)
			notify("ESCUDO BLOQUEÓ EL DISPARO")
		bullet.clear()
		refresh_ui()
		check_out_of_ammo()
	elif to_x - BULLET_RADIUS > WIDTH:
		notify("EL ENEMIGO ESQUIVÓ LA BALA")
		bullet.clear()
		refresh_ui()
		check_out_of_ammo()

func enemy_hitbox() -> Rect2:
	var half: Vector2
	if ENEMY_TEXTURES[level - 1] != null:
		half = enemy_sprite_rect().size * 0.5 * SPRITE_HITBOX_FILL
	else:
		half = ENEMIES[level - 1]["hit"]
	return Rect2(Vector2(ENEMY_X, enemy_y) - half, half * 2.0)

# Los PNG traen márgenes transparentes: se usa solo el área opaca para dibujar y colisionar.
func sprite_region(tex: Texture2D) -> Rect2:
	if sprite_regions.has(tex):
		return sprite_regions[tex]
	var region := Rect2(Vector2.ZERO, tex.get_size())
	var image: Image = tex.get_image()
	if image != null and not image.is_empty():
		var used: Rect2i = image.get_used_rect()
		if used.has_area():
			region = Rect2(used)
	sprite_regions[tex] = region
	return region

func start_death() -> void:
	status = "dying"
	death_time = 0.0
	hurt_time = -1.0
	shield_open = true
	spawn_particles(Vector2(ENEMY_X, enemy_y), Color("#ff9a3c"), 40)
	spawn_particles(Vector2(ENEMY_X, enemy_y), Color("#ffe39d"), 20)
	refresh_ui()

# Fotograma de una animación tras "t" segundos, o -1 si está inactiva o ya terminó.
# Fotograma de una animación tras "t" segundos, o -1 si no existe, está inactiva o ya terminó.
func frame_at(anim: Variant, t: float) -> int:
	if anim == null or t < 0.0:
		return -1
	var frame: int = int(t * float(anim["fps"]))
	return frame if frame < (anim["src"] as Array).size() else -1

func hurt_frame() -> int:
	return frame_at(HURT_ANIMATIONS.get(level), hurt_time)

func death_frame() -> int:
	return frame_at(DEATH_ANIMATIONS.get(level), death_time)

func weapon_animation(kind: String) -> Variant:
	return WEAPON_ANIMATIONS.get(int(WEAPONS[equipped]["sprite"]), {}).get(kind)

func weapon_fire_frame() -> int:
	return frame_at(weapon_animation("fire"), fire_time)

# La recarga reparte sus fotogramas a lo largo de RELOAD_DURATION, al ritmo de la barra.
func weapon_reload_frame() -> int:
	var anim: Variant = weapon_animation("reload")
	if anim == null or reload_time <= 0.0:
		return -1
	var count: int = (anim["src"] as Array).size()
	return mini(count - 1, int((1.0 - reload_time / RELOAD_DURATION) * float(count)))

func draw_sheet_frame(anim: Dictionary, frame: int, target: Rect2) -> void:
	var tex: Texture2D = anim["texture"]
	var src: Rect2 = anim["src"][frame]
	var anchor: Rect2 = anim["anchors"][frame]
	# El ancla del fotograma ocupa el mismo rectángulo que el sprite base (target); el resto sobresale alrededor.
	var s: float = target.size.y / anchor.size.y
	var origin: Vector2 = target.get_center() - (anchor.get_center() - src.position) * s
	draw_texture_rect_region(tex, Rect2(origin, src.size * s), src)

func enemy_sprite_rect() -> Rect2:
	var region: Rect2 = sprite_region(ENEMY_TEXTURES[level - 1])
	var size: Vector2 = region.size * (ENEMY_SPRITE_BOX / maxf(region.size.x, region.size.y))
	return Rect2(Vector2(ENEMY_X, enemy_y) - size * 0.5, size)

func spawn_particles(origin: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		if particles.size() >= MAX_PARTICLES:
			particles.pop_front()
		var life: float = randf_range(0.35, 0.75)
		var velocity: Vector2 = Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(70.0, 260.0)
		particles.append({"pos":origin, "vel":velocity, "life":life, "max_life":life, "color":color})

func update_particles(dt: float) -> void:
	# Recorrido inverso: permite eliminar partículas expiradas sin saltar elementos.
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		var life: float = float(particle["life"]) - dt
		if life <= 0.0:
			particles.remove_at(i)
			continue
		var velocity: Vector2 = particle["vel"]
		velocity.y += PARTICLE_GRAVITY * dt
		particle["vel"] = velocity
		particle["pos"] = (particle["pos"] as Vector2) + velocity * dt
		particle["life"] = life

func check_out_of_ammo() -> void:
	if shots >= int(WEAPONS[equipped]["ammo"]) and reloads_left <= 0 and reload_time <= 0.0 and status == "play":
		lose_stage()
	elif shots >= int(WEAPONS[equipped]["ammo"]) and reloads_left > 0 and status == "play":
		reload_weapon()

func win_stage() -> void:
	status = "win"
	var threshold: int = int(WEAPONS[equipped]["ammo"])
	var earned_stars := 3 if shots <= int(ceil(float(threshold) * 0.32)) else (2 if shots <= int(ceil(float(threshold) * 0.66)) else 1)
	stars[str(level)] = max(int(stars.get(str(level), 0)), earned_stars)
	var award: int = 110 + level * 80 + max(0, threshold - shots) * 25 + (int(ENEMIES[level - 1]["hp"]) * 40)
	coins += award
	score += award
	unlocked = max(unlocked, min(5, level + 1))
	save_game()
	show_overlay("¡VICTORIA!", "Derrotaste a %s. Recompensa: %d monedas. Estrellas: %d/3" % [str(ENEMIES[level - 1]["name"]), award, earned_stars], "SIGUIENTE NIVEL" if level < 5 else "VOLVER AL NIVEL 1")
	overlay_start.pressed.disconnect(start_stage)
	overlay_start.pressed.connect(next_stage)
	refresh_ui()

func next_stage() -> void:
	if overlay_start.pressed.is_connected(next_stage):
		overlay_start.pressed.disconnect(next_stage)
	if not overlay_start.pressed.is_connected(start_stage):
		overlay_start.pressed.connect(start_stage)
	level = level + 1 if level < 5 else 1
	save_game()
	start_stage()

func lose_stage() -> void:
	status = "lose"
	show_overlay("GAME OVER", "Sin munición. Disparos: %d. Vida enemiga restante: %d/%d. ¡Inténtalo otra vez!" % [shots, enemy_hp, enemy_max_hp], "REINTENTAR")
	refresh_ui()

func notify(message: String) -> void:
	notice = message
	notice_time = 1.5

func _draw() -> void:
	var theme_color: Color = COLORS[level - 1]
	draw_rect(Rect2(0, 0, WIDTH, HEIGHT), theme_color)
	for i in range(10):
		var hx: float = float(i) * 120.0
		var h: float = float(60 + ((i * 31 + level * 23) % 120))
		draw_rect(Rect2(hx, HEIGHT - 45.0 - h, 65, h), Color(0.5, 0.7, 0.8, 0.13))
	draw_rect(Rect2(0, 425, WIDTH, 45), Color("#131a26"))
	draw_line(Vector2(115, LINE_Y), Vector2(900, LINE_Y), Color(0.8, 0.9, 1.0, 0.2), 2)
	var sprite_index: int = int(WEAPONS[equipped]["sprite"])
	var gun: Texture2D = PISTOL_TEXTURE if sprite_index == 0 else (SHOTGUN_TEXTURE if sprite_index == 1 else PLASMA_TEXTURE)
	var gun_region: Rect2 = sprite_region(gun)
	var gun_size: Vector2 = gun_region.size * (float(GUN_WIDTHS[sprite_index]) / gun_region.size.x)
	var gun_rect := Rect2(Vector2(35.0 - kick * 10.0, LINE_Y - gun_size.y * 0.5), gun_size)
	var reload_frame: int = weapon_reload_frame()
	var fire_frame: int = weapon_fire_frame()
	if reload_frame >= 0:
		draw_sheet_frame(weapon_animation("reload"), reload_frame, gun_rect)
	elif fire_frame >= 0:
		draw_sheet_frame(weapon_animation("fire"), fire_frame, gun_rect)
	else:
		draw_texture_rect_region(gun, gun_rect, gun_region)
	for wall in walls:
		if bool(wall["broken"]):
			continue
		var x: float = float(wall["x"])
		var width: float = float(wall["w"])
		var top: float = float(wall["center"]) - float(wall["gap"]) * 0.5
		var bottom: float = float(wall["center"]) + float(wall["gap"]) * 0.5
		draw_wall_rect(Rect2(x, 0, width, max(0.0, top)))
		draw_wall_rect(Rect2(x, bottom, width, max(0.0, HEIGHT - bottom)))
		draw_line(Vector2(x - 3, top), Vector2(x + width + 3, top), Color("#ffe0a4"), 3)
		draw_line(Vector2(x - 3, bottom), Vector2(x + width + 3, bottom), Color("#ffe0a4"), 3)
		if bool(wall["breakable"]):
			draw_rect(Rect2(x + 10, max(0, top - 15), 10, 10), Color("#ffb44c"))
	draw_enemy()
	if not bullet.is_empty():
		var x: float = float(bullet["x"])
		var y: float = float(bullet["y"])
		draw_circle(Vector2(x, y), BULLET_RADIUS, Color("#ffe9a0"))
		draw_line(Vector2(x - 18.0, y), Vector2(x - 7.0, y), Color("#ffd77c"), 3.0)
	for particle in particles:
		var tint: Color = particle["color"]
		tint.a = clampf(float(particle["life"]) / float(particle["max_life"]), 0.0, 1.0)
		draw_rect(Rect2((particle["pos"] as Vector2) - Vector2(2, 2), Vector2(4, 4)), tint)
	if reload_time > 0.0:
		draw_rect(Rect2(30, 392, 170, 14), Color("#253047"))
		draw_rect(Rect2(30, 392, 170 * (1.0 - reload_time / RELOAD_DURATION), 14), Color("#82ffa7"))
	if notice_time > 0.0 and notice != "":
		# Antes el aviso solo se volcaba al tooltip del HUD y nunca era visible.
		var alpha: float = clampf(notice_time / 0.4, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(0, 40), notice, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, 22, Color(1.0, 0.95, 0.75, alpha))

func draw_wall_rect(rect: Rect2) -> void:
	if rect.size.y <= 0.0:
		return
	# El sprite original es un mosaico 554x554: se repite de manera estable.
	draw_texture_rect_region(WALL_TEXTURE, rect, Rect2(0, 0, rect.size.x * 3.0, rect.size.y * 3.0), Color.WHITE)

func draw_enemy() -> void:
	var center := Vector2(916.0, enemy_y)
	if enemy_defeated:
		return
	if death_frame() >= 0:
		draw_sheet_frame(DEATH_ANIMATIONS[level], death_frame(), enemy_sprite_rect())
		return
	if ENEMY_TEXTURES[level - 1] != null:
		var tex: Texture2D = ENEMY_TEXTURES[level - 1]
		var frame: int = hurt_frame()
		if frame >= 0:
			draw_sheet_frame(HURT_ANIMATIONS[level], frame, enemy_sprite_rect())
		else:
			draw_texture_rect_region(tex, enemy_sprite_rect(), sprite_region(tex))
	else:
		draw_circle(center, 62, Color("#f4edf1"))
		for r in [48.0, 33.0, 18.0, 7.0]:
			draw_arc(center, r, 0, TAU, 48, Color("#a33d4b") if int(r) % 2 == 0 else Color("#f8f1dc"), 8)
	if not shield_open:
		draw_arc(center, 75, 0, TAU, 60, Color("#87e4ff"), 5.0)
	if enemy_max_hp > 1:
		var ratio: float = float(enemy_hp) / float(enemy_max_hp)
		draw_rect(Rect2(853, 118, 125, 10), Color("#182336"))
		draw_rect(Rect2(853, 118, 125 * ratio, 10), Color("#f48979"))

func save_game() -> void:
	var payload := {"version":1, "coins":coins, "score":score, "level":level, "unlocked":unlocked, "owned":owned, "equipped":equipped, "stars":stars}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	coins = maxi(0, int(data.get("coins", 0)))
	score = maxi(0, int(data.get("score", 0)))
	unlocked = clampi(int(data.get("unlocked", 1)), 1, 5)
	level = clampi(int(data.get("level", 1)), 1, unlocked)
	var items: Variant = data.get("owned", [0])
	if typeof(items) == TYPE_ARRAY:
		owned = [0]
		for item in items:
			if int(item) >= 0 and int(item) < WEAPONS.size() and not owned.has(int(item)):
				owned.append(int(item))
	equipped = int(data.get("equipped", 0))
	if not owned.has(equipped):
		equipped = 0
	var ratings: Variant = data.get("stars", {})
	if typeof(ratings) == TYPE_DICTIONARY:
		stars = ratings
