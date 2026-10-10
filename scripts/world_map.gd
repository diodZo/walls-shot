extends Control

# Mapa del mundo al estilo Super Mario World: las etapas son puntos unidos por una ruta y el agente
# camina de uno a otro. Solo se llega hasta la última etapa desbloqueada; ENTER, ESPACIO o un clic
# sobre el punto actual entran en la etapa. Los mundos se definen en scripts/stages.gd (WORLDS).
#
# Ocupa toda la ventana: a la izquierda la imagen del mundo (cuadrada, MAP_SIZE px), que ya trae
# dibujados la ruta, los puntos y sus nombres; a la derecha, el panel con la etapa seleccionada.
# Sobre los puntos de la imagen solo se dibuja su estado: anillo si está pendiente, medalla si
# está superada y candado si está bloqueada.

signal stage_chosen(level: int)
signal menu_requested

const AGENT := preload("res://assets/player.png")
const AGENT_HEIGHT := 56.0 # alto en pantalla del agente
const AGENT_FEET_X := 0.34 # centro de los pies, como fracción del ancho opaco de player.png
const WALK_SPEED := 200.0 # px/s en pantalla
const MAP_SIZE := 650.0
const MIN_CLICK_RADIUS := 16.0
const INK := Color("#2a2b1d") # texto sobre la chapa del panel
const ACCENT := Color("#8a1f1a")
const OUTLINE := Color("#14120a")

var world: Dictionary = {}
var stages: Array = [] # fichas de etapa (stages.gd LIST), indexadas por nivel - 1
var unlocked := 1
var stars := {}
var coins := 0
var medal_icons: Array = [] # bronce, plata y oro pequeñas (sobre los puntos); las asigna main.gd
var medal_large: Array = [] # las mismas, grandes (panel)
var panel_box: StyleBox # chapa del panel derecho; la asigna main.gd
var cursor := 0 # nodo donde está el agente, o hacia el que camina
var agent_pos := Vector2.ZERO
var route: Array[Vector2] = [] # puntos que le quedan por recorrer (en pantalla)
var clock := 0.0
var facing := 1.0 # 1 = mira a la derecha (pose original), -1 = a la izquierda
var agent_region := Rect2() # área opaca de player.png (se calcula al dibujar por primera vez)
var enter_button: Button
var menu_button: Button

func _ready() -> void:
	enter_button = make_button("ENTRAR", enter, Vector2(MAP_SIZE + 45, 520))
	menu_button = make_button("MENÚ PRINCIPAL", func(): menu_requested.emit(), Vector2(MAP_SIZE + 45, 572))

func make_button(label: String, fn: Callable, pos: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.position = pos
	button.custom_minimum_size = Vector2(260, 45)
	button.focus_mode = Control.FOCUS_NONE # ENTER y ESPACIO los gestiona handle_input()
	button.pressed.connect(fn)
	add_child(button)
	return button

func open(world_data: Dictionary, stage_list: Array, unlocked_count: int, ratings: Dictionary, level: int, coin_count: int) -> void:
	world = world_data
	stages = stage_list
	unlocked = unlocked_count
	stars = ratings
	coins = coin_count
	cursor = 0
	for i in node_count():
		if node_level(i) == level:
			cursor = i
	route.clear()
	agent_pos = node_pos(cursor)
	facing = 1.0
	show()
	queue_redraw()

# Escala de la imagen del mundo (px de la imagen -> px de pantalla).
func map_scale() -> float:
	var bg: Texture2D = world.get("background")
	return MAP_SIZE / float(bg.get_width()) if bg != null else 1.0

func to_screen(p: Vector2) -> Vector2:
	return p * map_scale()

func node_count() -> int:
	return (world.get("nodes", []) as Array).size()

func node_level(i: int) -> int:
	return int(world["nodes"][i]["stage"])

func node_pos(i: int) -> Vector2:
	return to_screen(world["nodes"][i]["pos"])

func node_radius(i: int) -> float:
	return float(world["nodes"][i].get("radius", 20.0)) * map_scale()

func node_label(i: int) -> String:
	return str(world["nodes"][i].get("label", stages[node_level(i) - 1]["zone"]))

func is_open(i: int) -> bool:
	return node_level(i) <= unlocked

func walking() -> bool:
	return not route.is_empty()

func current_level() -> int:
	return node_level(cursor)

# Puntos (en pantalla) de la ruta que llega al nodo i desde el anterior, con ambos extremos.
func segment(i: int) -> Array[Vector2]:
	var points: Array[Vector2] = [node_pos(i - 1)]
	for p in world["nodes"][i].get("via", []):
		points.append(to_screen(p))
	points.append(node_pos(i))
	return points

# Camina hasta el nodo i pasando por los intermedios; no cruza etapas bloqueadas.
func walk_to(i: int) -> void:
	if walking() or i == cursor or i < 0 or i >= node_count() or not is_open(i):
		return
	var step: int = 1 if i > cursor else -1
	var j: int = cursor
	while j != i:
		var points: Array[Vector2] = segment(j + 1) if step > 0 else segment(j)
		if step < 0:
			points.reverse()
		route.append_array(points.slice(1))
		j += step
	cursor = i

# Vecino (anterior o siguiente) cuya ruta sale en la dirección pulsada. Si ninguna coincide,
# derecha/arriba avanzan y izquierda/abajo retroceden, para que la ruta nunca quede trabada.
func neighbor_towards(dir: Vector2) -> int:
	var best := -1
	var best_dot := 0.5
	for n in [cursor - 1, cursor + 1]:
		if n < 0 or n >= node_count():
			continue
		# Primer punto de la ruta al salir del nodo actual hacia n.
		var first: Vector2
		if n > cursor:
			first = segment(n)[1]
		else:
			var back: Array[Vector2] = segment(cursor)
			first = back[back.size() - 2]
		var d: float = (first - node_pos(cursor)).normalized().dot(dir)
		if d > best_dot:
			best_dot = d
			best = n
	if best < 0:
		best = cursor + 1 if (dir == Vector2.RIGHT or dir == Vector2.UP) else cursor - 1
	return best

func handle_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var dir := Vector2.ZERO
		match event.keycode:
			KEY_RIGHT, KEY_D:
				dir = Vector2.RIGHT
			KEY_LEFT, KEY_A:
				dir = Vector2.LEFT
			KEY_UP, KEY_W:
				dir = Vector2.UP
			KEY_DOWN, KEY_S:
				dir = Vector2.DOWN
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				enter()
			KEY_ESCAPE:
				menu_requested.emit()
		if dir != Vector2.ZERO:
			walk_to(neighbor_towards(dir))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in node_count():
			if event.position.distance_to(node_pos(i)) <= maxf(node_radius(i), MIN_CLICK_RADIUS) * 1.4:
				if i == cursor:
					enter()
				else:
					walk_to(i)
				return

func enter() -> void:
	if not walking() and is_open(cursor):
		stage_chosen.emit(current_level())

func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	var budget: float = WALK_SPEED * delta
	while budget > 0.0 and walking():
		# Mira hacia donde camina; en los tramos verticales conserva la orientación.
		if absf(route[0].x - agent_pos.x) > 0.5:
			facing = signf(route[0].x - agent_pos.x)
		var to_next: float = agent_pos.distance_to(route[0])
		if to_next <= budget:
			agent_pos = route.pop_front()
			budget -= to_next
		else:
			agent_pos += (route[0] - agent_pos).normalized() * budget
			budget = 0.0
	if enter_button != null:
		enter_button.disabled = walking() or not is_open(cursor)
	queue_redraw()

func _draw() -> void:
	var bg: Texture2D = world.get("background")
	if bg != null:
		draw_texture_rect(bg, Rect2(0, 0, MAP_SIZE, MAP_SIZE), false)
	for i in node_count():
		draw_node_state(i)
	draw_agent()
	draw_panel()

func draw_node_state(i: int) -> void:
	var p: Vector2 = node_pos(i)
	var r: float = node_radius(i)
	if not is_open(i):
		# Bloqueada: el punto de la imagen queda apagado bajo un candado.
		draw_circle(p, r + 2.0, Color(0.06, 0.07, 0.05, 0.78))
		draw_arc(p + Vector2(0, -2), 3.5, PI, TAU, 10, Color("#c9c4ac"), 2.0)
		draw_rect(Rect2(p + Vector2(-5, -2), Vector2(10, 7)), Color("#c9c4ac"))
		return
	var best: int = clampi(int(stars.get(stage_id(node_level(i)), 0)), 0, 3)
	if best == 0:
		# Pendiente: anillo que late para llamar la atención.
		var pulse: float = 0.5 + 0.5 * sin(clock * 4.0)
		draw_arc(p, r + 3.0 + pulse * 4.0, 0, TAU, 32, Color(1.0, 0.85, 0.3, 0.9 - pulse * 0.5), 2.5)
	elif best - 1 < medal_icons.size():
		var icon: Texture2D = medal_icons[best - 1]
		draw_texture(icon, p + Vector2(-r - icon.get_width() - 1.0, -icon.get_height() * 0.5))

func draw_agent() -> void:
	# Sprite de una sola pose (señala a la derecha): rebota al caminar y se voltea según la dirección.
	if agent_region == Rect2():
		agent_region = Rect2(AGENT.get_image().get_used_rect())
	var bob: float = absf(sin(clock * 12.0)) * 4.0 if walking() else 0.0
	var size_px: Vector2 = agent_region.size * (AGENT_HEIGHT / agent_region.size.y)
	var feet := Vector2(agent_pos.x, agent_pos.y - 4.0)
	draw_rect(Rect2(feet + Vector2(-12, -3), Vector2(24, 6)), Color(0, 0, 0, 0.4)) # sombra
	# Origen en los pies; la escala -1 en x voltea el sprite alrededor de ellos.
	draw_set_transform(feet + Vector2(0, -bob), 0.0, Vector2(facing, 1.0))
	draw_texture_rect_region(AGENT, Rect2(Vector2(-size_px.x * AGENT_FEET_X, -size_px.y), size_px), agent_region)
	draw_set_transform(Vector2.ZERO)

func draw_panel() -> void:
	var font: Font = ThemeDB.fallback_font
	var panel := Rect2(MAP_SIZE, 0, size.x - MAP_SIZE, size.y)
	if panel_box != null:
		draw_style_box(panel_box, panel)
	else:
		draw_rect(panel, Color("#3a3d30"))
	if node_count() == 0:
		return
	var x: float = MAP_SIZE + 45.0
	var w: float = panel.size.x - 90.0
	var level: int = current_level()
	var info: Dictionary = stages[level - 1]
	var best: int = clampi(int(stars.get(stage_id(level), 0)), 0, 3)
	draw_string(font, Vector2(x, 70), str(world.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, 15, ACCENT)
	draw_string(font, Vector2(x, 96), "ETAPA %d DE %d" % [cursor + 1, node_count()], HORIZONTAL_ALIGNMENT_LEFT, w, 15, INK)
	draw_line(Vector2(x, 108), Vector2(x + w, 108), INK, 2.0)
	draw_string(font, Vector2(x, 150), node_label(cursor).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, 32, INK)
	draw_string(font, Vector2(x, 190), "OBJETIVO", HORIZONTAL_ALIGNMENT_LEFT, w, 13, ACCENT)
	draw_string(font, Vector2(x, 212), str(info["name"]), HORIZONTAL_ALIGNMENT_LEFT, w, 18, INK)
	var state: String = "BLOQUEADA" if not is_open(cursor) else ("SUPERADA" if best > 0 else "PENDIENTE")
	draw_string(font, Vector2(x, 250), "ESTADO", HORIZONTAL_ALIGNMENT_LEFT, w, 13, ACCENT)
	draw_string(font, Vector2(x, 272), state, HORIZONTAL_ALIGNMENT_LEFT, w, 18, INK)
	for m in range(medal_large.size()):
		var icon: Texture2D = medal_large[m]
		var tint := Color.WHITE if m < best else Color(0.25, 0.25, 0.25, 0.55)
		draw_texture(icon, Vector2(x + m * (icon.get_width() + 10.0), 292), tint)
	draw_string(font, Vector2(x, 420), "MONEDAS: %d" % coins, HORIZONTAL_ALIGNMENT_LEFT, w, 15, INK)
	draw_string(font, Vector2(x, 450), "FLECHAS: moverse", HORIZONTAL_ALIGNMENT_LEFT, w, 13, INK)
	draw_string(font, Vector2(x, 470), "ENTER / CLIC: entrar   ESC: menú", HORIZONTAL_ALIGNMENT_LEFT, w, 13, INK)
	# Avisos de main.gd (p. ej. sin monedas): el mapa tapa el escenario donde se dibujan.
	var host := get_parent()
	if host != null and "notice_time" in host and float(host.notice_time) > 0.0:
		var alpha: float = clampf(float(host.notice_time) / 0.4, 0.0, 1.0)
		draw_string(font, Vector2(x, 500), str(host.notice), HORIZONTAL_ALIGNMENT_LEFT, w, 15, Color(ACCENT, alpha))

func stage_id(level: int) -> String:
	return str(stages[level - 1]["id"])
