# Auditoría técnica — WALLSHOT (Godot)

**Fecha:** 2026-10-09
**Motor de validación:** Godot Engine v4.7.2.stable.official (ed1daf0bf), Windows 11, `--headless`
**Alcance:** `project.godot`, `scenes/main.tscn`, `scripts/main.gd`, `assets/*.png` y `*.import`, `README.md`

---

## 1. Resumen ejecutivo

**Estado inicial:** el proyecto **no arrancaba**. `scripts/main.gd` no compilaba porque llamaba dos veces a `spawn_particles()` (líneas 326 y 345), que no existía. La corrección propuesta anteriormente (`spawn_particles()` + `update_particles()`) **nunca llegó al archivo**: ninguna de las dos funciones existía y no había ninguna llamada a `update_particles()`. Por eso la escena principal no cargaba.

**Estado final:** el proyecto abre en el editor y se ejecuta sin errores ni advertencias en Godot 4.7.2. Una batería automatizada de 38 pruebas de juego pasa por completo. Cubre partículas, colisiones, perforación, escudos, munición y Game Over, una campaña completa del nivel 1 al 5, guardado y compra de armas.

**Principales riesgos restantes:**
- Toda la lógica está en un único script de unas 540 líneas.
- No hay controles táctiles nativos ni configuración de exportación móvil.
- El nivel 4 es mucho más difícil si no se destruyen primero los muros destructibles.
- No se hizo una prueba visual con ventana real: el entorno era headless.

El proyecto consta de un único script (`main.gd`), sobre un `Control` raíz que dibuja todo en `_draw()`. No hay recursos `.tres`, autoloads, mapa de entradas ni `export_presets.cfg`.

---

## 2. Hallazgos

| ID | Severidad | Archivo | Línea / función | Causa | Consecuencia | Corrección aplicada |
|----|-----------|---------|-----------------|-------|--------------|---------------------|
| H-01 | **Crítico** | `scripts/main.gd` | `move_bullet()` (orig. 326, 345) | Se llamaba a `spawn_particles()`, que no estaba implementada. | `Parse Error: Function "spawn_particles()" not found in base self`. El script no cargaba y el juego no iniciaba. | Se implementó `spawn_particles(origin, color, count)` (l. 380): velocidad radial aleatoria, vida de 0,35–0,75 s y tope de `MAX_PARTICLES = 240`. |
| H-02 | **Alto** | `scripts/main.gd` | `_process()` / `update_particles()` | No existía actualización de partículas y nadie limpiaba el array `particles`. | Aunque compilara, las partículas quedarían congeladas y acumulándose indefinidamente (fuga de memoria y de tiempo de dibujado). | Se implementó `update_particles(dt)` (l. 388): gravedad de 520 px/s², integración con `delta` y eliminación en recorrido inverso. Se llama en cada `_process` aunque no se esté jugando, para que los efectos de victoria terminen. En `_draw` las partículas se centran y se desvanecen según la vida restante. |
| H-03 | **Alto** | `scripts/main.gd` | `move_bullet()` (orig. 340–356) | La colisión con el enemigo se evaluaba solo al llegar a `x >= 897`, con un margen vertical fijo de ±56 px igual para todos los enemigos. | Un enemigo móvil recibía daño al alcanzar su X aunque la bala no lo tocara visualmente: el drone mide ±32 px de alto y recibía impactos a ±56. Además, la bala desaparecía en x = 897 aunque fallara. | Hitbox real por enemigo (clave `"hit"` en `ENEMIES`, l. 25–30, ajustada a `draw_enemy()`) y `enemy_hitbox()` (l. 376). Ahora se hace una prueba de intersección entre el barrido horizontal de la bala (radio 5) y el rectángulo del enemigo en su posición actual. Si falla, la bala continúa hasta salir de la pantalla y se informa «EL ENEMIGO ESQUIVÓ LA BALA». |
| H-04 | **Medio** | `scripts/main.gd` | `build_ui()` / `make_button()` | Los `Button` y `OptionButton` tomaban el foco al pulsarlos con el ratón. | Tras pulsar REINICIAR o MENÚ, la tecla ESPACIO activaba ese botón en lugar de disparar: reiniciaba el nivel o volvía al menú. Con un selector enfocado, ESPACIO abría el desplegable. | `focus_mode = FOCUS_NONE` en los botones de la barra y en los selectores (l. 109, 117, 147). Los botones del overlay mantienen el foco para conservar la navegación por teclado. |
| H-05 | **Medio** | `scripts/main.gd` | `_draw()` (orig. 433–437) | Los avisos (`notify()`) solo se copiaban al `tooltip_text` del HUD, y además en cada fotograma. | Los avisos «RECARGANDO…», «MURO DESTRUIDO», «ESCUDO BLOQUEÓ…», «Monedas insuficientes», etc. no se veían. | Se dibujan con `draw_string()` centrado sobre el escenario, con desvanecimiento (l. 483). |
| H-06 | **Medio** | `scripts/main.gd` | `draw_wall_rect()` / `_ready()` | `draw_texture_rect_region` pedía una región de hasta 3× el tamaño de la textura (554 px), con la repetición de textura desactivada por defecto. | Los muros altos mostraban el borde del sprite estirado en lugar del mosaico de ladrillos que indica el comentario original. | `texture_repeat = TEXTURE_REPEAT_ENABLED` en el `Control` raíz (l. 76). No afecta a los demás sprites, que se dibujan con UV 0..1 y filtro *nearest*. |
| H-07 | Bajo | `scripts/main.gd` | `build_ui()` (orig. 78) | `set_anchors_and_offsets_preset(PRESET_TOP_WIDE)` seguido de una asignación manual de `size`. | Advertencia en tiempo de ejecución: «Nodes with non-equal opposite anchors will have their size overridden». La barra podía acabar con un ancho distinto del previsto. | Se eliminó el preset, de modo que se aplican la posición y el tamaño definidos en el código. |
| H-08 | Bajo | `scripts/main.gd` | `_draw()` | La bala se dibujaba siempre en `LINE_Y`, sin usar `bullet["y"]`. | Sin efecto visible hoy, pero inconsistente con la posición usada en las colisiones. | Se usa `bullet["y"]` y `BULLET_RADIUS`. |
| H-09 | Bajo | `scripts/main.gd` | varias | Uso de `max()` y `min()` con resultado `Variant` asignado a variables tipadas, y sangría irregular en `else:` (orig. 350–351). | Advertencias de tipado y menor legibilidad. | Se sustituyeron por `maxi`, `maxf` y `minf`. La sangría quedó corregida al reescribir el bloque. |
| H-10 | Bajo | `scripts/main.gd` | `move_bullet()` | Las partículas de impacto en un muro se generaban en `wall.x`, aunque la bala hubiera entrado desde otra posición. | Efecto visual desplazado. | Se generan en el punto de entrada `max(from_x, wall.x)`. |

### Revisado y sin incidencias

- **Rutas de recursos:** las 5 texturas (`wall`, `pistol`, `shotgun`, `plasma`, `enemy`) existen, son PNG válidos y tienen su `.import`. La escena principal `res://scenes/main.tscn` y el script con UID son válidos.
- **`project.godot`:** es compatible con 4.7 (renderizador `gl_compatibility`, `stretch canvas_items`, filtro *nearest* para pixel art).
- **Señales:** las conexiones de `pressed` y `item_selected` son correctas. El intercambio `start_stage`/`next_stage` del botón del overlay se protege con `is_connected` en todos los caminos.
- **Guardado:** `load_game()` valida tipos, rangos y armas compradas. La validación de JSON es robusta.

---

## 3. Pruebas

| # | Prueba | Resultado |
|---|--------|-----------|
| P1 | `godot --headless --path . --editor --quit` (estado original) | **Falló** y reprodujo el error: `Parse Error: Function "spawn_particles()" not found` en `main.gd:326` y `:345`. |
| P2 | `godot --headless --path . --editor --quit` (tras las correcciones) | **Aprobada:** exit 0, sin errores ni advertencias. |
| P3 | `godot --headless --path . --quit-after 120` (tras las correcciones) | **Aprobada:** exit 0. La primera pasada mostró la advertencia H-07, que se corrigió. La segunda salió limpia. |
| P4 | Batería automatizada de juego (script `SceneTree` externo, ejecutado con `--script`) | **Aprobada: 38/38.** |

**P4 cubre:**
- Creación, movimiento, expiración y tope de partículas.
- El drone desplazado 50 px no recibe daño; la bala fallada sale de la pantalla y se destruye; un impacto centrado gana el nivel.
- El escudo cerrado bloquea el disparo sin causar daño.
- **Antitunelado:** el rifle a 1250 px/s con dt = 0,033 (41 px por fotograma) no atraviesa un muro de 31 px.
- El plasma prepara doble perforación y la bala sigue tras el muro; un muro destructible se rompe en 2 impactos; la habilidad de tiempo lento se activa.
- Munición, auto-recarga y Game Over: se consumen 8 + 8 balas y se pierde.
- Campaña completa del nivel 1 al 5 con un bot predictivo: cada nivel se completa, desbloquea el siguiente, el botón cambia a «SIGUIENTE NIVEL» y tras el nivel 5 se vuelve al 1.
- Monedas y estrellas otorgadas, persistencia guardar/cargar, compra rechazada por falta de monedas, compra correcta y 30 fotogramas reales de render sin errores.

**Notas sobre las pruebas:**
- Antes de las pruebas no existía `user://wallshot_save.json` (`%APPDATA%\Godot\app_userdata\WALLSHOT Godot\`). El archivo que crearon las pruebas se eliminó al terminar.
- El script de pruebas no se añadió al proyecto, para no meter archivos ajenos al juego.

**No se pudieron realizar:**
- Prueba visual con ventana y entrada real de ratón y teclado: el entorno era headless. Las correcciones visuales (H-05, H-06) se validaron por ejecución sin errores, no por inspección visual.
- Medición de FPS en hardware real o en móviles.
- Exportación a Android o iOS: no hay presets y no se solicitó.

---

## 4. Estado final

### Errores corregidos
H-01 a H-10, todos.

### Problemas pendientes (no bloqueantes)
1. **Equilibrio del nivel 4:** con los 4 muros intactos, la línea de tiro queda libre en todos a la vez solo el ~1,2 % del tiempo, y teniendo en cuenta el tiempo de vuelo apenas se obtienen disparos limpios. En las pruebas, un bot que solo disparaba en ventanas limpias no disparó ni una vez en 100 s; ganó en cuanto destruyó primero los muros 0 y 2. El nivel es completable, pero exige esa estrategia y el juego no la comunica. No se cambió porque sería un ajuste de diseño.
2. ~~**Sprite compartido:** el nivel 3 (Skullbit) y el nivel 5 (Boss Retro Rojo) usan el mismo sprite (`enemy.png`).~~ Resuelto en la sección 4 bis.
3. **Barra de vida fija:** la barra de vida del enemigo está fija en y = 118 y no sigue al enemigo móvil. Es cosmético.
4. **Emoji del selector:** el «🔒» del selector de niveles depende de que el sistema tenga una fuente con emoji. Con la fuente por defecto puede verse como un cuadrado.
5. **README desactualizado:** indica «Godot 4.3 o posterior» y una carpeta `WALLSHOT_Godot`, mientras que el proyecto declara la característica 4.7.
6. **`.godot/` sin ignorar:** la carpeta `.godot/` (caché de importación) no está en un `.gitignore` y aparece como no rastreada en git.

### Funcionalidades verificadas (ejecución automatizada)
- Carga y ejecución del proyecto.
- Disparo, velocidad, dirección y destrucción de proyectiles; antitunelado.
- Colisión con muros, muros destructibles, perforación simple y doble.
- Hitbox real de enemigos móviles; escudos; vida; victoria.
- Munición, recarga, cargadores y Game Over.
- Habilidad de tiempo lento.
- Progresión: desbloqueo, monedas, puntuación, estrellas y ciclo de vuelta al nivel 1.
- Compra y equipamiento de armas.
- Guardado y carga.
- Partículas: creación, física, expiración y tope.

### Funcionalidades no verificadas
- Apariencia visual real (mosaico de muros, avisos, overlay) y su legibilidad.
- Entrada real de ratón y teclado, incluido el comportamiento de foco corregido en H-04 (validado solo por código).
- Rendimiento en FPS, escalado en otras resoluciones y comportamiento en dispositivos móviles.

---

## 4 bis. Integración de nuevos jefes (posterior a la auditoría)

| Nivel | Antes | Ahora |
|-------|-------|-------|
| 2 | Drone dibujado por código | `enemy.png` (la bola roja). La hitbox se calcula a partir del sprite. |
| 3 | `enemy.png`, compartido con el nivel 5 | `level_3_boss.png` |
| 4 | Cuadrado dibujado por código | `level_4_boss.png` |
| 5 | `enemy.png`, compartido con el nivel 3 | `final_boss.png` (resuelve el pendiente n.º 2) |

**Cambios en el código:**
- Los nuevos PNG, y también `enemy.png`, `pistol.png` y `plasma.png` reexportados, vienen en lienzos de 325×350 con margen transparente.
- `sprite_region()` detecta el área opaca con `Image.get_used_rect()` y guarda el resultado en caché. Los sprites se dibujan recortados a esa área y escalados sin deformación: los jefes caben en una caja de 130 px y las armas mantienen el ancho que tenían antes.
- La hitbox de los jefes con sprite se calcula a partir del sprite visible: el 85 % de su tamaño dibujado. Los niveles 1 y 2 conservan la hitbox fija en `ENEMIES["hit"]`.
- Solo el nivel 1 (la diana) sigue dibujándose por código.
- No se cambiaron los nombres, la vida, el movimiento ni los escudos de los enemigos.

**Animación de dolor (nivel 3):**
- `level_3_boss_dolor.png` es un sprite sheet horizontal de 4 fotogramas (2172×724).
- Se reproduce una vez, a 12 fps (≈0,33 s), cada vez que un disparo daña al jefe. El escudo no la activa.
- Se configura en `HURT_ANIMATIONS`. Allí se guarda el rectángulo de la cara de cada fotograma, medido en el PNG, para alinearla con `level_3_boss.png`, porque la cara no está centrada igual en cada fotograma.
- El PNG contiene unos 35.000 píxeles semitransparentes sueltos que impiden detectar el borde automáticamente. A la escala del juego no se aprecian.
- Para añadir otro jefe basta con una entrada más en `HURT_ANIMATIONS`.

**Animación de muerte (nivel 3):**
- `level_3_boss_muerte.png` tiene 4 fotogramas: cara agrietada, estallido, explosión y humo.
- Se reproduce a 8 fps (0,5 s) al recibir el golpe final.
- El juego pasa al estado `dying`: la acción se congela como pausa dramática, no se puede disparar y la victoria, las monedas y el guardado se aplican al terminar. Después, el jefe ya no se dibuja detrás de la pantalla de victoria.
- Los fotogramas de esta hoja no tienen el mismo ancho, porque la explosión invade el hueco vecino. Por eso las regiones `src` son explícitas en `DEATH_ANIMATIONS`, y los fotogramas sin cara se anclan por su centro de masa.
- Si se pulsa REINICIAR o MENÚ durante la animación, el estado queda limpio. Los niveles sin animación de muerte siguen dando la victoria inmediata.

**Animaciones de dolor y muerte para los niveles 2, 4 y 5:**
- Se añadieron las hojas `enemy_*`, `level_4_boss_*` y `final_boss_*`, en sus variantes `_dolor` y `_muerte`, a `HURT_ANIMATIONS` y `DEATH_ANIMATIONS`.
- Las regiones de cada fotograma se tomaron de los huecos transparentes reales.
- Las anclas se calcularon automáticamente: se ajusta la silueta del sprite base sobre cada fotograma mediante correlación de máscaras alfa y se elige el mayor IoU. La escala se fija con el primer fotograma de cada hoja, para que el personaje no cambie de tamaño entre fotogramas.
- Si un fotograma no tiene un personaje reconocible (IoU < 0,6), se ancla por su centro de masa.
- Se verificó visualmente con vistas previas generadas con la misma fórmula que `draw_sheet_frame()`.
- Ahora solo el nivel 1 (la diana) carece de animaciones y da la victoria al instante.

**Animaciones de la pistola (`pistol_firing.png`, `pistol_reloading.png`):**
- Están en `WEAPON_ANIMATIONS`, indexadas por el campo `sprite` de `WEAPONS`, así que las usan la pistola básica y la pistola mejorada.
- El disparo se reproduce a 16 fps (0,25 s) y se mantiene el retroceso por código (`kick`).
- La recarga reparte sus 4 fotogramas a lo largo de `RELOAD_DURATION` (1,1 s, antes un literal repetido), sincronizada con la barra de recarga.
- `draw_sheet_frame()` recibe ahora el rectángulo destino, de modo que la misma rutina sirve para jefes y armas.
- Después se añadieron `shotgun_firing`/`shotgun_reloading` (rifle de precisión) y `plasma_firing`/`plasma_reloading` (cañón de plasma), con anclas calculadas igual. Ahora las cuatro armas tienen animación de disparo y de recarga.
- `shotgun.png` y `plasma.png` se reexportaron (lienzo de 260×280). El nuevo plasma es mucho más alargado, así que su ancho en pantalla (`GUN_WIDTHS[2]`) pasó de 98 a 140 px para mantener un tamaño visual parecido al anterior.

**Pruebas:** 108/108. Dieciséis cubren las armas: animación de disparo y de recarga en las cuatro. Además: Las animaciones de dolor y muerte se comprueban en los niveles 2–5, la victoria inmediata en el nivel 1, y hay dieciséis pruebas de los jefes con sprite:
- Usan su sprite y caben en la caja de 130 px.
- La hitbox queda dentro del sprite visible.
- Una bala que pasa por fuera no causa daño y un impacto centrado sí.

Además, el editor carga sin errores y la ejecución de 120 fotogramas pasa sin errores.

---

## 4 ter. Sonido, hit-stop y sacudida

- **Sonido:** 14 efectos retro sintetizados con `tools/sfx.py` (`assets/sfx/*.wav`, 256 KB en total). Cubren el disparo de cada arma, el impacto y la rotura de muros, el impacto al jefe, el bloqueo del escudo, la explosión, la recarga (inicio y fin), la habilidad, la compra, la victoria y el game over.
  - Se reproducen en un grupo de 8 voces, con una variación de tono de ±5 %.
  - El volumen relativo de cada efecto se ajusta en la tabla `SFX`.
  - Se pueden silenciar con la tecla M o el botón SONIDO. El ajuste se guarda (`"sound"` en el JSON de guardado; si un guardado antiguo no lo tiene, el sonido queda activado).
- **Hit-stop:** el juego se congela 0,06 s al dañar al jefe, 0,04 s al romper un muro y 0,12 s al matar al jefe.
- **Sacudida:** solo se desplaza el escenario, no la UI. Es de 5 px al impactar al jefe, 4 px al romper un muro y 11 px al matarlo (el desplazamiento real se limita a 8 px), y decae a 40 px/s. El fondo y el suelo se dibujan con 8 px de margen para que no aparezcan bordes vacíos. El aviso de texto no tiembla.
- **No verificado:** cómo suenan los efectos y cómo se ve la sacudida. Las pruebas comprueban la lógica, pero no la percepción.

**Pruebas:** 130/130. Veintidós son nuevas: los sonidos de cada evento, que el hit-stop congela y reanuda el juego, que la sacudida decae y que el sonido se puede silenciar y queda guardado. Las pruebas detienen ahora el audio antes de salir; si no, el servidor de audio retenía reproducciones y aparecían avisos de fugas al cerrar.

---

## 4 quater. Interfaz estilo Guerra Fría

- **Piezas de interfaz:** `tools/ui_slice.py` recorta las hojas de `assets/interface/` y las reduce con filtro BOX a su tamaño de uso, guardándolas en `assets/interface/game/`. También borra el texto «PLAY» incrustado en los botones, rellenando cada fila de la placa con su propio color. Los originales no se modifican.
- **Tema (`build_theme()`):**
  - Botones y desplegables con la chapa metálica en 4 estados, como StyleBoxTexture 9-slice, y letras doradas con contorno.
  - Paneles de victoria y game over con la chapa grande.
  - La zona de controles inferior va sobre la chapa pequeña.
- **HUD de fósforo:** balas llenas y gastadas según la munición del cargador, cargadores de reserva como balas plateadas y los datos en verde.
- **Menú:** el fondo del búnker con el mapa ocupa el escenario, con la placa WALLSHOT encima.
- **Expediente CLASIFICADO:** aparece al entrar en un nivel nuevo, ya sea desde el menú, en el siguiente nivel o con el selector. No se repite al reintentar.
  - Muestra la foto del objetivo, su nombre, una franja roja de amenaza por nivel y observaciones derivadas de sus estadísticas, con efecto máquina de escribir.
  - El primer clic o ESPACIO completa el texto y el segundo empieza el nivel.
  - Nuevo estado `briefing`.
- **Medallas:** en la victoria se muestran bronce, plata y oro, y las no conseguidas aparecen apagadas. En el selector de niveles, la medalla de la mejor marca sustituye al emoji 🔒/✓, que podía no verse.
- **Mira verde:** cuatro esquinas alrededor del área de impacto del objetivo durante la partida.
- **Verificado visualmente** con capturas en ventana real del menú, el expediente, la partida, la victoria y el game over.
- **Sin usar todavía:** el medidor de aguja (trae la aguja dibujada; habría que borrarla para animarla) y el marco verde grande.
- **Pendiente:** los originales de `assets/interface/*.png` (8 MB) entran en la exportación aunque el juego no los usa. Conviene moverlos a una carpeta con `.gdignore` o excluirlos en el preset de exportación.

**Pruebas:** 146/146. Dieciséis son nuevas y cubren la interfaz: menú, expediente (escritura, avance, que no se dispara durante él y que no se repite al reintentar), balas del HUD, medallas, iconos del selector y tema aplicado.

---

## 4 quinquies. Música

- **Temas:** 7 temas de `assets/music/` (MP3, 48 kHz, generados con Suno).
  - Volumen medido entre −14,3 y −16,2 LUFS, igualado con ±2 dB por tema en `MUSIC`.
  - La música va a −9 dB respecto a los efectos (`MUSIC_DB`).
- **Asignación:**

  | Pantalla | Tema | Reproducción |
  |---|---|---|
  | Menú | `principal_menu` | bucle |
  | Expediente | `boss_presentation` | bucle |
  | Niveles 1–3 | `levels_to_1_at_3` | bucle |
  | Nivel 4 | `levels_to_4_at_5` | bucle |
  | Nivel 5 | `final_boss` | bucle |
  | Victoria | `victory` | una vez |
  | Game over | `game_over` | una vez (72 s) |

- **Bucle con fundido cruzado:** los temas acaban con un desvanecimiento de 1–4 s, así que el bucle no usa el `loop` del stream. Se alternan dos `AudioStreamPlayer` y el tema vuelve a empezar `xfade` segundos antes de su final.
  - Cada reproductor tiene un único `Tween` activo, para que un fundido de salida pendiente no apague el tema nuevo si se cambia de pantalla rápido.
  - Reintentar el mismo nivel no reinicia el tema.
- **Cierre ordenado:** `NOTIFICATION_WM_CLOSE_REQUEST` → `quit_cleanly()` detiene el audio y espera 0,15 s antes de salir. Si no, el servidor de audio retenía la reproducción MP3 y Godot avisaba de recursos sin liberar. La marca `quitting` impide que `update_music()` vuelva a arrancar el tema durante esa espera.
  - Con `--quit-after`, que fuerza la salida sin pasar por la ventana, el aviso sigue apareciendo. Es propio de esa forma de cierre, no del juego.
- **No verificado:** cómo suena la mezcla real y lo perceptible que es el empalme del bucle. La lógica sí está probada, pero el oído no.

**Pruebas:** 161/161. Quince son nuevas: el tema de cada pantalla, que no se reinicie al reintentar, el bucle con fundido cruzado, el silencio y su reactivación, los cambios rápidos de pantalla y que la música no se rearranque al cerrar.

---

## 5. Preparación para móviles (análisis, sin cambios aplicados)

| Tema | Situación actual | Acción necesaria |
|------|------------------|------------------|
| Controles táctiles | Funcionan como clic emulado (`InputEventMouseButton`), porque `emulate_mouse_from_touch` está activo por defecto. Los botones de 112×40 px son pequeños para un dedo. | Manejar `InputEventScreenTouch` explícitamente y agrandar los botones de la barra a ≥ 48 dp. |
| Orientación | No está configurada. | `display/window/handheld/orientation = "landscape"` (o `sensor_landscape`). |
| Resoluciones y áreas seguras | Hay escalado `canvas_items` con base de 1000×650, pero `aspect` no está fijado y la UI usa coordenadas absolutas. | Fijar `window/stretch/aspect = "keep"` o `"expand"`, y respetar `DisplayServer.get_display_safe_area()` en la barra y el HUD (muesca del iPhone). |
| Pausa al perder el foco | No existe. | Manejar `NOTIFICATION_APPLICATION_FOCUS_OUT` y `NOTIFICATION_APPLICATION_PAUSED` para pausar y guardar. |
| Persistencia | `user://` es válido en Android e iOS. | Guardar también al pausar o cerrar (`NOTIFICATION_WM_CLOSE_REQUEST`). |
| Rendimiento | El renderizador `gl_compatibility` es adecuado para móviles y el dibujado es inmediato y ligero. `refresh_ui()` reconstruye los `OptionButton` en cada evento (no en cada fotograma). | Aceptable. Medir en un dispositivo de gama baja. |
| Exportación | No hay `export_presets.cfg`. | Instalar las plantillas de exportación 4.7.2 y configurar el SDK de Android, el keystore, y Xcode en macOS para iOS. |

---

## 6. Recomendaciones (priorizadas)

1. **(Alta)** Añadir un `.gitignore` con `.godot/` y versionar el estado actual antes de seguir con 7.0. El repositorio no tiene ningún commit todavía.
2. **(Alta)** Hacer una sesión de prueba manual con ventana (F5) para confirmar H-04, H-05 y H-06 visualmente.
3. **(Media)** Revisar el equilibrio del nivel 4 o comunicar al jugador la estrategia de romper los muros naranjas, por ejemplo con un aviso al empezar el nivel.
4. **(Media)** Dividir `main.gd` cuando empiece el desarrollo de 7.0: `Weapon`, `Wall`, `Enemy`, `SaveManager` (autoload) y `Hud` (escena). Así la lógica de juego queda separada del dibujado y de la UI. Hoy funciona, pero cada nueva mecánica aumentará el acoplamiento.
5. **(Media)** Convertir los diccionarios de `walls`, `bullet` y `particles` en clases ligeras (`class_name` / `RefCounted`) para tener tipado estático y autocompletado.
6. **(Media)** Aplicar los puntos de la sección 5 antes de la primera exportación móvil.
7. **(Baja)** Hacer que la barra de vida del enemigo siga su posición vertical, y sustituir el emoji 🔒 por texto o un icono.
8. **(Baja)** Actualizar el `README.md`: versión de Godot, nombre de la carpeta y la nota de que el proyecto ya se probó en 4.7.2.
9. **(Baja)** Incorporar la batería de pruebas al proyecto, por ejemplo en `tests/`, con GUT o con un `SceneTree` propio, para detectar regresiones en 7.0.
