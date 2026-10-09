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

## Efectos de sonido
Los `.wav` de `assets/sfx/` se generan con `python tools/sfx.py assets/sfx` (requiere numpy). Para usar un sonido propio, reemplaza el archivo con el mismo nombre; el volumen relativo de cada uno se ajusta en `SFX` (`scripts/main.gd`).

## Pruebas
```
godot --headless --path . --script res://tests/wallshot_test.gd
```
Termina con código 0 si todo pasa. Cubre colisiones, armas, escudos, munición, progresión, guardado, animaciones y una campaña completa del nivel 1 al 5 jugada por un bot. Las pruebas guardan una copia de la partida guardada al empezar y la restauran al terminar.

## Añadir animaciones (sprite sheets)
Las hojas son de 4 fotogramas en horizontal. Para integrar una nueva, calcula su alineación con el sprite base:
```
python tools/anchors.py assets <carpeta_salida> <base.png> <hoja1.png>[,<hoja2.png>]
```
Requiere numpy y Pillow. El script imprime los `Rect2` listos para pegar en `HURT_ANIMATIONS`, `DEATH_ANIMATIONS` o `WEAPON_ANIMATIONS` (`scripts/main.gd`) y genera una vista previa para comprobar la alineación.

## Importante
Este proyecto es una migración editable, no una conversión 1:1 de cada efecto audiovisual. El progreso `localStorage` del navegador no se importa automáticamente. Las exportaciones Android/iOS requieren configurar los SDK y plantillas de exportación correspondientes (para iOS: macOS/Xcode). Consulta `AUDITORIA_WALLSHOT.md` para el estado técnico y las tareas pendientes.
