# Revisión de interacción — PR #1

Base: `a0210fd92148a522fbc4ae65c2cde50500d6a8c1`, rama `feat/visual-continuity-cabin-frames`.

## Propiedad de comportamiento (antes de editar)

| Requisito | Godot | Contrato reutilizado | Política del juego |
| --- | --- | --- | --- |
| Cursor hardware | Input.set_custom_mouse_cursor | NucleusCursor conserva el modo del ratón | cabin_demo elige círculo, aro, lupa o mano |
| Hit testing y respiración | Control, CanvasItem | NucleusImageScreen y coordenadas normalizadas | regiones y verbos de objetos |
| Recoger y capacidad | Node, señales | NucleusInventory, dos slots | CabinInventory decide si es recogible |
| Examinar sin recoger | Control modal | ruta de interacción de CabinSession | panel de examen sin mutar inventario |
| Objetos en el mundo | Node2D | transformación de NucleusImageScreen | textura world separada de icon/examine |
| Flechas | TextureButton, eventos de teclado | navegación de CabinSession | todas ocultas hasta TAB |

## Hallazgos

El dibujado mundial reutilizaba iconos con tarjeta de madera opaca. Se separa `world_texture` de `icon` y `examine`; sin textura mundial no se dibuja una tarjeta de sustitución. Los actuales recortes SVG siguen siendo provisionales: no equivalen a arte fotográfico de producción. Se hereda la transformación de la imagen y el pase VHS existente.

`collectible` permite props solo examinables; la figura del zorro demuestra ese contrato. CD, fotos, llave y recibo siguen permitiendo probar recoger, usar, dejar y recuperar. Inventario lleno ofrece lupa y examen sin pérdida del objeto; no promete recogida imposible. Seleccionar un objeto usa aro, no mano.

El paquete SpawnIconPack contiene círculos, aros y flechas, pero no símbolos de lupa/mano ni archivo de licencia. Se conservan Circle/MidRing ya presentes; se añaden SVG propios de 24 px para lupa y mano. No se copia el paquete completo. Puntos de clic: centro de lente (9,9), punta del índice (9,3); círculos centrados. El cursor del sistema vuelve en HUD, modales y pausa.

Los placeholders y sus IDs no fijan el contenido narrativo final. Las partidas conservan esquema 1; snapshots que intentan llevar un prop no recogible se rechazan de forma atómica.

## Validación ejecutada

- Godot 4.7.2-stable: importación sin errores de script; smoke de la escena real PASS. Incluye clics inyectados, examen del zorro, capacidad llena, recogida, desaparición del hotspot, TAB y rechazo atómico de snapshot inválido.
- Suite headless: 4399 checks / 104 suites PASS. El motor emite tres avisos Unicode/NUL durante esta suite, sin fallo del runner; no se presenta como un log sin avisos.
- Smoke general y carga de recursos: PASS.
- Static checks, auditorías de documentación/productización/casos de uso, contenido de cabina, cuatro pruebas de validación de datos y dimensiones de 16 fondos: PASS.
- Lupa y mano rasterizadas e inspeccionadas a 24 px y ampliadas. No se ha podido ejecutar revisión gráfica de la escena: no hay servidor de pantalla disponible. Pendientes Forward+, DPI de Windows, sensación del cursor y arte fotográfico definitivo. No se ha exportado un ejecutable.
