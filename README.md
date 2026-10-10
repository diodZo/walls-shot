# WALLSHOT - Godot 4

Proyecto nativo Godot 4 basado en las mecánicas de WALLSHOT 6.0 HTML5.

## Abrir
1. Instala Godot 4.7.2 (es la versión con la que se valida el proyecto).
2. Importa esta carpeta como proyecto (selecciona `project.godot`).
3. Ejecuta la escena principal con **F6** o el proyecto con **F5**.

## Controles
- Clic en campo de juego, barra espaciadora o botón DISPARAR: disparar.
- R: recargar.
- E: habilidad del arma.
- M o botón SONIDO: activar/desactivar el sonido (se guarda).
- Botones y menús: selección de armas, compra y selección de niveles.
- Mapa: flechas (o WASD) para caminar entre etapas, ENTER, ESPACIO o clic sobre el punto actual para entrar, clic en otro punto para ir hasta él y ESC para volver al menú. El botón MAPA abandona la etapa y vuelve al mapa.

## Incluido
- Cinco niveles, muros móviles y destructibles, sprite pixel art.
- Pistola, pistola mejorada, rifle de precisión y cañón de plasma, con animaciones de disparo y recarga.
- Balas con colisión continua horizontal.
- Cinco objetivos/enemigos, escudos y vida. Los jefes de los niveles 2–5 tienen animaciones de dolor y muerte.
- Economía, monedas, estrellas y guardado en `user://wallshot_save.json`.
- Recarga y pantallas de derrota/victoria.
- Efectos de sonido retro, congelación breve al impactar (hit-stop) y sacudida del escenario.

## Interfaz
Las hojas de arte originales están en `assets/interface/`. El juego usa las piezas ya recortadas y reducidas de `assets/interface/game/`, que se regeneran con:
```
python tools/ui_slice.py assets/interface
```
Si cambias una hoja manteniendo la disposición de las piezas, basta con volver a ejecutarlo.

## Música
Los temas de `assets/music/` (generados con Suno) suenan según la pantalla: menú, expediente, niveles 1–3, nivel 4, nivel 5 (jefe final), victoria y game over. Los temas en bucle vuelven a empezar con un fundido cruzado antes de su final. El volumen de cada tema y la duración del fundido se ajustan en la tabla `MUSIC` de `scripts/main.gd`; el volumen general de la música, en `MUSIC_DB`. La tecla M y el botón SONIDO silencian también la música.

## Efectos de sonido
Los `.wav` de `assets/sfx/` se generan con `python tools/sfx.py assets/sfx` (requiere numpy). Para usar un sonido propio, reemplaza el archivo con el mismo nombre; el volumen relativo de cada uno se ajusta en `SFX` (`scripts/main.gd`).

## Pruebas
```
godot --headless --path . --script res://tests/wallshot_test.gd
```
Termina con código 0 si todo pasa. Cubre colisiones, armas, escudos, munición, progresión, guardado, animaciones y una campaña completa del nivel 1 al 5 jugada por un bot. Las pruebas guardan una copia de la partida guardada al empezar y la restauran al terminar.

## Añadir animaciones (sprite sheets)
Las hojas son de fotogramas en horizontal (4 por defecto; indica otro número con `hoja.png:N`, p. ej. las de muerte de 5). Para integrar una nueva, calcula su alineación con el sprite base:
```
python tools/anchors.py assets <carpeta_salida> <base.png> <hoja1.png[:N]>[,<hoja2.png[:N]>]
```
Requiere numpy y Pillow. El script imprime los `Rect2` listos para pegar en `"hurt"` o `"death"` de la etapa (`scripts/stages.gd`) o en `WEAPON_ANIMATIONS` (`scripts/main.gd`) y genera una vista previa para comprobar la alineación.

## Importante
Este proyecto es una migración editable, no una conversión 1:1 de cada efecto audiovisual. El progreso `localStorage` del navegador no se importa automáticamente. Las exportaciones Android/iOS requieren configurar los SDK y plantillas de exportación correspondientes (para iOS: macOS/Xcode). Consulta `AUDITORIA_WALLSHOT.md` para el estado técnico y las tareas pendientes.

## Etapas
Cada etapa es una ficha en `scripts/stages.gd`: enemigo (nombre, vida, movimiento, escudo, sprite y animaciones), muros (posición, velocidad, recorrido, abertura, fase, resistencia y si se pueden romper), cargadores, música, color de fondo, zona y nivel de amenaza del expediente. El orden de la lista es el orden de juego; para añadir una etapa basta con otra entrada. Las pruebas validan que cada ficha tenga todos los campos.

## Mundos y mapa
El flujo es menú → mapa → expediente → etapa → mapa. El mapa ocupa toda la ventana: a la izquierda la imagen del mundo y a la derecha un panel con la etapa seleccionada (país, objetivo, estado, medallas) y los botones ENTRAR y MENÚ PRINCIPAL. La barra de combate se oculta mientras tanto.

Los mundos están en `WORLDS` (`scripts/stages.gd`). Cada uno tiene nombre, una imagen (`"background"`, que ya trae dibujados la ruta, los puntos y sus nombres), opcionalmente la parte de ella que se muestra (`"view"`, que se escala para caber en el cuadrado del mapa) y una lista de nodos con la etapa (`"stage"`), el nombre del punto (`"label"`), su centro y radio en píxeles de la imagen (`"pos"`, `"radius"`) y los recodos de la ruta desde el nodo anterior (`"via"`). Para añadir un continente: su imagen en `assets/` y otra entrada en `WORLDS` con las coordenadas medidas sobre la imagen.

Sobre los puntos de la imagen el juego solo dibuja su estado: anillo si está pendiente, medalla si está superada y candado si está bloqueada. El agente (`assets/player.png`) camina por la ruta y solo llega hasta la última etapa desbloqueada. Las medallas se guardan por el `"id"` de la etapa; las partidas de la versión anterior (por número de nivel) se convierten al cargar y las de etapas que ya no existen se descartan.

Mundo 1 (`assets/map_word_1.png`): Chile, Argentina, Colombia, Venezuela y Cuba. Argentina, Colombia y Venezuela tienen sus jefes (`assets/boss_*`); en Venezuela, al morir el primero entra el segundo (`"phases"` en la ficha). Chile es el entrenamiento: tres blancos seguidos, y con el 2.º y el 3.º se levanta un muro más (`"add_walls"` en `"phases"`). Cuba (Boss Retro Rojo) conserva el jefe provisional. En el mapa suena el tema del menú.

Mundo 2 (`assets/map_word_2.png`, se abre al ganar Cuba): China, Corea del Norte, Vietnam, Laos y Camboya. Al ganar la última etapa de un mundo, CONTINUAR lleva al mapa del siguiente; en el mapa se cambia de mundo con los botones ◄ MUNDO / MUNDO ► o avanzando más allá del último punto (retrocediendo antes del primero).

Si un jefe llega solo con sus hojas de dolor y muerte, su sprite base se crea a partir del primer fotograma (pose neutra) de la hoja de dolor:
```
python tools/base_from_sheet.py assets/korea_dolor.png assets/korea.png 5
```
