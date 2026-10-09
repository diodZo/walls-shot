extends SceneTree

# Pruebas automatizadas de WALLSHOT (lógica de juego, animaciones y render básico).
# Ejecutar desde la raíz del proyecto:
#   godot --headless --path . --script res://tests/wallshot_test.gd
# Termina con código 0 si todo pasa y 1 si alguna prueba falla.
# Las pruebas escriben user://wallshot_save.json: se guarda una copia al empezar y se restaura al final.

const SAVE_PATH := "user://wallshot_save.json"

var fails := 0
var passes := 0

func check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)

# Predice si un disparo ahora cruzaría todas las aberturas y alcanzaría al enemigo con el escudo abierto.
func will_hit(game: Node) -> bool:
	var speed: float = float(game.WEAPONS[game.equipped]["speed"])
	var y: float = game.LINE_Y
	for w in game.walls:
		if bool(w["broken"]):
			continue
		for edge in [float(w["x"]) - 5.0, float(w["x"]) + float(w["w"]) + 5.0]:
			var t: float = (edge - 125.0) / speed
			var c: float = game.LINE_Y + sin(float(w["clock"]) + t * float(w["speed"]) + float(w["phase"])) * float(w["amp"])
			if absf(c - y) > float(w["gap"]) * 0.5 - 5.0 - 2.0:
				# el primer muro que bloquearía es destructible: disparo útil (estrategia de jugador)
				return bool(w["breakable"]) and absf(c - y) > float(w["gap"]) * 0.5 + 10.0
	var prof: Dictionary = game.ENEMIES[game.level - 1]
	var hit: Vector2 = game.enemy_hitbox().size * 0.5
	var te: float = game.elapsed + (game.ENEMY_X - hit.x - 125.0) / speed
	var motion: int = int(prof["motion"])
	var ey: float = game.LINE_Y + (sin(te * 2.2) * 36.0 if motion == 1 else (sin(te * 1.2) * 18.0 if motion == 2 else 0.0))
	if absf(ey - y) > hit.y:
		return false
	var shield: int = int(prof["shield"])
	return shield == 0 or sin(te * (1.65 if shield == 2 else 2.0)) > -0.1

func hit_center(game: Node) -> void:
	game.enemy_y = game.LINE_Y
	game.bullet = {"x":800.0, "y":game.LINE_Y, "speed":660.0, "damage":1, "pierce":0, "ignored":[]}
	for i in 20:
		if game.bullet.is_empty():
			break
		game.move_bullet(0.033)

func fresh(game: Node, lvl: int, weapon: int) -> void:
	game.level = lvl
	game.owned = [0, 1, 2, 3]
	game.equipped = weapon
	game.start_stage()

func _initialize() -> void:
	var save_backup: Variant = FileAccess.get_file_as_string(SAVE_PATH) if FileAccess.file_exists(SAVE_PATH) else null
	await run_tests()
	if save_backup == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	else:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_string(save_backup)
		file.close()
	print("RESULT passes=%d fails=%d" % [passes, fails])
	quit(1 if fails > 0 else 0)

func run_tests() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.status == "menu", "arranque en menú")

	# --- Partículas ---
	game.particles.clear()
	game.spawn_particles(Vector2(100, 100), Color.RED, 12)
	check(game.particles.size() == 12, "spawn_particles crea 12")
	var p0: Vector2 = game.particles[0]["pos"]
	game.update_particles(0.016)
	check(game.particles[0]["pos"] != p0, "update_particles mueve")
	for i in 60:
		game.update_particles(0.016)
	check(game.particles.is_empty(), "partículas expiran (<1s)")
	game.spawn_particles(Vector2.ZERO, Color.RED, 1000)
	check(game.particles.size() == game.MAX_PARTICLES, "límite MAX_PARTICLES")
	game.particles.clear()

	# --- Hitbox real del enemigo móvil (drone, nivel 2, semialto 32) ---
	fresh(game, 2, 0)
	game.walls.clear()
	game.enemy_y = game.LINE_Y
	game.enemy_y = game.LINE_Y + game.enemy_hitbox().size.y * 0.5 + 20.0
	game.bullet = {"x":850.0, "y":game.LINE_Y, "speed":660.0, "damage":1, "pierce":0, "ignored":[]}
	game.move_bullet(0.033)
	check(not game.bullet.is_empty() and game.enemy_hp == 1, "drone desplazado fuera de su hitbox: la bala NO impacta al alcanzar su X")
	for i in 20:
		if game.bullet.is_empty():
			break
		game.move_bullet(0.033)
	check(game.bullet.is_empty() and game.enemy_hp == 1 and game.status == "play", "bala fallada sale de pantalla y se destruye")
	game.enemy_y = game.LINE_Y
	game.bullet = {"x":850.0, "y":game.LINE_Y, "speed":660.0, "damage":1, "pierce":0, "ignored":[]}
	for i in 10:
		if game.bullet.is_empty():
			break
		game.move_bullet(0.033)
	check(game.status == "dying" and game.enemy_hp == 0, "impacto centrado derrota al nivel 2 (inicia su muerte)")

	# --- Nuevos jefes con sprite (niveles 3, 4, 5) ---
	for lvl in [2, 3, 4, 5]:
		fresh(game, lvl, 0)
		var tex: Texture2D = game.ENEMY_TEXTURES[lvl - 1]
		var region: Rect2 = game.sprite_region(tex)
		var drawn: Rect2 = game.enemy_sprite_rect()
		var hb: Rect2 = game.enemy_hitbox()
		print("   nivel %d sprite=%s region=%s dibujado=%s hitbox=%s" % [lvl, tex.resource_path.get_file(), region, drawn.size, hb.size])
		check(tex != null and maxf(drawn.size.x, drawn.size.y) <= game.ENEMY_SPRITE_BOX + 0.01, "nivel %d: jefe con sprite propio dentro de la caja" % lvl)
		check(drawn.encloses(hb), "nivel %d: hitbox contenida en el sprite visible" % lvl)
		game.walls.clear()
		game.shield_open = true
		game.enemy_y = game.LINE_Y + hb.size.y * 0.5 + 20.0
		game.bullet = {"x":800.0, "y":game.LINE_Y, "speed":660.0, "damage":1, "pierce":0, "ignored":[]}
		var hp_before: int = game.enemy_hp
		for i in 20:
			if game.bullet.is_empty():
				break
			game.move_bullet(0.033)
		check(game.enemy_hp == hp_before, "nivel %d: bala por fuera de la hitbox no daña" % lvl)
		game.enemy_y = game.LINE_Y
		game.bullet = {"x":800.0, "y":game.LINE_Y, "speed":660.0, "damage":1, "pierce":0, "ignored":[]}
		for i in 20:
			if game.bullet.is_empty():
				break
			game.move_bullet(0.033)
		check(game.enemy_hp == hp_before - 1, "nivel %d: impacto centrado daña al jefe" % lvl)

	# --- Animaciones de dolor y muerte (niveles 2..5) ---
	for lvl in [2, 3, 4, 5]:
		fresh(game, lvl, 0)
		game.walls.clear()
		game.shield_open = true
		game.enemy_hp = 2
		check(game.hurt_frame() == -1, "nivel %d: sin animación de dolor al empezar" % lvl)
		hit_center(game)
		check(game.enemy_hp == 1 and game.hurt_frame() == 0, "nivel %d: impacto inicia animación de dolor" % lvl)
		var seen := {}
		for i in 60:
			var f: int = game.hurt_frame()
			if f >= 0:
				seen[f] = true
			if i % 4 == 0:
				await process_frame # dibuja los fotogramas reales
			game._process(1.0 / 60.0)
		check(seen.size() == 4 and game.hurt_frame() == -1, "nivel %d: dolor recorre 4 fotogramas y vuelve al sprite base" % lvl)
		var coins_pre: int = game.coins
		hit_center(game)
		check(game.status == "dying" and game.death_frame() == 0, "nivel %d: golpe final inicia animación de muerte" % lvl)
		check(not game.overlay_panel.visible and game.coins == coins_pre, "nivel %d: victoria se retrasa hasta terminar la animación" % lvl)
		var shots_pre: int = game.shots
		game.fire()
		check(game.bullet.is_empty() and game.shots == shots_pre, "nivel %d: no se puede disparar durante la muerte" % lvl)
		var dseen := {}
		var dguard := 0
		while game.status == "dying" and dguard < 200:
			dguard += 1
			dseen[game.death_frame()] = true
			if dguard % 4 == 0:
				await process_frame
			game._process(1.0 / 60.0)
		check(dseen.size() == 4, "nivel %d: recorre los 4 fotogramas de muerte" % lvl)
		check(game.status == "win" and game.overlay_panel.visible and game.coins > coins_pre and game.enemy_defeated, "nivel %d: tras la muerte aparece la victoria y el jefe desaparece" % lvl)
		game.start_stage()
		check(not game.enemy_defeated and game.death_time < 0.0 and game.status == "play", "nivel %d: reiniciar restaura al jefe" % lvl)
	fresh(game, 3, 0)
	game.enemy_hp = 1
	game.walls.clear()
	game.shield_open = true
	hit_center(game)
	game.go_menu()
	check(game.status == "menu" and game.death_time < 0.0 and not game.enemy_defeated, "ir al menú durante la muerte deja el estado limpio")
	fresh(game, 1, 0)
	game.walls.clear()
	hit_center(game)
	check(game.status == "win" and game.hurt_frame() == -1, "nivel 1 (sin animaciones): victoria inmediata")

	# --- Animaciones de la pistola (disparo y recarga) ---
	for weapon in [0, 1, 2, 3]:
		fresh(game, 1, weapon)
		check(game.weapon_fire_frame() == -1 and game.weapon_reload_frame() == -1, "arma %d: sin animación al empezar" % weapon)
		game.fire()
		check(game.weapon_fire_frame() == 0, "arma %d: disparar inicia animación de disparo" % weapon)
		game.bullet.clear() # solo se prueba la animación; evita que la bala gane el nivel
		var fseen := {}
		for i in 40:
			var f: int = game.weapon_fire_frame()
			if f >= 0:
				fseen[f] = true
			if i % 3 == 0:
				await process_frame
			game._process(1.0 / 60.0)
		check(fseen.size() == 4 and game.weapon_fire_frame() == -1, "arma %d: disparo recorre 4 fotogramas y vuelve al sprite base" % weapon)
		game.reload_weapon()
		var rseen := {}
		var order_ok := true
		var last := -1
		var rguard := 0
		while game.reload_time > 0.0 and rguard < 200:
			rguard += 1
			var f: int = game.weapon_reload_frame()
			rseen[f] = true
			if f < last:
				order_ok = false
			last = f
			if rguard % 4 == 0:
				await process_frame
			game._process(1.0 / 60.0)
		check(rseen.size() == 4 and order_ok and game.weapon_reload_frame() == -1, "arma %d: recarga recorre 4 fotogramas en orden y termina" % weapon)

	# --- Escudo bloquea ---
	fresh(game, 3, 0)
	game.walls.clear()
	game.shield_open = false
	game.bullet = {"x":850.0, "y":game.LINE_Y, "speed":660.0, "damage":1, "pierce":0, "ignored":[]}
	for i in 20:
		if game.bullet.is_empty():
			break
		game.move_bullet(0.033)
	check(game.bullet.is_empty() and game.enemy_hp == 2, "escudo cerrado bloquea sin daño")

	# --- Anti-tunneling: bala 1250 px/s con dt 0.033 (41px) vs muro de 31px ---
	fresh(game, 1, 2)
	var wall: Dictionary = game.walls[0]
	wall["center"] = game.LINE_Y + 200.0 # abertura lejos de la línea de tiro
	wall["breakable"] = false
	game.bullet = {"x":float(wall["x"]) - 8.0, "y":game.LINE_Y, "speed":1250.0, "damage":1, "pierce":0, "ignored":[]}
	game.move_bullet(0.033)
	check(game.bullet.is_empty(), "rifle no atraviesa muro por salto de fotograma")
	check(game.particles.size() > 0, "impacto en muro genera partículas")

	# --- Perforación ---
	fresh(game, 1, 3)
	game.special()
	check(game.pierce_next == 2, "plasma prepara doble perforación")
	wall = game.walls[0]
	wall["center"] = game.LINE_Y + 200.0
	game.fire()
	game.bullet["x"] = float(wall["x"]) - 8.0
	game.move_bullet(0.033)
	check(not game.bullet.is_empty() and int(game.bullet["pierce"]) == 1, "bala perforante sigue tras el muro")

	# --- Muro destructible ---
	fresh(game, 1, 0)
	wall = game.walls[0]
	for k in 2:
		wall["center"] = game.LINE_Y + 200.0
		game.bullet = {"x":float(wall["x"]) - 8.0, "y":game.LINE_Y, "speed":660.0, "damage":1, "pierce":0, "ignored":[]}
		game.move_bullet(0.033)
	check(bool(wall["broken"]), "muro destructible se rompe con 2 impactos")

	# --- Habilidad lenta ---
	fresh(game, 1, 1)
	game.special()
	check(game.focus_time > 0.0 and game.abilities_left == 1, "pistola mejorada activa tiempo lento")

	# --- Munición, recarga y Game Over ---
	fresh(game, 1, 0)
	for w in game.walls:
		w["breakable"] = false
		w["gap"] = 0.0 # todo choca
	var guard := 0
	while game.status == "play" and guard < 20000:
		guard += 1
		game.fire()
		game._process(0.033)
	check(game.status == "lose", "sin munición ni cargadores -> GAME OVER")
	check(game.shots == 8 and game.reloads_left == 0, "consumió 2 cargadores (8+8)")

	# --- Partida completa automática niveles 1..5 con el plasma ---
	game.unlocked = 1
	game.coins = 0
	fresh(game, 1, 3)
	var cleared := 0
	for lvl in range(1, 6):
		var attempts := 0
		while attempts < 40:
			attempts += 1
			game.level = lvl
			game.start_stage()
			guard = 0
			while (game.status == "play" or game.status == "dying") and guard < 6000:
				guard += 1
				# dispara solo cuando la abertura del primer muro intacto está alineada
				if game.bullet.is_empty() and game.reload_time <= 0.0 and will_hit(game):
					game.fire()
				game._process(1.0 / 60.0)
			if game.status == "win":
				break
		check(game.status == "win", "nivel %d completable (intentos %d)" % [lvl, attempts])
		if game.status == "win":
			cleared += 1
			check(game.unlocked >= mini(5, lvl + 1), "nivel %d desbloquea el siguiente" % lvl)
			check(game.overlay_start.pressed.is_connected(game.next_stage), "botón pasa a SIGUIENTE NIVEL")
	check(game.coins > 0 and game.stars.size() == cleared, "monedas y estrellas otorgadas")
	game.overlay_start.pressed.emit()
	check(game.level == 1 and game.status == "play", "tras nivel 5 vuelve al nivel 1")

	# --- Guardado ---
	var coins_before: int = game.coins
	game.save_game()
	var other: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(other)
	await process_frame
	check(other.coins == coins_before and other.unlocked == 5 and other.owned.size() == 4, "guardado/carga persiste progreso")

	# --- Compra ---
	other.owned = [0]
	other.equipped = 0
	other.coins = 300
	other.choose_weapon(2)
	check(other.equipped == 0 and other.coins == 300, "compra rechazada sin monedas")
	other.choose_weapon(1)
	check(other.equipped == 1 and other.coins == 50 and other.owned.has(1), "compra de pistola mejorada")

	# --- Render: forzar varios frames reales con partículas y aviso ---
	game.spawn_particles(Vector2(500, 200), Color.WHITE, 50)
	game.notify("TEST")
	for i in 30:
		await process_frame
	check(true, "render de frames sin errores")
