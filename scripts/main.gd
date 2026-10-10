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
# Fichas de las etapas (enemigo, muros y ambientación); "level" es el índice 1.. de STAGES.
const STAGE_DATA := preload("res://scripts/stages.gd")
const STAGES: Array = STAGE_DATA.LIST
const WORLDS: Array = STAGE_DATA.WORLDS # mapa: etapas agrupadas por mundo
const WorldMap := preload("res://scripts/world_map.gd")
const WALL_WIDTH := 31.0
const ENEMY_SPRITE_BOX := 130.0
const SPRITE_HITBOX_FILL := 0.85
# Ancho en pantalla de cada sprite de arma (índice "sprite" de WEAPONS).
const GUN_WIDTHS := [111.0, 152.0, 140.0]
const RELOAD_DURATION := 1.1
# Efectos de sonido (generados con tools/sfx.py; se pueden reemplazar por otros .wav con el mismo nombre).
# "db" compensa los sonidos de onda cuadrada sostenida, que suenan más fuertes que el resto.
const SFX := {
	"shot_pistol": {"stream":preload("res://assets/sfx/shot_pistol.wav"), "db":0.0},
	"shot_rifle": {"stream":preload("res://assets/sfx/shot_rifle.wav"), "db":0.0},
	"shot_plasma": {"stream":preload("res://assets/sfx/shot_plasma.wav"), "db":-1.0},
	"wall_hit": {"stream":preload("res://assets/sfx/wall_hit.wav"), "db":-2.0},
	"wall_break": {"stream":preload("res://assets/sfx/wall_break.wav"), "db":0.0},
	"enemy_hit": {"stream":preload("res://assets/sfx/enemy_hit.wav"), "db":-1.0},
	"shield": {"stream":preload("res://assets/sfx/shield.wav"), "db":-2.0},
	"explosion": {"stream":preload("res://assets/sfx/explosion.wav"), "db":0.0},
	"reload": {"stream":preload("res://assets/sfx/reload.wav"), "db":0.0},
	"reload_done": {"stream":preload("res://assets/sfx/reload_done.wav"), "db":-3.0},
	"ability": {"stream":preload("res://assets/sfx/ability.wav"), "db":-7.0},
	"buy": {"stream":preload("res://assets/sfx/buy.wav"), "db":-5.0},
	"victory": {"stream":preload("res://assets/sfx/victory.wav"), "db":-6.0},
	"game_over": {"stream":preload("res://assets/sfx/game_over.wav"), "db":-3.0}
}
const SHOT_SOUNDS := ["shot_pistol", "shot_rifle", "shot_plasma"] # por índice "sprite" de WEAPONS
# Música (assets/music/). "db" iguala el volumen entre temas; "xfade" son los segundos de fundido cruzado
# con que el tema vuelve a empezar antes de su final (los temas acaban con un desvanecimiento);
# 0 = se reproduce una sola vez.
const MUSIC := {
	"menu": {"stream":preload("res://assets/music/principal_menu.mp3"), "db":-1.0, "xfade":4.0},
	"briefing": {"stream":preload("res://assets/music/boss_presentation.mp3"), "db":-2.0, "xfade":1.0},
	"levels_a": {"stream":preload("res://assets/music/levels_to_1_at_3.mp3"), "db":0.0, "xfade":1.0},
	"levels_b": {"stream":preload("res://assets/music/levels_to_4_at_5.mp3"), "db":2.0, "xfade":1.0},
	"boss": {"stream":preload("res://assets/music/final_boss.mp3"), "db":1.0, "xfade":1.5},
	"victory": {"stream":preload("res://assets/music/victory.mp3"), "db":2.0, "xfade":0.0},
	"game_over": {"stream":preload("res://assets/music/game_over.mp3"), "db":-1.0, "xfade":0.0}
}
const MUSIC_DB := -9.0 # la música queda por debajo de los efectos
const MUSIC_FADE := 0.6 # fundido al cambiar de tema
const SILENT_DB := -60.0
const SFX_VOICES := 8
# Sensación de impacto: congelación breve del juego (hit-stop, s) y sacudida del escenario (px).
const HITSTOP_ENEMY := 0.06
const HITSTOP_WALL_BREAK := 0.04
const HITSTOP_DEATH := 0.12
const SHAKE_ENEMY := 5.0
const SHAKE_WALL_BREAK := 4.0
const SHAKE_DEATH := 11.0
const SHAKE_DECAY := 40.0 # px/s
const SHAKE_MAX := 8.0 # desplazamiento máximo real; el fondo se dibuja con este margen extra
# Interfaz estilo Guerra Fría: piezas recortadas y reducidas por tools/ui_slice.py desde assets/interface/.
const UI_TEX := {
	"button_normal": preload("res://assets/interface/game/button_normal.png"),
	"button_hover": preload("res://assets/interface/game/button_hover.png"),
	"button_pressed": preload("res://assets/interface/game/button_pressed.png"),
	"button_disabled": preload("res://assets/interface/game/button_disabled.png"),
	"panel_large": preload("res://assets/interface/game/panel_large.png"),
	"panel_small": preload("res://assets/interface/game/panel_small.png"),
	"hud_bar": preload("res://assets/interface/game/hud_bar.png"),
	"title": preload("res://assets/interface/game/title.png"),
	"menu_bg": preload("res://assets/interface/game/menu_bg.png"),
	"dossier": preload("res://assets/interface/game/dossier.png"),
	"bullet_full": preload("res://assets/interface/game/bullet_full.png"),
	"bullet_spent": preload("res://assets/interface/game/bullet_spent.png"),
	"bullet_silver": preload("res://assets/interface/game/bullet_silver.png"),
	"reticle_tl": preload("res://assets/interface/game/reticle_tl.png"),
	"reticle_tr": preload("res://assets/interface/game/reticle_tr.png"),
	"reticle_bl": preload("res://assets/interface/game/reticle_bl.png"),
	"reticle_br": preload("res://assets/interface/game/reticle_br.png")
}
# Medallas por estrellas obtenidas: 1 bronce, 2 plata, 3 oro.
const MEDALS := [preload("res://assets/interface/game/medal_bronze.png"), preload("res://assets/interface/game/medal_silver.png"), preload("res://assets/interface/game/medal_gold.png")]
const MEDALS_SMALL := [preload("res://assets/interface/game/medal_bronze_small.png"), preload("res://assets/interface/game/medal_silver_small.png"), preload("res://assets/interface/game/medal_gold_small.png")]
const MAX_AMMO_SLOTS := 14 # munición máxima entre todas las armas
const MAX_RELOAD_SLOTS := 2
const HUD_GREEN := Color("#9dff6a")
# Expediente "CLASIFICADO" previo a cada nivel. Zonas en píxeles de dossier.png (640x466).
const DOSSIER_POS := Vector2(180, 2)
const DOSSIER_TAB := Rect2(137, 20, 143, 23)
const DOSSIER_PHOTO := Rect2(61, 111, 203, 224)
const DOSSIER_NAME := Rect2(287, 183, 300, 32)
const DOSSIER_THREAT := Rect2(454, 224, 131, 18)
const DOSSIER_NOTES := Rect2(290, 284, 305, 92)
const DOSSIER_FOOTER := Rect2(151, 407, 339, 40)
const DOSSIER_INK := Color("#2b2414")
const MAX_THREAT := 5 # franjas que caben en la barra de amenaza del expediente
const TYPE_SPEED := 45.0 # caracteres por segundo del efecto máquina de escribir
const MOTION_NAMES := ["posición fija", "desplazamiento vertical", "patrulla lenta"]
const SHIELD_NAMES := ["ninguno", "intermitente", "alta frecuencia"]
# Animaciones de arma por índice "sprite" de WEAPONS (mismo formato que "hurt" en scripts/stages.gd).
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
var shots := 0 # balas gastadas del cargador actual (vuelve a 0 al recargar)
var total_shots := 0 # balas disparadas en todo el nivel: medallas, recompensa y Game Over
var reloads_left := 1
var reload_time := 0.0
var elapsed := 0.0
var focus_time := 0.0
var pierce_next := 0
var abilities_left := 2
var kick := 0.0
var status := "menu" # menu / map / briefing / play / dying / lose / win
var enemy_hp := 1
var enemy_max_hp := 1
var enemy_y := LINE_Y
var shield_open := true
var notice := ""
var notice_time := 0.0
var fire_button: Button
var reload_button: Button
var ability_button: Button
var restart_button: Button
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
var sound_button: Button
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_next := 0
var last_sfx := "" # último efecto pedido (útil para depurar y para las pruebas)
var hitstop_time := 0.0
var shake := 0.0
var music_players: Array[AudioStreamPlayer] = [] # dos reproductores que se alternan para los fundidos
var music_active := 0 # índice del reproductor que suena ahora
var music_track := "" # tema actual ("" = ninguno)
var music_looping := false # true mientras se hace el fundido cruzado de vuelta al inicio
var quitting := false
var overlay_logo: TextureRect
var overlay_medals: Array[TextureRect] = []
var ammo_slots: Array[TextureRect] = []
var reload_slots: Array[TextureRect] = []
var dossier: Control
var world_map: Control # mapa del mundo (scripts/world_map.gd)
var combat_ui: Array[Control] = [] # controles bajo el escenario; el mapa (pantalla completa) los oculta
var briefed_level := 0 # último nivel cuyo expediente ya se mostró (0 = ninguno)
var briefing_time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	get_tree().auto_accept_quit = false # el cierre de ventana pasa por quit_cleanly()
	# draw_wall_rect() muestrea una región mayor que la textura del muro: necesita repetición.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	load_game()
	for i in range(SFX_VOICES):
		var player := AudioStreamPlayer.new()
		add_child(player)
		sfx_players.append(player)
	for i in range(2):
		var player := AudioStreamPlayer.new()
		add_child(player)
		music_players.append(player)
	theme = build_theme()
	build_ui()
	reset_stage()
	show_overlay("", "Atraviesa los muros móviles y vence a todos los objetivos.", "JUGAR", false)
	set_process(true)

# Tema común de la interfaz: botones metálicos con letras doradas y paneles de chapa (9-slice).
func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	var states := {"normal":"button_normal", "hover":"button_hover", "pressed":"button_pressed", "hover_pressed":"button_pressed", "disabled":"button_disabled"}
	for type_name in ["Button", "OptionButton"]:
		for state in states:
			t.set_stylebox(state, type_name, ui_box(UI_TEX[states[state]], Vector2(22, 15), Vector2(18, 8)))
		t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
		t.set_color("font_color", type_name, Color("#f7c22f"))
		t.set_color("font_hover_color", type_name, Color("#ffe27a"))
		t.set_color("font_pressed_color", type_name, Color("#ff9d2e"))
		t.set_color("font_hover_pressed_color", type_name, Color("#ff9d2e"))
		t.set_color("font_disabled_color", type_name, Color("#9a9a8c"))
		t.set_color("font_outline_color", type_name, Color("#1a1205"))
		t.set_constant("outline_size", type_name, 4)
	t.set_stylebox("panel", "PanelContainer", ui_box(UI_TEX["panel_large"], Vector2(48, 34), Vector2(44, 30)))
	t.set_color("font_color", "Label", Color("#2a2b1d"))
	return t

# StyleBoxTexture 9-slice: "margin" son los bordes fijos de la textura y "content" el relleno interior.
func ui_box(tex: Texture2D, margin: Vector2, content: Vector2) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = margin.x
	box.texture_margin_right = margin.x
	box.texture_margin_top = margin.y
	box.texture_margin_bottom = margin.y
	box.content_margin_left = content.x
	box.content_margin_right = content.x
	box.content_margin_top = content.y
	box.content_margin_bottom = content.y
	return box

# Cierre ordenado: si el juego sale con música sonando, el servidor de audio aún retiene la
# reproducción y Godot avisa de recursos sin liberar. Se detiene el audio, se espera a que el
# servidor de audio la suelte (0,15 s; unos fotogramas no bastan con MP3) y entonces se sale.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_cleanly()

func quit_cleanly() -> void:
	quitting = true # evita que update_music() vuelva a arrancar el tema mientras se espera
	stop_music()
	for player in sfx_players + music_players:
		player.stop()
		player.stream = null
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func build_ui() -> void:
	# Chapa de fondo de toda la zona de controles, bajo el escenario.
	var backdrop := Panel.new()
	backdrop.position = Vector2(0, HEIGHT)
	backdrop.size = Vector2(WIDTH, 650.0 - HEIGHT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_theme_stylebox_override("panel", ui_box(UI_TEX["panel_small"], Vector2(40, 22), Vector2.ZERO))
	add_child(backdrop)
	combat_ui.append(backdrop)
	var bar := HBoxContainer.new()
	bar.position = Vector2(28, 482)
	bar.size = Vector2(944, 45)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	combat_ui.append(bar)
	fire_button = make_button("DISPARAR", Callable(self, "fire"), bar)
	reload_button = make_button("RECARGAR (R)", Callable(self, "reload_weapon"), bar)
	ability_button = make_button("HABILIDAD (E)", Callable(self, "special"), bar)
	restart_button = make_button("REINICIAR", Callable(self, "start_stage"), bar)
	make_button("MAPA", Callable(self, "open_map"), bar)
	# HUD en pantalla de fósforo: balas del cargador, cargadores de reserva y datos de la partida.
	var hud_panel := PanelContainer.new()
	hud_panel.position = Vector2(28, 532)
	hud_panel.size = Vector2(944, 44)
	hud_panel.add_theme_stylebox_override("panel", ui_box(UI_TEX["hud_bar"], Vector2(24, 13), Vector2(22, 6)))
	add_child(hud_panel)
	combat_ui.append(hud_panel)
	var hud_row := HBoxContainer.new()
	hud_row.add_theme_constant_override("separation", 14)
	hud_panel.add_child(hud_row)
	var ammo_row := HBoxContainer.new()
	ammo_row.add_theme_constant_override("separation", 3)
	hud_row.add_child(ammo_row)
	for i in range(MAX_AMMO_SLOTS):
		ammo_slots.append(make_icon(UI_TEX["bullet_full"], ammo_row))
	var reload_row := HBoxContainer.new()
	reload_row.add_theme_constant_override("separation", 3)
	hud_row.add_child(reload_row)
	for i in range(MAX_RELOAD_SLOTS):
		reload_slots.append(make_icon(UI_TEX["bullet_silver"], reload_row))
	hud = Label.new()
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_theme_color_override("font_color", HUD_GREEN)
	hud_row.add_child(hud)
	var selectors := HBoxContainer.new()
	selectors.position = Vector2(44, 582)
	selectors.size = Vector2(912, 45)
	selectors.add_theme_constant_override("separation", 12)
	add_child(selectors)
	combat_ui.append(selectors)
	var weapons_label := Label.new()
	weapons_label.text = "ARSENAL"
	selectors.add_child(weapons_label)
	weapon_box = OptionButton.new()
	weapon_box.custom_minimum_size = Vector2(300, 45)
	weapon_box.focus_mode = Control.FOCUS_NONE
	selectors.add_child(weapon_box)
	weapon_box.item_selected.connect(choose_weapon)
	var levels_label := Label.new()
	levels_label.text = "NIVEL"
	selectors.add_child(levels_label)
	level_box = OptionButton.new()
	level_box.custom_minimum_size = Vector2(210, 45)
	level_box.focus_mode = Control.FOCUS_NONE
	selectors.add_child(level_box)
	level_box.item_selected.connect(choose_level)
	sound_button = make_button("", Callable(self, "toggle_sound"), selectors)
	# Mapa del mundo sobre el escenario; los clics y teclas le llegan desde _unhandled_input.
	world_map = WorldMap.new()
	world_map.position = Vector2.ZERO
	world_map.size = Vector2(WIDTH, 650.0) # pantalla completa: imagen del mundo + panel
	world_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_map.medal_icons = MEDALS_SMALL
	world_map.medal_large = MEDALS
	world_map.panel_box = ui_box(UI_TEX["panel_large"], Vector2(48, 34), Vector2(44, 30))
	world_map.stage_chosen.connect(enter_stage)
	world_map.menu_requested.connect(go_menu)
	world_map.hide()
	add_child(world_map)
	overlay_panel = PanelContainer.new()
	overlay_panel.position = Vector2(210, 50)
	overlay_panel.size = Vector2(580, 315)
	add_child(overlay_panel)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 12)
	overlay_panel.add_child(layout)
	overlay_logo = TextureRect.new()
	overlay_logo.texture = UI_TEX["title"]
	overlay_logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	layout.add_child(overlay_logo)
	overlay_title = Label.new()
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 33)
	layout.add_child(overlay_title)
	var medal_row := HBoxContainer.new()
	medal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	medal_row.add_theme_constant_override("separation", 18)
	layout.add_child(medal_row)
	for tex in MEDALS:
		overlay_medals.append(make_icon(tex, medal_row))
	overlay_message = Label.new()
	overlay_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_message.custom_minimum_size = Vector2(480, 60)
	layout.add_child(overlay_message)
	overlay_start = make_button("JUGAR", Callable(self, "on_overlay_start"), layout, true)
	overlay_menu = make_button("VOLVER AL MAPA", Callable(self, "open_map"), layout, true)
	for button in [overlay_start, overlay_menu]:
		button.custom_minimum_size = Vector2(260, 45)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Expediente: se dibuja en draw_dossier(); ignora el ratón para que el clic llegue a _unhandled_input.
	dossier = Control.new()
	dossier.position = DOSSIER_POS
	dossier.size = UI_TEX["dossier"].get_size()
	dossier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dossier.draw.connect(draw_dossier)
	dossier.hide()
	add_child(dossier)
	refresh_ui()

func make_icon(tex: Texture2D, parent: Node) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = tex
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func make_button(label: String, fn: Callable, parent: Node, focusable: bool = false) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(112, 45)
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
	# Balas restantes llenas y gastadas a continuación; cargadores de reserva como balas plateadas.
	for i in range(ammo_slots.size()):
		ammo_slots[i].visible = i < int(weapon["ammo"])
		ammo_slots[i].texture = UI_TEX["bullet_full"] if i < ammo_left else UI_TEX["bullet_spent"]
	for i in range(reload_slots.size()):
		reload_slots[i].visible = i < reloads_left
	hud.text = "NIVEL %d/%d  MONEDAS %d  PUNTOS %d  HAB %d  ENEMIGO %d/%d" % [level, STAGES.size(), coins, score, abilities_left, enemy_hp, enemy_max_hp]
	fire_button.disabled = status != "play" or not bullet.is_empty() or reload_time > 0.0
	reload_button.disabled = status != "play" or reload_time > 0.0 or reloads_left <= 0 or not bullet.is_empty()
	ability_button.disabled = status != "play" or abilities_left <= 0 or weapon["ability"] == "none" or not bullet.is_empty()
	# Fuera de una etapa no hay nada que reiniciar (en el mapa se entra eligiendo un punto).
	restart_button.disabled = status == "menu" or status == "map"
	weapon_box.clear()
	for i in range(WEAPONS.size()):
		var info: Dictionary = WEAPONS[i]
		var label: String = str(info["name"])
		if not owned.has(i):
			label += " — COMPRAR %d monedas" % int(info["price"])
		weapon_box.add_item(label, i)
	weapon_box.select(equipped)
	level_box.clear()
	for i in range(1, STAGES.size() + 1):
		# Medalla según la mejor puntuación en estrellas del nivel (antes era un emoji que podía no verse).
		var best: int = clampi(int(stars.get(str(STAGES[i - 1]["id"]), 0)), 0, 3)
		var label: String = "Nivel %d" % i + (" (bloqueado)" if i > unlocked else "")
		if best > 0:
			level_box.add_icon_item(MEDALS_SMALL[best - 1], label, i)
		else:
			level_box.add_item(label, i)
		level_box.set_item_disabled(i - 1, i > unlocked)
	level_box.select(level - 1)
	sound_button.text = "SONIDO (M): " + ("SÍ" if sound_enabled else "NO")

func reset_stage() -> void:
	walls.clear()
	particles.clear()
	bullet.clear()
	shots = 0
	total_shots = 0
	reloads_left = int(stage()["reloads"])
	reload_time = 0.0
	elapsed = 0.0
	focus_time = 0.0
	pierce_next = 0
	abilities_left = 0 if WEAPONS[equipped]["ability"] == "none" else 2
	enemy_hp = int(stage()["hp"])
	enemy_max_hp = enemy_hp
	hurt_time = -1.0
	death_time = -1.0
	enemy_defeated = false
	fire_time = -1.0
	hitstop_time = 0.0
	shake = 0.0
	enemy_y = LINE_Y
	shield_open = true
	for def in stage()["walls"]:
		walls.append({"x":float(def["x"]), "w":WALL_WIDTH, "center":LINE_Y, "phase":float(def["phase"]), "clock":0.0, "speed":float(def["speed"]), "amp":float(def["amp"]), "gap":float(def["gap"]), "hp":int(def["hp"]), "breakable":bool(def["breakable"]), "broken":false})
	refresh_ui()
	queue_redraw()

# Ficha de la etapa actual (scripts/stages.gd).
func stage() -> Dictionary:
	return STAGES[level - 1]

func start_stage() -> void:
	overlay_panel.hide()
	world_map.hide()
	set_combat_ui(true)
	# Nivel nuevo (o recién llegado del menú): primero el expediente del objetivo. Reintentar no lo repite.
	if level != briefed_level:
		status = "briefing"
		reset_stage()
		briefing_time = 0.0
		dossier.show()
		dossier.queue_redraw()
		return
	status = "play"
	reset_stage()

func begin_stage() -> void:
	if status != "briefing":
		return
	briefed_level = level
	dossier.hide()
	status = "play"
	refresh_ui()

# Primer clic: completa el texto que se está escribiendo; segundo clic: empieza el nivel.
func advance_briefing() -> void:
	if briefing_chars() < dossier_total_chars():
		briefing_time = float(dossier_total_chars()) / TYPE_SPEED
		dossier.queue_redraw()
	else:
		begin_stage()

func go_menu() -> void:
	status = "menu"
	briefed_level = 0
	dossier.hide()
	world_map.hide()
	set_combat_ui(true)
	reset_stage()
	show_overlay("", "Recorre el mapa y elige tu arma. Gana monedas para desbloquear el arsenal.", "JUGAR", false)

# Mapa del mundo de la etapa actual, con el agente sobre ella.
func open_map() -> void:
	status = "map"
	overlay_panel.hide()
	dossier.hide()
	reset_stage()
	world_map.open(world_of(level), STAGES, unlocked, stars, level, coins)
	set_combat_ui(false)

func set_combat_ui(shown: bool) -> void:
	for control in combat_ui:
		control.visible = shown

func world_of(stage_level: int) -> Dictionary:
	for world in WORLDS:
		for node in world["nodes"]:
			if int(node["stage"]) == stage_level:
				return world
	return WORLDS[0]

# Etapa elegida en el mapa: pasa por el expediente si no se ha visto.
func enter_stage(stage_level: int) -> void:
	level = stage_level
	save_game()
	start_stage()

# Botón principal del panel: JUGAR (menú) y CONTINUAR (victoria) llevan al mapa; REINTENTAR repite la etapa.
func on_overlay_start() -> void:
	if status == "menu" or status == "win":
		open_map()
	else:
		start_stage()

func show_overlay(title: String, message: String, button_text: String, show_menu: bool = true) -> void:
	overlay_panel.show()
	overlay_title.text = title
	overlay_message.text = message
	overlay_start.text = button_text
	overlay_menu.visible = show_menu
	# En el menú: placa WALLSHOT sobre el fondo del búnker, sin chapa de panel y con texto claro.
	var in_menu: bool = status == "menu"
	overlay_logo.visible = in_menu
	overlay_title.visible = not in_menu
	for medal in overlay_medals:
		medal.get_parent().visible = false
	if in_menu:
		overlay_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		overlay_message.add_theme_color_override("font_color", Color("#f2e6c8"))
		overlay_message.add_theme_color_override("font_outline_color", Color("#14120a"))
		overlay_message.add_theme_constant_override("outline_size", 5)
	else:
		overlay_panel.remove_theme_stylebox_override("panel")
		overlay_message.remove_theme_color_override("font_color")
		overlay_message.remove_theme_color_override("font_outline_color")
		overlay_message.remove_theme_constant_override("outline_size")
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
		play_sfx("buy")
	equipped = index
	# Equipar está permitido entre partidas; en plena partida reiniciamos el nivel para evitar recargas gratuitas.
	# En el expediente también: la munición y las habilidades del nivel dependen del arma.
	if status == "play" or status == "briefing":
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
	total_shots += 1
	bullet = {"x":125.0, "y":LINE_Y, "speed":float(w["speed"]), "damage":int(w["damage"]), "pierce":pierce_next, "ignored":[]}
	pierce_next = 0
	kick = 1.0
	fire_time = 0.0
	play_sfx(SHOT_SOUNDS[int(w["sprite"])])
	refresh_ui()

func reload_weapon() -> void:
	if status != "play" or reload_time > 0.0 or reloads_left <= 0 or not bullet.is_empty():
		return
	reloads_left -= 1
	reload_time = RELOAD_DURATION
	play_sfx("reload")
	notify("RECARGANDO...")
	refresh_ui()

func special() -> void:
	if status != "play" or not bullet.is_empty() or abilities_left <= 0 or reload_time > 0.0:
		return
	var ability: String = str(WEAPONS[equipped]["ability"])
	if ability == "none":
		return
	abilities_left -= 1
	play_sfx("ability")
	if ability == "slow":
		focus_time = 3.0
		notify("TIEMPO LENTO")
	else:
		pierce_next = 2 if ability == "double_pierce" else 1
		notify("PERFORACIÓN PREPARADA")
	refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if status == "map":
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
			toggle_sound()
		else:
			world_map.handle_input(event)
		return
	if status == "briefing":
		var key_go: bool = event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)
		var click_go: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		if key_go or click_go:
			advance_briefing()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			fire()
		elif event.keycode == KEY_R:
			reload_weapon()
		elif event.keycode == KEY_E:
			special()
		elif event.keycode == KEY_M:
			toggle_sound()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.position.y < HEIGHT:
		fire()

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.033)
	update_music() # antes del hit-stop: la música no se congela
	if status == "briefing":
		briefing_time += dt
		dossier.queue_redraw()
	shake = maxf(0.0, shake - dt * SHAKE_DECAY)
	if hitstop_time > 0.0:
		# Hit-stop: todo se congela unos fotogramas para que el impacto se sienta; la sacudida sigue.
		hitstop_time = maxf(0.0, hitstop_time - dt)
		queue_redraw()
		return
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
			play_sfx("reload_done")
			notify("RECARGA COMPLETA")
			refresh_ui()
	if status == "play":
		elapsed += dt
		focus_time = maxf(0.0, focus_time - dt)
		var profile: Dictionary = stage()
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
			var broke := false
			if bool(wall["breakable"]):
				walls[i]["hp"] = int(wall["hp"]) - int(bullet["damage"])
				if int(walls[i]["hp"]) <= 0:
					walls[i]["broken"] = true
					broke = true
					notify("MURO DESTRUIDO")
			if broke:
				play_sfx("wall_break")
				impact(HITSTOP_WALL_BREAK, SHAKE_WALL_BREAK)
			else:
				play_sfx("wall_hit")
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
			if stage()["hurt"] != null:
				hurt_time = 0.0
			spawn_particles(Vector2(maxf(from_x, hit.position.x), bullet_y), Color("#ffe39d"), 22)
			if enemy_hp > 0:
				play_sfx("enemy_hit")
				impact(HITSTOP_ENEMY, SHAKE_ENEMY)
			if enemy_hp <= 0:
				bullet.clear()
				if stage()["death"] != null:
					start_death()
				else:
					win_stage()
				return
		else:
			spawn_particles(Vector2(ENEMY_X - 75.0, bullet_y), Color("#87e4ff"), 10)
			play_sfx("shield")
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
	if stage()["texture"] != null:
		half = enemy_sprite_rect().size * 0.5 * SPRITE_HITBOX_FILL
	else:
		half = stage()["hit"]
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
	play_sfx("explosion")
	impact(HITSTOP_DEATH, SHAKE_DEATH)
	refresh_ui()

func impact(hitstop: float, shake_px: float) -> void:
	hitstop_time = maxf(hitstop_time, hitstop)
	shake = maxf(shake, shake_px)

func play_sfx(sound: String) -> void:
	last_sfx = sound
	if not sound_enabled or sfx_players.is_empty():
		return
	# Varias voces para que los sonidos se solapen sin cortarse; una leve variación de tono evita la monotonía.
	var player: AudioStreamPlayer = sfx_players[sfx_next]
	sfx_next = (sfx_next + 1) % sfx_players.size()
	player.stream = SFX[sound]["stream"]
	player.volume_db = float(SFX[sound]["db"])
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()

func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	if not sound_enabled:
		for player in sfx_players:
			player.stop()
		stop_music()
	save_game()
	refresh_ui()

# Tema que corresponde al estado actual del juego.
func desired_music() -> String:
	match status:
		"menu", "map":
			return "menu" # provisional: el mapa usa el tema del menú hasta tener uno propio
		"briefing":
			return "briefing"
		"play", "dying":
			return str(stage()["music"])
		"win":
			return "victory"
		"lose":
			return "game_over"
	return ""

func update_music() -> void:
	if not sound_enabled or quitting or music_players.is_empty():
		return
	var wanted: String = desired_music()
	if wanted != music_track:
		play_music(wanted)
		return
	if music_track == "" or music_looping:
		return
	# Bucle con fundido cruzado: el tema vuelve a empezar "xfade" segundos antes de acabar.
	var xfade: float = float(MUSIC[music_track]["xfade"])
	var current: AudioStreamPlayer = music_players[music_active]
	if xfade > 0.0 and current.playing and current.get_playback_position() >= current.stream.get_length() - xfade:
		music_looping = true
		crossfade_to(music_track, xfade)

func play_music(track: String) -> void:
	music_track = track
	music_looping = false
	if track == "":
		fade_out(music_players[music_active], MUSIC_FADE)
		return
	crossfade_to(track, MUSIC_FADE)

# Arranca "track" desde el principio en el reproductor libre y funde con el que sonaba.
func crossfade_to(track: String, duration: float) -> void:
	var old: AudioStreamPlayer = music_players[music_active]
	music_active = 1 - music_active
	var player: AudioStreamPlayer = music_players[music_active]
	player.stream = MUSIC[track]["stream"]
	player.volume_db = SILENT_DB
	player.play()
	var tween := music_tween(player)
	tween.tween_property(player, "volume_db", MUSIC_DB + float(MUSIC[track]["db"]), duration)
	tween.tween_callback(func(): music_looping = false)
	if old.playing:
		fade_out(old, duration)

func fade_out(player: AudioStreamPlayer, duration: float) -> void:
	var tween := music_tween(player)
	tween.tween_property(player, "volume_db", SILENT_DB, duration)
	tween.tween_callback(player.stop)

# Un solo fundido activo por reproductor: si se cambia de tema rápido, el fundido de salida
# anterior no debe apagar el tema nuevo que ahora suena en ese mismo reproductor.
func music_tween(player: AudioStreamPlayer) -> Tween:
	if player.has_meta("tween"):
		var previous: Tween = player.get_meta("tween")
		if previous != null and previous.is_valid():
			previous.kill()
	var tween := create_tween()
	player.set_meta("tween", tween)
	return tween

func stop_music() -> void:
	for player in music_players:
		if player.has_meta("tween"):
			var previous: Tween = player.get_meta("tween")
			if previous != null and previous.is_valid():
				previous.kill()
		player.stop()
	music_track = ""
	music_looping = false

# Fotograma de una animación tras "t" segundos, o -1 si no existe, está inactiva o ya terminó.
func frame_at(anim: Variant, t: float) -> int:
	if anim == null or t < 0.0:
		return -1
	var frame: int = int(t * float(anim["fps"]))
	return frame if frame < (anim["src"] as Array).size() else -1

func hurt_frame() -> int:
	return frame_at(stage()["hurt"], hurt_time)

func death_frame() -> int:
	return frame_at(stage()["death"], death_time)

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
	var region: Rect2 = sprite_region(stage()["texture"])
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
	play_sfx("victory")
	var threshold: int = int(WEAPONS[equipped]["ammo"])
	var earned_stars := 3 if total_shots <= int(ceil(float(threshold) * 0.32)) else (2 if total_shots <= int(ceil(float(threshold) * 0.66)) else 1)
	var key: String = str(stage()["id"])
	stars[key] = max(int(stars.get(key, 0)), earned_stars)
	var award: int = 110 + level * 80 + max(0, threshold - total_shots) * 25 + (int(stage()["hp"]) * 40)
	coins += award
	score += award
	unlocked = max(unlocked, mini(STAGES.size(), level + 1))
	save_game()
	# CONTINUAR vuelve al mapa, con el camino a la siguiente etapa ya abierto.
	show_overlay("¡VICTORIA!", "Derrotaste a %s. Recompensa: %d monedas." % [str(stage()["name"]), award], "CONTINUAR", false)
	# Medallas: bronce, plata y oro; las no conseguidas se ven apagadas.
	overlay_medals[0].get_parent().visible = true
	for i in range(overlay_medals.size()):
		overlay_medals[i].modulate = Color.WHITE if i < earned_stars else Color(0.25, 0.25, 0.25, 0.7)
	refresh_ui()

func lose_stage() -> void:
	status = "lose"
	play_sfx("game_over")
	show_overlay("GAME OVER", "Sin munición. Disparos: %d. Vida enemiga restante: %d/%d. ¡Inténtalo otra vez!" % [total_shots, enemy_hp, enemy_max_hp], "REINTENTAR")
	refresh_ui()

func notify(message: String) -> void:
	notice = message
	notice_time = 1.5

func _draw() -> void:
	# Sacudida: solo el escenario se desplaza (los controles de UI son nodos hijos y no se ven afectados).
	# El fondo y el suelo se extienden SHAKE_MAX px para que no aparezcan bordes vacíos.
	if status == "map":
		return # el mapa (world_map) se dibuja a sí mismo encima
	var offset := Vector2.ZERO
	if shake > 0.0:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * minf(shake, SHAKE_MAX)
	draw_set_transform(offset)
	if status == "menu":
		draw_texture(UI_TEX["menu_bg"], Vector2.ZERO) # búnker de mando con el mapa
		draw_set_transform(Vector2.ZERO)
		return
	var theme_color: Color = stage()["color"]
	draw_rect(Rect2(-SHAKE_MAX, -SHAKE_MAX, WIDTH + SHAKE_MAX * 2.0, HEIGHT + SHAKE_MAX), theme_color)
	for i in range(10):
		var hx: float = float(i) * 120.0
		var h: float = float(60 + ((i * 31 + level * 23) % 120))
		draw_rect(Rect2(hx, HEIGHT - 45.0 - h, 65, h), Color(0.5, 0.7, 0.8, 0.13))
	draw_rect(Rect2(-SHAKE_MAX, 425, WIDTH + SHAKE_MAX * 2.0, 45 + SHAKE_MAX), Color("#131a26"))
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
	if status == "play":
		draw_reticle(enemy_hitbox().grow(8.0))
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
	draw_set_transform(Vector2.ZERO) # el aviso no tiembla, para que se lea bien
	if notice_time > 0.0 and notice != "":
		# Antes el aviso solo se volcaba al tooltip del HUD y nunca era visible.
		var alpha: float = clampf(notice_time / 0.4, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(0, 40), notice, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, 22, Color(1.0, 0.95, 0.75, alpha))

# Mira verde: cuatro esquinas alrededor del área de impacto del objetivo.
func draw_reticle(r: Rect2) -> void:
	var tl: Texture2D = UI_TEX["reticle_tl"]
	var tr: Texture2D = UI_TEX["reticle_tr"]
	var bl: Texture2D = UI_TEX["reticle_bl"]
	var br: Texture2D = UI_TEX["reticle_br"]
	draw_texture(tl, r.position)
	draw_texture(tr, Vector2(r.end.x - tr.get_width(), r.position.y))
	draw_texture(bl, Vector2(r.position.x, r.end.y - bl.get_height()))
	draw_texture(br, r.end - br.get_size())

# Textos del expediente en orden de escritura: pestaña, nombre, observaciones y pie.
func dossier_lines() -> Array[String]:
	var info: Dictionary = stage()
	var hp: int = int(info["hp"])
	return [
		"EXPEDIENTE %02d" % level,
		str(info["name"]).to_upper(),
		"Zona: %s" % stage()["zone"],
		"Resistencia: %d impacto%s" % [hp, "" if hp == 1 else "s"],
		"Movimiento: %s" % MOTION_NAMES[int(info["motion"])],
		"Escudo: %s" % SHIELD_NAMES[int(info["shield"])],
	]

func dossier_total_chars() -> int:
	var total := 0
	for line in dossier_lines():
		total += line.length()
	return total

func briefing_chars() -> int:
	return int(briefing_time * TYPE_SPEED)

func draw_dossier() -> void:
	var d := dossier
	var font: Font = ThemeDB.fallback_font
	d.draw_rect(Rect2(-DOSSIER_POS, Vector2(WIDTH, HEIGHT)), Color(0, 0, 0, 0.6)) # oscurece el escenario
	d.draw_texture(UI_TEX["dossier"], Vector2.ZERO)
	# Foto del objetivo, encajada en el marco conservando su proporción.
	var photo: Rect2 = DOSSIER_PHOTO.grow(-14.0)
	var tex: Texture2D = stage()["texture"]
	if tex != null:
		var region: Rect2 = sprite_region(tex)
		var s: float = minf(photo.size.x / region.size.x, photo.size.y / region.size.y)
		var size: Vector2 = region.size * s
		d.draw_texture_rect_region(tex, Rect2(photo.get_center() - size * 0.5, size), region)
	else:
		var c: Vector2 = photo.get_center()
		d.draw_circle(c, 62, Color("#f4edf1"))
		for r in [48.0, 33.0, 18.0, 7.0]:
			d.draw_arc(c, r, 0, TAU, 48, Color("#a33d4b") if int(r) % 2 == 0 else Color("#f8f1dc"), 8)
	# Nivel de amenaza: hasta MAX_THREAT franjas rojas.
	var stripe_w: float = DOSSIER_THREAT.size.x / float(MAX_THREAT)
	for i in range(clampi(int(stage()["threat"]), 0, MAX_THREAT)):
		var x: float = DOSSIER_THREAT.position.x + stripe_w * float(i)
		var y0: float = DOSSIER_THREAT.position.y
		var y1: float = DOSSIER_THREAT.end.y
		d.draw_colored_polygon(PackedVector2Array([Vector2(x + 6, y0), Vector2(x + stripe_w - 2, y0), Vector2(x + stripe_w - 8, y1), Vector2(x, y1)]), Color("#c0302a"))
	# Texto con efecto máquina de escribir.
	var lines: Array[String] = dossier_lines()
	var budget: int = briefing_chars()
	var shown: Array[String] = []
	for line in lines:
		shown.append(line.substr(0, clampi(budget, 0, line.length())))
		budget -= line.length()
	d.draw_string(font, DOSSIER_TAB.position + Vector2(0, 17), shown[0], HORIZONTAL_ALIGNMENT_CENTER, DOSSIER_TAB.size.x, 14, DOSSIER_INK)
	d.draw_string(font, DOSSIER_NAME.position + Vector2(10, 23), shown[1], HORIZONTAL_ALIGNMENT_LEFT, DOSSIER_NAME.size.x - 20, 19, DOSSIER_INK)
	for i in range(4):
		d.draw_string(font, DOSSIER_NOTES.position + Vector2(8, 16 + 21 * i), shown[2 + i], HORIZONTAL_ALIGNMENT_LEFT, DOSSIER_NOTES.size.x - 16, 14, DOSSIER_INK)
	if briefing_chars() >= dossier_total_chars() and fmod(briefing_time, 1.0) < 0.7:
		d.draw_string(font, DOSSIER_FOOTER.position + Vector2(0, 26), "CLIC O ESPACIO PARA COMENZAR", HORIZONTAL_ALIGNMENT_CENTER, DOSSIER_FOOTER.size.x, 15, Color("#8a1f1a"))

func draw_wall_rect(rect: Rect2) -> void:
	if rect.size.y <= 0.0:
		return
	# El sprite original es un mosaico 554x554: se repite de manera estable.
	draw_texture_rect_region(WALL_TEXTURE, rect, Rect2(0, 0, rect.size.x * 3.0, rect.size.y * 3.0), Color.WHITE)

func draw_enemy() -> void:
	var center := Vector2(ENEMY_X, enemy_y)
	if enemy_defeated:
		return
	if death_frame() >= 0:
		draw_sheet_frame(stage()["death"], death_frame(), enemy_sprite_rect())
		return
	if stage()["texture"] != null:
		var tex: Texture2D = stage()["texture"]
		var frame: int = hurt_frame()
		if frame >= 0:
			draw_sheet_frame(stage()["hurt"], frame, enemy_sprite_rect())
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
	var payload := {"version":2, "coins":coins, "score":score, "level":level, "unlocked":unlocked, "owned":owned, "equipped":equipped, "stars":stars, "sound":sound_enabled}
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
	unlocked = clampi(int(data.get("unlocked", 1)), 1, STAGES.size())
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
	sound_enabled = bool(data.get("sound", true))
	var ratings: Variant = data.get("stars", {})
	if typeof(ratings) == TYPE_DICTIONARY:
		stars = {}
		for key in ratings:
			var id: String = str(key)
			# Partidas de la versión 1: la clave era el número de nivel; ahora es el "id" de la etapa.
			if id.is_valid_int() and int(id) >= 1 and int(id) <= STAGES.size():
				id = str(STAGES[int(id) - 1]["id"])
			# Las medallas de etapas que ya no existen se descartan.
			if STAGES.any(func(s): return str(s["id"]) == id):
				stars[id] = clampi(int(ratings[key]), 0, 3)
