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
	var prof: Dictionary = game.stage()
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

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

# Salta al último blanco o jefe de la etapa (Chile tiene tres blancos seguidos).
func last_target(game: Node) -> void:
	game.phase = (game.stage().get("phases", []) as Array).size()
	game.enemy_hp = int(game.enemy()["hp"])
	game.enemy_max_hp = game.enemy_hp

func fresh(game: Node, lvl: int, weapon: int) -> void:
	game.level = lvl
	game.owned = [0, 1, 2, 3]
	game.equipped = weapon
	game.start_stage()
	game.begin_stage() # salta el expediente si el nivel es nuevo

func _initialize() -> void:
	var save_backup: Variant = FileAccess.get_file_as_string(SAVE_PATH) if FileAccess.file_exists(SAVE_PATH) else null
	await run_tests()
	# Detiene los sonidos y libera las instancias del juego antes de salir: el servidor de audio
	# retiene las reproducciones en curso unos fotogramas y, si no, quedan como fugas al cerrar.
	for child in root.get_children():
		if "quitting" in child:
			child.quitting = true # que la música no vuelva a arrancar durante la espera
		for player in child.find_children("*", "AudioStreamPlayer", true, false):
			player.stop()
			player.stream = null
		child.queue_free()
	await create_timer(0.2).timeout # el servidor de audio tarda unos ciclos en soltar las MP3
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

	# --- Fichas de etapas (scripts/stages.gd) ---
	var keys := ["name", "hp", "motion", "shield", "texture", "hurt", "death", "zone", "color", "music", "threat", "reloads", "walls"]
	var wall_keys := ["x", "speed", "amp", "gap", "phase", "hp", "breakable"]
	var data_ok := true
	for i in game.STAGES.size():
		var st: Dictionary = game.STAGES[i]
		var prev_x := -INF
		for k in keys:
			if not st.has(k):
				data_ok = false
				print("   etapa %d: falta \"%s\"" % [i + 1, k])
		if st.get("texture") == null and not st.has("hit"):
			data_ok = false
			print("   etapa %d: sin sprite necesita \"hit\"" % (i + 1))
		if not game.MUSIC.has(st.get("music", "")):
			data_ok = false
			print("   etapa %d: tema de música desconocido" % (i + 1))
		for extra in st.get("phases", []):
			for k in ["name", "hp", "motion", "shield", "texture", "hurt", "death"]:
				if not extra.has(k):
					data_ok = false
					print("   etapa %d: jefe adicional sin \"%s\"" % [i + 1, k])
			if extra.get("texture") == null and not extra.has("hit"):
				data_ok = false
				print("   etapa %d: jefe adicional sin sprite necesita \"hit\"" % (i + 1))
			for w in extra.get("add_walls", []):
				for k in wall_keys:
					if not w.has(k):
						data_ok = false
						print("   etapa %d: muro añadido sin \"%s\"" % [i + 1, k])
		for anim in [st.get("hurt"), st.get("death")]:
			if anim != null and (anim["src"] as Array).size() != (anim["anchors"] as Array).size():
				data_ok = false
				print("   etapa %d: animación con distinto número de src y anchors" % (i + 1))
		for w in st.get("walls", []):
			for k in wall_keys:
				if not w.has(k):
					data_ok = false
					print("   etapa %d: muro sin \"%s\"" % [i + 1, k])
			if float(w.get("x", 0.0)) <= prev_x:
				data_ok = false
				print("   etapa %d: muros fuera de orden" % (i + 1))
			prev_x = float(w.get("x", 0.0))
	check(game.STAGES.size() >= 1 and data_ok, "fichas de etapas completas y válidas (%d etapas)" % game.STAGES.size())

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
		var tex: Texture2D = game.stage()["texture"]
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
		var death_count: int = (game.enemy()["death"]["src"] as Array).size()
		var dseen := {}
		var dguard := 0
		while game.status == "dying" and dguard < 200:
			dguard += 1
			dseen[game.death_frame()] = true
			if dguard % 4 == 0:
				await process_frame
			game._process(1.0 / 60.0)
		check(dseen.size() == death_count, "nivel %d: recorre los %d fotogramas de muerte" % [lvl, death_count])
		if game.stage().has("phases"):
			# Venezuela: al morir el primer jefe entra el segundo, sin victoria ni recompensa todavía.
			var second: Dictionary = game.stage()["phases"][0]
			check(game.status == "play" and game.phase == 1 and game.enemy_hp == int(second["hp"]) and not game.overlay_panel.visible and game.coins == coins_pre and not game.enemy_defeated, "nivel %d: al morir el primer jefe entra %s" % [lvl, second["name"]])
			check(game.notice.contains(str(second["name"]).to_upper()) and game.enemy_sprite_rect().size.x > 0.0, "nivel %d: aviso del segundo jefe y su sprite" % lvl)
			await process_frame # dibuja al segundo jefe
			game.enemy_hp = 1
			hit_center(game)
			check(game.status == "dying" and game.death_frame() == 0, "nivel %d: el segundo jefe también tiene animación de muerte" % lvl)
			dguard = 0
			while game.status == "dying" and dguard < 200:
				dguard += 1
				game._process(1.0 / 60.0)
		check(game.status == "win" and game.overlay_panel.visible and game.coins > coins_pre and game.enemy_defeated, "nivel %d: tras la muerte aparece la victoria y el jefe desaparece" % lvl)
		game.start_stage()
		check(not game.enemy_defeated and game.death_time < 0.0 and game.status == "play" and game.phase == 0 and game.enemy_hp == int(game.stage()["hp"]), "nivel %d: reiniciar restaura al (primer) jefe" % lvl)
	# Venezuela: si la última bala derriba al primer jefe y no quedan cargadores, se pierde al entrar el segundo.
	fresh(game, 4, 0)
	game.walls.clear()
	game.enemy_hp = 1
	game.shots = int(game.WEAPONS[0]["ammo"])
	game.reloads_left = 0
	hit_center(game)
	var ammo_guard := 0
	while game.status == "dying" and ammo_guard < 200:
		ammo_guard += 1
		game._process(1.0 / 60.0)
	check(game.status == "lose" and game.phase == 1, "nivel 4: sin munición al entrar el segundo jefe -> GAME OVER")
	fresh(game, 3, 0)
	game.enemy_hp = 1
	game.walls.clear()
	game.shield_open = true
	hit_center(game)
	game.go_menu()
	check(game.status == "menu" and game.death_time < 0.0 and not game.enemy_defeated, "ir al menú durante la muerte deja el estado limpio")
	# Chile: tres blancos seguidos; con el 2.º y el 3.º se levanta un muro más.
	fresh(game, 1, 0)
	var chile_walls: int = game.walls.size()
	hit_center(game)
	check(game.status == "play" and game.phase == 1 and game.walls.size() == chile_walls + 1 and game.notice.begins_with("BLANCO 2"), "Chile: el 1.er blanco da paso al 2.º y se levanta un muro")
	var xs_sorted := true
	for i in range(1, game.walls.size()):
		xs_sorted = xs_sorted and float(game.walls[i]["x"]) > float(game.walls[i - 1]["x"])
	check(xs_sorted and game.shake > 0.0, "Chile: el muro nuevo queda en orden de izquierda a derecha, con sacudida")
	hit_center(game)
	check(game.status == "play" and game.phase == 2 and game.walls.size() == chile_walls + 2 and game.notice.begins_with("BLANCO 3"), "Chile: el 2.º blanco da paso al 3.º y otro muro")
	hit_center(game)
	check(game.status == "win" and game.hurt_frame() == -1, "Chile: el 3.er blanco da la victoria (sin animaciones)")
	game.start_stage()
	check(game.phase == 0 and game.walls.size() == chile_walls, "Chile: reintentar vuelve al 1.er blanco y a un solo muro")

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

	# --- Sonido, hit-stop y sacudida ---
	var sfx_ok := true
	for sound in game.SFX:
		var stream: AudioStream = game.SFX[sound]["stream"]
		if stream == null or stream.get_length() <= 0.0:
			sfx_ok = false
			print("   sfx inválido: ", sound)
	check(sfx_ok and game.SFX.size() == 14, "los 14 efectos de sonido cargan y tienen duración")
	game.sound_enabled = true
	for weapon in [0, 2, 3]:
		fresh(game, 1, weapon)
		game.fire()
		check(game.last_sfx == game.SHOT_SOUNDS[int(game.WEAPONS[weapon]["sprite"])], "arma %d: suena su disparo (%s)" % [weapon, game.last_sfx])
	fresh(game, 3, 0)
	game.walls.clear()
	game.shield_open = true
	hit_center(game)
	check(game.last_sfx == "enemy_hit" and game.hitstop_time > 0.0 and game.shake > 0.0, "impacto al jefe: sonido, hit-stop y sacudida")
	var t_before: float = game.elapsed
	game._process(1.0 / 60.0)
	check(game.elapsed == t_before, "hit-stop congela el juego")
	for i in 3:
		await process_frame # dibuja con sacudida activa
	for i in 10:
		game._process(1.0 / 60.0)
	check(game.elapsed > t_before and game.hitstop_time == 0.0, "el juego se reanuda tras el hit-stop")
	for i in 30:
		game._process(1.0 / 60.0)
	check(game.shake == 0.0, "la sacudida se desvanece")
	game.shield_open = false
	hit_center(game)
	check(game.last_sfx == "shield", "escudo: suena el bloqueo")
	game.shield_open = true
	hit_center(game)
	check(game.status == "dying" and game.last_sfx == "explosion" and game.shake >= game.SHAKE_DEATH - 0.01, "muerte: explosión y sacudida fuerte")
	var vguard := 0
	while game.status == "dying" and vguard < 300:
		vguard += 1
		game._process(1.0 / 60.0)
	check(game.status == "win" and game.last_sfx == "victory", "victoria: suena el jingle")
	fresh(game, 1, 0)
	var wall0: Dictionary = game.walls[0]
	for k in 2:
		wall0["center"] = game.LINE_Y + 200.0
		game.bullet = {"x":float(wall0["x"]) - 8.0, "y":game.LINE_Y, "speed":660.0, "damage":1, "pierce":0, "ignored":[]}
		game.move_bullet(0.033)
		check(game.last_sfx == ("wall_hit" if k == 0 else "wall_break"), "muro: impacto %d suena %s" % [k + 1, game.last_sfx])
	check(game.shake > 0.0 and game.hitstop_time > 0.0, "muro destruido: sacudida y hit-stop")
	fresh(game, 1, 0)
	game.reload_weapon()
	check(game.last_sfx == "reload", "recarga: suena al empezar")
	for i in 90:
		game._process(1.0 / 60.0)
	check(game.last_sfx == "reload_done", "recarga: suena al terminar")
	fresh(game, 1, 1)
	game.special()
	check(game.last_sfx == "ability", "habilidad: suena al activarse")
	game.lose_stage()
	check(game.last_sfx == "game_over", "game over: suena el jingle")
	game.toggle_sound()
	check(not game.sound_enabled and game.sound_button.text.ends_with("NO"), "botón SONIDO desactiva el sonido")
	var muted: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(muted)
	await process_frame
	check(not muted.sound_enabled, "el sonido desactivado se guarda y se carga")
	muted.queue_free()
	game.play_sfx("buy")
	var any_playing := false
	for player in game.sfx_players:
		if player.playing:
			any_playing = true
	check(not any_playing, "sin sonido no se reproduce nada")
	game.toggle_sound()
	check(game.sound_enabled, "botón SONIDO lo vuelve a activar")

	# --- Interfaz Guerra Fría: menú, expediente, HUD y medallas ---
	game.go_menu()
	check(game.status == "menu" and game.overlay_logo.visible and not game.overlay_title.visible, "menú: placa WALLSHOT sobre el búnker")
	await process_frame
	game.level = 2
	game.unlocked = maxi(game.unlocked, 2)
	game.overlay_start.pressed.emit()
	check(game.status == "map" and game.world_map.visible and game.world_map.current_level() == 2 and not game.overlay_panel.visible, "JUGAR desde el menú abre el mapa sobre la etapa actual")
	game._unhandled_input(key(KEY_ENTER))
	check(game.status == "briefing" and game.dossier.visible and not game.world_map.visible, "ENTER en el mapa abre el expediente")
	game.fire()
	check(game.bullet.is_empty() and game.shots == 0, "no se dispara durante el expediente")
	for i in 5:
		game._process(1.0 / 60.0)
		await process_frame # dibuja el expediente a medio escribir
	check(game.briefing_chars() > 0 and game.briefing_chars() < game.dossier_total_chars(), "el expediente se escribe progresivamente")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	game._unhandled_input(space)
	check(game.status == "briefing" and game.briefing_chars() >= game.dossier_total_chars(), "primer ESPACIO completa el texto")
	await process_frame
	game._unhandled_input(space)
	check(game.status == "play" and not game.dossier.visible and game.shots == 0, "segundo ESPACIO empieza el nivel sin disparar")
	game.start_stage()
	check(game.status == "play", "reintentar el mismo nivel no repite el expediente")
	var lines: Array = game.dossier_lines()
	check(lines[1] == "JEFE DE ARGENTINA" and lines[0] == "EXPEDIENTE 02" and lines[2] == "Zona: Argentina", "expediente con los datos del objetivo")
	for lvl in [1, 3, 4, 5]:
		game.level = lvl
		game.briefed_level = 0
		game.start_stage()
		game.briefing_time = 99.0
		await process_frame
		game.begin_stage()
	check(true, "expediente dibujado en los 5 niveles sin errores")
	fresh(game, 1, 2)
	var visible_ammo := 0
	for slot in game.ammo_slots:
		if slot.visible:
			visible_ammo += 1
	check(visible_ammo == 14 and game.ammo_slots[0].texture == game.UI_TEX["bullet_full"], "HUD: 14 balas del rifle, todas llenas")
	game.fire()
	game.bullet.clear()
	check(game.ammo_slots[13].texture == game.UI_TEX["bullet_spent"] and game.ammo_slots[12].texture == game.UI_TEX["bullet_full"], "HUD: la bala disparada aparece gastada")
	var reload_visible := 0
	for slot in game.reload_slots:
		if slot.visible:
			reload_visible += 1
	check(reload_visible == game.reloads_left, "HUD: un cartucho plateado por cargador de reserva")
	fresh(game, 1, 0)
	game.walls.clear()
	game.shots = 1
	game.total_shots = 1
	last_target(game)
	hit_center(game)
	var lit := 0
	for medal in game.overlay_medals:
		if medal.modulate == Color.WHITE:
			lit += 1
	check(game.status == "win" and game.overlay_medals[0].get_parent().visible and lit == int(game.stars["sudamerica-1"]), "victoria: medallas encendidas según estrellas (%d)" % lit)
	game.stars["sudamerica-1"] = 3
	game.refresh_ui()
	check(game.level_box.get_item_icon(0) == game.MEDALS_SMALL[2], "selector de nivel: medalla de oro con 3 estrellas")
	game.lose_stage()
	check(not game.overlay_medals[0].get_parent().visible and game.overlay_title.visible, "game over: sin medallas")
	# Recargar no debe borrar los disparos del nivel: 8 + 1 balas son 1 estrella y sin bonus de munición.
	fresh(game, 1, 0)
	game.walls.clear()
	for i in 8:
		game.fire()
		game.bullet.clear()
	game.reload_weapon()
	game.reload_time = 0.001
	game._process(0.01)
	game.fire()
	game.bullet.clear()
	var coins_pre: int = game.coins
	last_target(game)
	hit_center(game)
	lit = 0
	for medal in game.overlay_medals:
		if medal.modulate == Color.WHITE:
			lit += 1
	check(game.status == "win" and game.shots == 1 and game.total_shots == 9 and lit == 1, "victoria tras recargar: cuenta los 9 disparos (1 estrella)")
	check(game.coins - coins_pre == 110 + 80 + 3 * 40, "victoria tras recargar: sin bonus por balas no disparadas (3 blancos)")
	# Comprar o cambiar de arma durante el expediente recalcula las habilidades del nivel.
	game.level = 2
	game.briefed_level = 0
	game.equipped = 0
	game.start_stage()
	var no_ability: bool = game.abilities_left == 0
	game.choose_weapon(1)
	check(game.status == "briefing" and no_ability and game.abilities_left == 2, "cambio de arma en el expediente: habilidades del arma nueva")
	game.begin_stage()
	var styled := game.fire_button.get_theme_stylebox("normal") is StyleBoxTexture
	check(styled, "botones con la textura metálica del tema")

	# --- Música por pantalla, bucle con fundido cruzado y silencio ---
	var music_ok := true
	for track in game.MUSIC:
		var stream: AudioStream = game.MUSIC[track]["stream"]
		if stream == null or stream.get_length() <= 5.0:
			music_ok = false
			print("   música inválida: ", track)
	check(music_ok and game.MUSIC.size() == 7, "los 7 temas cargan y tienen duración")
	game.sound_enabled = true
	game.go_menu()
	game._process(1.0 / 60.0)
	check(game.music_track == "menu", "menú: suena el tema del menú")
	game.level = 4
	game.briefed_level = 0
	game.start_stage()
	game._process(1.0 / 60.0)
	check(game.music_track == "briefing", "expediente: suena la presentación del jefe")
	var expected := {1:"levels_a", 3:"levels_a", 4:"levels_b", 5:"boss"}
	for lvl in expected:
		fresh(game, lvl, 0)
		game._process(1.0 / 60.0)
		check(game.music_track == expected[lvl], "nivel %d: suena %s" % [lvl, expected[lvl]])
	var active: AudioStreamPlayer = game.music_players[game.music_active]
	var stream_before: AudioStream = active.stream
	game.start_stage() # reintentar: mismo tema, no debe reiniciarse
	game._process(1.0 / 60.0)
	check(game.music_players[game.music_active] == active and active.stream == stream_before, "reintentar no reinicia la música")
	# Bucle: al acercarse al final, el tema vuelve a empezar en el otro reproductor con fundido.
	for i in 60:
		game._process(1.0 / 60.0) # termina el fundido de entrada
		await process_frame
	var length: float = active.stream.get_length()
	active.seek(length - 0.5)
	await process_frame
	game._process(1.0 / 60.0)
	var next_player: AudioStreamPlayer = game.music_players[1 - game.music_players.find(active)]
	check(game.music_looping and next_player.playing and next_player.stream == stream_before and next_player.get_playback_position() < 1.0, "cerca del final, el tema vuelve a empezar con fundido cruzado")
	game.toggle_sound()
	var any_music := false
	for player in game.music_players:
		if player.playing:
			any_music = true
	check(not any_music and game.music_track == "", "SONIDO desactivado también calla la música")
	game.toggle_sound()
	game._process(1.0 / 60.0)
	check(game.music_track == "boss", "al reactivar el sonido vuelve la música de la pantalla")
	game.walls.clear()
	game.enemy_hp = 1
	game.shield_open = true
	hit_center(game)
	var mguard := 0
	while game.status == "dying" and mguard < 300:
		mguard += 1
		game._process(1.0 / 60.0)
	game._process(1.0 / 60.0)
	check(game.music_track == "victory", "victoria: suena el tema de victoria")
	game.lose_stage()
	game._process(1.0 / 60.0)
	check(game.music_track == "game_over", "game over: suena su tema")
	# Cambios rápidos de pantalla: el fundido de salida pendiente no debe apagar el tema nuevo.
	game.go_menu()
	game._process(1.0 / 60.0)
	game.level = 2
	game.briefed_level = 0
	game.start_stage()
	game._process(1.0 / 60.0)
	game.begin_stage()
	game._process(1.0 / 60.0)
	for i in 50:
		game._process(1.0 / 60.0)
		await process_frame
	check(game.music_players[game.music_active].playing and game.music_track == "levels_a", "cambios rápidos de pantalla no dejan la música apagada")
	game.quitting = true # lo que hace quit_cleanly() al cerrar la ventana (sin salir de verdad)
	game.stop_music()
	game._process(1.0 / 60.0)
	check(game.music_track == "" and not game.music_players[0].playing and not game.music_players[1].playing, "al cerrar, la música no vuelve a arrancar")
	game.quitting = false

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
	check(game.total_shots == 16 and game.overlay_message.text.contains("Disparos: 16"), "GAME OVER informa los 16 disparos del nivel")

	# --- Partida completa automática niveles 1..5 con el plasma ---
	game.unlocked = 1
	game.coins = 0
	game.stars.clear() # la partida guardada del jugador puede traer medallas propias
	fresh(game, 1, 3)
	var cleared := 0
	for lvl in range(1, game.STAGES.size() + 1):
		var attempts := 0
		while attempts < 40:
			attempts += 1
			game.level = lvl
			game.start_stage()
			game.begin_stage()
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
			check(game.unlocked >= mini(game.STAGES.size(), lvl + 1), "nivel %d desbloquea el siguiente" % lvl)
			check(game.overlay_start.text == "CONTINUAR" and not game.overlay_menu.visible, "victoria: botón CONTINUAR")
			if lvl == game.last_stage_of(0):
				# Fin del Mundo 1: CONTINUAR lleva al mapa del Mundo 2, sobre su primera etapa.
				game.overlay_start.pressed.emit()
				check(game.status == "map" and game.world_map.world["id"] == "asia" and game.world_map.current_level() == lvl + 1 and game.world_map.has_prev_world, "fin del Mundo 1: CONTINUAR abre el mapa de Asia")
	check(game.coins > 0 and game.stars.size() == cleared, "monedas y estrellas otorgadas")
	game.overlay_start.pressed.emit()
	var all_open := true
	for i in game.world_map.node_count():
		all_open = all_open and game.world_map.is_open(i)
	check(game.status == "map" and game.world_map.current_level() == game.STAGES.size() and all_open and not game.world_map.has_next_world, "tras la última etapa, CONTINUAR vuelve al mapa con todo abierto")

	# --- Mapa del mundo ---
	game.unlocked = 2
	game.level = 1
	game.open_map()
	var wm: Control = game.world_map
	check(game.status == "map" and wm.visible and wm.current_level() == 1 and wm.agent_pos == wm.node_pos(0), "mapa: el agente empieza sobre la etapa actual")
	check(game.desired_music() == "menu", "mapa: suena el tema del menú")
	check(game.restart_button.disabled and game.fire_button.disabled, "mapa: REINICIAR y DISPARAR desactivados")
	var ui_hidden := true
	for control in game.combat_ui:
		ui_hidden = ui_hidden and not control.visible
	check(ui_hidden and wm.size == Vector2(1000, 650), "mapa: pantalla completa, sin la barra de combate")
	check(wm.node_label(0) == "Chile" and wm.node_label(4) == "Cuba", "mapa: puntos de Sudamérica")
	game._unhandled_input(key(KEY_RIGHT))
	check(wm.walking() and wm.cursor == 1, "mapa: → camina hacia la etapa siguiente")
	game._unhandled_input(key(KEY_ENTER))
	check(game.status == "map", "mapa: no se entra en una etapa mientras camina")
	for i in 120:
		wm._process(1.0 / 60.0)
	check(not wm.walking() and wm.agent_pos.is_equal_approx(wm.node_pos(1)), "mapa: llega al punto siguiente siguiendo el camino")
	game._unhandled_input(key(KEY_RIGHT))
	check(not wm.walking() and wm.cursor == 1, "mapa: no avanza hacia una etapa bloqueada")
	check(wm.facing == 1.0, "mapa: el agente mira a la derecha al avanzar")
	game._unhandled_input(key(KEY_LEFT))
	check(wm.walking() and wm.cursor == 0, "mapa: ← vuelve a la etapa anterior")
	for i in 120:
		wm._process(1.0 / 60.0)
	check(wm.facing == -1.0, "mapa: el agente se voltea al volver hacia la izquierda")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = wm.node_pos(1)
	game._unhandled_input(click)
	check(wm.walking() and wm.cursor == 1, "mapa: clic en un punto abierto camina hasta él")
	for i in 120:
		wm._process(1.0 / 60.0)
	await process_frame # dibuja el mapa
	game._unhandled_input(click)
	check(game.status == "briefing" and game.level == 2, "mapa: clic en el punto actual entra en la etapa")
	check(game.combat_ui.all(func(c): return c.visible), "al entrar en la etapa vuelve la barra de combate")
	game.begin_stage()
	game.open_map()
	game._unhandled_input(key(KEY_ESCAPE))
	check(game.status == "menu" and not wm.visible, "mapa: ESC vuelve al menú")
	game.unlocked = 5
	game.lose_stage()
	game.overlay_menu.pressed.emit()
	check(game.status == "map" and wm.visible, "game over: VOLVER AL MAPA")
	# La ruta Argentina -> Colombia sube: ↑ avanza por dirección y → también, como respaldo.
	game.level = 2
	game.open_map()
	game._unhandled_input(key(KEY_UP))
	check(wm.walking() and wm.cursor == 2, "mapa: ↑ sigue la ruta hacia el norte")
	for i in 300:
		wm._process(1.0 / 60.0)
	game._unhandled_input(key(KEY_RIGHT))
	check(wm.walking() and wm.cursor == 3, "mapa: → avanza aunque la ruta no vaya a la derecha")
	wm.enter_button.pressed.emit()
	check(game.status == "map", "mapa: ENTRAR desactivado mientras camina")
	for i in 300:
		wm._process(1.0 / 60.0)
	wm.enter_button.pressed.emit()
	check(game.status == "briefing" and game.level == 4, "mapa: botón ENTRAR entra en la etapa")
	game.begin_stage()
	game.open_map()
	wm.menu_button.pressed.emit()
	check(game.status == "menu", "mapa: botón MENÚ PRINCIPAL")

	# --- Cambio de mundo: Asia se abre al ganar Cuba ---
	game.unlocked = 5
	game.level = 5
	game.open_map()
	game._unhandled_input(key(KEY_RIGHT))
	check(not wm.has_next_world and wm.world["id"] == "sudamerica", "mapa: Asia bloqueada hasta ganar Cuba")
	game.unlocked = 6
	game.open_map()
	game._unhandled_input(key(KEY_RIGHT))
	check(game.status == "map" and wm.world["id"] == "asia" and wm.current_level() == 6, "mapa: → desde Cuba pasa a Asia, a China")
	await process_frame # dibuja el mapa de Asia (vista recortada)
	game._unhandled_input(key(KEY_LEFT))
	check(wm.world["id"] == "sudamerica" and wm.current_level() == 5, "mapa: ← desde China vuelve a Sudamérica, a Cuba")
	wm.next_world_button.pressed.emit()
	check(wm.world["id"] == "asia" and wm.current_level() == 6, "mapa: botón MUNDO ►")
	var view: Rect2 = wm.view_rect()
	var inside := true
	for i in wm.node_count():
		inside = inside and Rect2(0, 0, wm.MAP_SIZE, wm.MAP_SIZE).has_point(wm.node_pos(i))
	check(view.size.x < 1448.0 and inside, "mapa de Asia: vista recortada con todos los puntos dentro")
	game.unlocked = 10
	game.level = 9
	game.open_map()
	game._unhandled_input(key(KEY_RIGHT))
	for i in 600:
		wm._process(1.0 / 60.0)
	check(wm.cursor == 4 and wm.agent_pos.is_equal_approx(wm.node_pos(4)), "mapa de Asia: de Laos a Camboya pasando por el cruce")
	game._unhandled_input(key(KEY_LEFT))
	check(wm.walking() and wm.cursor == 3, "mapa de Asia: ← desde Camboya vuelve a Laos")
	game.unlocked = 5
	game.go_menu()

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

	# --- Partida guardada de la versión 1: medallas por número de nivel ---
	var legacy_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({"version":1, "coins":10, "unlocked":4, "level":3, "stars":{"1":2, "3":3, "99":1, "etapa-borrada":3}}))
	legacy_file.close()
	var legacy: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(legacy)
	await process_frame
	check(legacy.stars.get("sudamerica-1") == 2 and legacy.stars.get("sudamerica-3") == 3 and legacy.unlocked == 4 and legacy.level == 3 and legacy.stars.size() == 2, "partida v1: medallas convertidas a id de etapa; las de etapas inexistentes se descartan")
	legacy.queue_free()

	# --- Render: forzar varios frames reales con partículas y aviso ---
	game.spawn_particles(Vector2(500, 200), Color.WHITE, 50)
	game.notify("TEST")
	for i in 30:
		await process_frame
	check(true, "render de frames sin errores")
