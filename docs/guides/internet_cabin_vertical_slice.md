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

Para explorar: mueve el ratón sobre los objetos; el cursor cambia a mano en los hotspots y aparece un texto contextual discreto. Haz clic para actuar o avanzar. El foco de hotspots de Nucleus sigue disponible mediante teclado y mando (direcciones + aceptar). Escape vuelve a la vista general. No hay barra de navegación ni botones de QA superpuestos a la escena.

Las pantallas de ordenador, bosque y cama contienen textos placeholder, no los menús finales. No hay aún sistema de PC empresarial, puzzle narrativo ni audio final.

## Estilo y accesibilidad

El tema se ha duplicado **por valor**, no derivado dinámicamente: conserva los StyleBox, estados hover/pressed/disabled, foco visible y tamaños de control de Nucleus, con paleta de madera oscuro/ámbar, y la fuente `HomeVideo-Regular.ttf` CC0 ya presente en el proyecto. No entregar archivos de la fuente fuera del repositorio.

El VHS es un shader propio inspirado en el lenguaje analógico de [VHS / Scanline Color Fuzz](https://godotshaders.com/shader/vhs-scanline-color-fuzz/) y no copia su fuente; se minimizan ruido de sombra, movimiento horizontal y scanlines. Se aplica mediante el backend `BACKBUFFER` de Nucleus solo a la imagen de la cabina. El HUD vive en un `CanvasLayer` por encima del render y no se ve afectado por los filtros. Su control tiene activación y un deslizador de intensidad (0–1). El zoom respiratorio utiliza una sinusoide continua con interpolación exponencial dependiente de delta, a ~0,115 Hz, sin saltos de actualización ni restablecimientos de fase al cambiar de vista. Se transforma la pantalla junto a sus hotspots. Se puede desactivar desde «Respiración» y el VHS desde «VHS». No afecta a la lógica del mapa.

No se usa movimiento angular falso o desplazamiento de paralaje que rompa la geografía de escenas pintadas. El control de respiración se debería integrar después con los ajustes de accesibilidad globales del juego.

## Pruebas

1. Abrir Godot 4.7.2, importar recursos y pulsar F5.
2. Entrar a escritorio, ventana, pared trasera y cama; volver en cada caso.
3. Aproximarse a puerta cerrada, abrirla, cruzar al porche, cerrar desde fuera y volver a abrir; comprobar consistencia del flag global.
4. Alternar VHS y respiración, variar el deslizador VHS de 0 a 1 y verificar su efecto; confirmar que hotspots siguen alineados, también con ventana redimensionada a 16:9, 4:3, vertical y ultrawide.
5. Ejecutar `python3 scripts/ci/check_cabin_images.py` y escena smoke `res://tests/smoke/internet_cabin_smoke.tscn`.
6. Comparar las imágenes de puerta desde dentro y desde fuera. Exigir continuidad visual; el script comprueba relaciones de pantalla pero no puede certificar el arte.

Las imágenes de los estados tienen detalles generados en distintos pases y deben aprobarse visualmente antes de producir el juego. La composición no pretende certificar inmersión, accesibilidad o rendimiento por sí sola.

## Verificación visual adicional

- Comprobar que HUD/controles permanecen visibles en el inicio y no están recortados por el aspecto 4:3.
- Comparar VHS a 0 y 1: deben verse variaciones en grano de sombras, pequeñas líneas y crominancia sin tapar hotspots.
- Desactivar la respiración mientras la cámara está ampliada: debe volver a escala 1 de forma gradual.
- Mover el ratón sobre escritorio, puerta, ventana y fondo vacío: mano en hotspots y flecha fuera.
- Mantener el texto contextual legible sobre diferentes exposiciones; no se debe convertir en barra de botones.

## Calibración VHS YUV y respiración (iteración actual)

El shader `game/shaders/vhs_subtle.gdshader` utiliza el algoritmo suministrado de desplazamiento de luminancia/crominancia, funciones `noise`, `rgb_to_yuv` y `yuv_to_rgb`, y `textureLod` para el desenfoque de color. Solo se añade `effect_strength` para mezclar imagen original y resultado sin romper la fórmula. La UI de intensidad controla **effect_strength**, no un uniforme inexistente llamado `intensity`.

Valores de partida: `effect_strength=0.55`, `color_offset_multiplier=0.004`, `black_offset_multiplier=0.1`, `color_offset=0.005`, `blur_amount=0.5`. Se conservan en `vhs_settings` entre cambios de pantalla. `colorLookup` permanece declarado como en la fuente, pero aún no realiza una LUT.

Respiración actual: desplazamiento vertical sinusoidal ±0,9 % de la altura del lienzo, frecuencia 0,135 Hz, interpolación exponencial de respuesta 5, y sobremargen estable del 3 % para ocultar bordes. No hay zoom pulsante: imagen y hotspots se mueven como un mismo Control, manteniendo la alineación.

## Revisión de máscaras interactivas

Se han ajustado las áreas de escritorio, monitor CRT, ventanas, estufa/entrada, cama y suelo mediante zonas más ajustadas y polígonos normalizados. La cámara ya no debe vibrar en zoom, sino desplazarse muy ligeramente arriba/abajo. Las máscaras de fuente están en `game/adventure/cabin_map.json`, en el campo `polygon` por pantalla; `NucleusScreenHotspot` realiza la intersección. Los rectángulos de retroceso se mantienen solo como bandas discretas junto al borde inferior. Se ha retirado el hotspot de cama no visible del plano general. Antes de dar por definitiva una máscara hay que verificarla en el motor sobre las imágenes reales, sin basarse únicamente en las coordenadas.

## Navegación y menú de pausa (iteración actual)

**Juego:** los hotspots de Nucleus continúan activos. En las zonas sin objeto, hacer clic en el extremo izquierdo (0–9 %), derecho (91–100 %) o borde inferior (89–100 %) permite navegar incluso sin mostrar iconos. La precedencia corresponde al hotspot real de un objeto, seguido por las bandas de navegación. Las rutas están declaradas en `game/adventure/cabin_map.json` como `edge_left`, `edge_right`, `back_target` y `navigation`. El historial de las pantallas visitadas permite recuperar una vista anterior con `@previous`. Se eliminaron las frágiles franjas `back` sobre fotografías como las del ordenador y la ventana.

**TAB:** alterna las flechas de navegación aportadas por el proyecto. No activa ni desactiva la exploración: los márgenes siguen funcionando aunque las flechas estén ocultas. El HUD principal no muestra opciones durante la partida.

**ESC:** abre/cierra un menú independiente en `CanvasLayer`. Solo ahí se modifica el filtro VHS, su intensidad y la respiración. Pausar bloquea la interacción con hotspots y la simulación normal, pero deja la interfaz en funcionamiento.

**Shaders de prueba:** `Sin filtro`, `YUV sutil`, `VHS`, `VHS suave`, `VHS postproceso`, `Scanlines` y `Fathom`. Todos proceden del repositorio actual, en `shaders/` y `game/shaders/`. La selección es de previsualización en la pausa; cada shader conserva sus uniforms originales y una asignación mínima del control de intensidad. Algunos efectos son agresivos por diseño y no están calibrados para producción. El shader postprocesado recibe la textura de ruido `rgba-noise-medium.png` incluida en el repositorio.

**Audio declarativo:** `game/adventure/cabin_audio_events.json` admite claves `page:<id>`, `interaction:<hotspot>` e `inspect:<message_key>`. Cada entrada contiene `stream` (ruta `res://`), `type` (`sfx`, `ambient` o `music`) y `fade` opcional. El adaptador delega sonidos a `NucleusAudio.play_one_shot` y música a `NucleusAudio.music.play`, sin nuevos Autoload. Las rutas están vacías como marcadores de posición hasta que se añadan pistas reales.

### QA de navegación

- Desde `desk` y `window`, verificar el retroceso por borde inferior y flechas visibles con TAB.
- Desde puerta abierta o cerrada, comprobar que los bordes vuelven a vistas válidas y que el historial no impide salir.
- Abrir pausa con ESC, cambiar entre los siete modos de vídeo, volver al juego, cambiar de pantalla y confirmar que el filtro elegido persiste.
- Confirmar que el HUD no altera las zonas de imagen ni recibe el shader.
- Probar en 4:3, ultrawide y vertical, y verificar el margen real de clic con cámara respirando.

## Controles y rutas — revisión de continuidad

- Cursor propio únicamente durante la partida: `assets/cursors/Circle.png` (normal) y `assets/cursors/MidRing.png` (sobre interacción o zonas de borde). Se preparan en memoria con un máximo de 32 píxeles y `Image.INTERPOLATE_NEAREST`; el centro es el punto activo, sin escalado del CanvasLayer ni del shader. La pausa restaura el cursor del sistema.
- Las flechas de ayuda, activadas por TAB, se anclan a las esquinas inferiores y al centro inferior, con botones de 38×40. Los márgenes laterales exteriores de 6,5 % y la banda inferior del 7 % se gestionan en `_input` antes de que los hotspots puedan capturarlos; el resto permanece interactivo de manera normal.
- `Fathom` es el efecto inicial; todos los demás shaders permanecen seleccionables desde pausa.
- El mapa tiene 18 vistas, incluidas las ocho imágenes nuevas (`bed_close`, `bed_windows`, `entry_picture`, `desktop_tower`, `computer_screen`, `cabin_shelf`, `cabin_clothes`, `cabin_boots`). Cada acercamiento posee `back_target`, `edge_left` y `edge_right` explícitos; los botones inferiores vuelven al nodo madre. El acceso a cama también está disponible desde la vista principal mediante un hotspot visible.
- El historial se mantiene como mecanismo adicional, no como la única ruta de salida. Los tests smoke comprueban que todos los acercamientos cargan y pueden retornar a su nodo padre.

Revisión manual pendiente: contraste y tamaño percibido de cursores en monitores con escala DPI distinta de 100 %, posiciones exactas de flechas y preferencias individuales sobre tamaño y amplitud de bordes.


## Corrección de interacción (router único)

La navegación física por ratón es propiedad de `cabin_demo.gd`: transforma coordenadas de viewport a UV reales del control animado, espera a soltar el botón y usa `screen.hotspot_at` y `session.activate_hotspot` cuando corresponde. `NucleusImageScreen` sigue resolviendo polígonos, prioridades y foco por teclado, pero no recibe eventos GUI de ratón en esta composición para evitar doble despacho. La banda inferior mínima (último 6,5 %) se reserva al retorno fijo de `back_target`; fuera de ella los hotspots tienen prioridad sobre los bordes. Los iconos mostrados con TAB conservan sus controles de UI.

Las comprobaciones automatizadas prueban **clics** sobre el CRT y cuadro, el recorrido hacia la cama y el regreso desde la ventana, no únicamente la carga de escenas. Una vista nueva debe disponer de una ruta concreta de salida sin depender exclusivamente del historial. Se han resuelto los avisos `UNASSIGNED_VARIABLE` (selección Nucleus) y `SHADOWED_VARIABLE_BASE_CLASS` (variables del juego).

## Inventario de bolsillo (primera versión)

La cabina incorpora `CabinInventory` como adaptador local de `NucleusInventory`, con `max_slots = 2` y objetos no apilables. El catálogo `game/inventory/cabin_items.json` define IDs estables, nombre, descripción, lugar de aparición y **dos imágenes independientes** por objeto: `*_icon.svg` (slot) y `*_examine.svg` (inspección). Son placeholders estilizados editables; conviene sustituirlos por fotografías coherentes con el lenguaje visual definitivo.

Las dos casillas compactas se muestran siempre arriba a la izquierda en un CanvasLayer, sin aplicarles el shader. Al pulsar un slot ocupado aparece una ampliación y descripción; el cierre devuelve el control al escenario. Recoger un tercer objeto deja el objeto en el mundo y emite un aviso. `discard(item_id, page_id)` permite liberar espacio sin destruir la instancia narrativa; la vista de descarte se registra en `world` para recogerlo de nuevo, y `capture_state` / `restore_state` persisten el estado de la bolsa y el mundo. Todavía no hay pantalla definitiva de soltar/usar/combinar ni puzzles.

Objetos iniciales: CD-ROM (torre), fotos del empleado dormido (cama), llave (estantería), figura del zorro (botas) y recibo oculto (perchero). El progreso posterior podrá requerir decisiones entre estos cinco objetos y dos espacios. Los puntos de aparición son provisionales en algunas imágenes: antes del arte definitivo habrá que alinear las ilustraciones y las máscaras con los píxeles de las escenas.

El cursor de hardware se reduce a 24 px manteniendo `Image.INTERPOLATE_NEAREST`; la flecha inferior de retroceso está girada 90° hacia arriba para representar un movimiento de retirada. Verificar orientación con el icono original en Godot.
