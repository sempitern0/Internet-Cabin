# Internet Cabin — vertical slice navegable

Escena de arranque: `res://game/adventure/cabin_demo.tscn`. También se ejecuta con F6 desde el editor; `project.godot` usa esta escena como punto de entrada.

## Arquitectura y propiedad

| Responsabilidad | Dueño |
| --- | --- |
| Dibujo e input 2D, Theme, ShaderMaterial, BackBufferCopy | Godot |
| Rectángulos normalizados, hit testing, foco | `NucleusImageScreen` |
| Páginas, cambio de pantalla, flags de puerta | `NucleusAdventureSession` |
| Canal de efectos con backend Backbuffer | `NucleusScreenShaderStack` |
| Gráfico de vistas, textos y reglas del juego | `game/adventure/cabin_map.json` |
| Presentación, controles HUD y sincronización de targets | `game/adventure/cabin_demo.gd` |
| Zoom de respiración optativo | `game/adventure/breathing_camera.gd` |
| VHS original, discreto | `game/shaders/vhs_subtle.gdshader` |
| Accesibilidad/colores/fuente | `game/ui/internet_cabin_theme.tres` |

No se añaden Autoloads. No se reemplazan componentes de Nucleus. Las imágenes se cargan desde `assets/cabin` (1448 × 1086, 4:3). El contenido escala proporcionalmente dentro del aspecto fijo, también en 16:9 y ultrawide. Los hotspots permanecen sobre la imagen transformada; el HUD queda fuera de la capa VHS.

## Navegación

`cabin_map.json` contiene diez pantallas y el enrutamiento mediante IDs estables. Pantallas:
`overview_closed` / `overview_open` → `desk`, `window`, `back_wall`, `bed` y `door_closed` / `door_open`; desde el umbral `porch_closed` / `porch_open`.

El flag `door_open` guarda el estado global. `@overview` y `@interior_door` son aliases resueltos localmente por el juego, no rutas de archivo. En el futuro se pueden agregar más vistas sin introducir nuevas escenas físicas de Godot ni romper la semántica del mapa.

Para explorar: pulsa sobre los elementos de la imagen o usa la barra inferior con acciones explícitas. Flechas en el footer recorren las vistas para QA (modo prototipo, no navegación narrativa definitiva). Tab/teclado sobre los botones permite interacción sin localizar con precisión cada hotspot. Escape vuelve a la visión general.

Las pantallas de ordenador, bosque y cama contienen textos placeholder, no los menús finales. No hay aún sistema de PC empresarial, puzzle narrativo ni audio final.

## Estilo y accesibilidad

El tema se ha duplicado **por valor**, no derivado dinámicamente: conserva los StyleBox, estados hover/pressed/disabled, foco visible y tamaños de control de Nucleus, con paleta de madera oscuro/ámbar, y la fuente `HomeVideo-Regular.ttf` CC0 ya presente en el proyecto. No entregar archivos de la fuente fuera del repositorio.

El VHS es un shader propio inspirado en el lenguaje analógico de [VHS / Scanline Color Fuzz](https://godotshaders.com/shader/vhs-scanline-color-fuzz/) y no copia su fuente; se minimizan ruido de sombra, movimiento horizontal y scanlines. Se aplica mediante el backend `BACKBUFFER` de Nucleus; no degrada botones de la interfaz. El zoom respira entre 1.0025 y 1.0095 de escala a ~0,19 Hz y transforma la pantalla junto a sus hotspots. Puede desactivarse con «Respiración» y el VHS con el botón «VHS» para comodidad del jugador.

No se usa movimiento angular falso o desplazamiento de paralaje que rompa la geografía de escenas pintadas. El control de respiración se debería integrar después con los ajustes de accesibilidad globales del juego.

## Pruebas

1. Abrir Godot 4.7.2, importar recursos y pulsar F5.
2. Entrar a escritorio, ventana, pared trasera y cama; volver en cada caso.
3. Aproximarse a puerta cerrada, abrirla, cruzar al porche, cerrar desde fuera y volver a abrir; comprobar consistencia del flag global.
4. Alternar VHS y respiración; confirmar que hotspots siguen alineados, también con ventana redimensionada a 16:9, 4:3, vertical y ultrawide.
5. Ejecutar `python3 scripts/ci/check_cabin_images.py` y escena smoke `res://tests/smoke/internet_cabin_smoke.tscn`.
6. Comparar las imágenes de puerta desde dentro y desde fuera. Exigir continuidad visual; el script comprueba relaciones de pantalla pero no puede certificar el arte.

Las imágenes de los estados tienen detalles generados en distintos pases y deben aprobarse visualmente antes de producir el juego. La composición no pretende certificar inmersión, accesibilidad o rendimiento por sí sola.
