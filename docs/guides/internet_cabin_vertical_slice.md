# Internet Cabin: navegación, interacción y autoría

Escena: `res://game/adventure/cabin_demo.tscn`. Motor de referencia: **Godot 4.7.2-stable**.
Este documento describe el comportamiento actual y sustituye las notas de iteraciones anteriores.

## Propiedad y composición

| Necesidad | Primitiva Godot | Contrato Nucleus reutilizado | Política del juego |
| --- | --- | --- | --- |
| Entrada, hit testing, foco | `Control._gui_input`, transformaciones canvas | `NucleusImageScreen`, `NucleusScreenHotspot` | Prioridad de objetos, banda de retorno y texto contextual |
| Navegación y progreso | Nodes, Resources y signals | `NucleusAdventureSession`, `NucleusScreenAction` | Mapa JSON, aliases y reglas de la cabina |
| Objetos | Resources, Texture2D, Buttons | `NucleusInventory`, catálogo y definiciones | Dos bolsillos, colocación en el mundo, selección y examen |
| Filtros | ShaderMaterial y BackBufferCopy | `NucleusScreenShaderStack`, `NucleusScreenEffectPass` | Selección de shader e intensidad |
| Audio | AudioStream y buses | `NucleusAudio` | Correspondencia evento → pista |

`game/adventure/cabin_session.gd` es un adaptador pequeño: sobrescribe `_on_hotspot`
para emitir `interaction_requested` antes de ejecutar la acción. Es necesario porque
la sesión genérica activa inmediatamente los destinos y comprueba posesión, pero el
juego necesita resolver aliases y exigir que el jugador seleccione el objeto.
No se desconectan callbacks privados ni se modifican las clases compartidas. El
controlador llama después a `session.activate_hotspot`: Nucleus valida posesión,
consume objetos, aplica banderas y controla acciones de un solo uso.

Nucleus es el único dueño de páginas/banderas y cantidades de inventario. El juego
posee únicamente selección, historial y ubicación de objetos no transportados.
Los hotspots temporales se agregan a una copia del array de la pantalla; no se
mutan los Resources del mapa ni se sustituyen permanentemente aliases.

## Controles y lectura del escenario

- Clic izquierdo: examinar, avanzar o recoger. El cursor de hardware de 24 px y
  el texto contextual usan el mismo hit test que la activación.
- Flecha inferior siempre visible, banda inferior del 6,5 % o Retroceso:
  volver al `back_target` explícito. No depende del historial.
- Clic derecho sobre el escenario: cancelar objeto seleccionado; sin selección,
  volver. Escape: cerrar examen, cancelar selección o abrir/cerrar pausa, por orden.
- Tab: mostrar/ocultar flechas laterales. Los bordes laterales ocupan el 7 % y
  tienen prioridad inferior a los objetos. Las direcciones y aceptar permiten
  recorrer/activar hotspots mediante el foco de Nucleus.
- Dos bolsillos arriba a la izquierda. Pulsar un objeto abre imagen y descripción,
  con **Usar en el escenario**, **Dejar aquí** y **Cerrar**.
- Al seleccionar Usar, pulsar el objetivo. Fallar no consume el objeto. Las pistas
  describen el mecanismo/material/contexto que falta, sin marcar el objetivo correcto.
- Los mensajes permanecen 4,5 segundos; el hover no los borra al siguiente frame.
- La inspección y pausa tienen una barrera modal que bloquea clics sobre el mundo.

Los recogibles se dibujan usando sus iconos actuales en la misma transformación que
la imagen y los hotspots; desaparecen al recogerlos. Al soltarlos usan posiciones
separadas, recuperables, en la parte baja del escenario. Los SVG son placeholders:
no equivalen a arte final integrado fotográficamente en el fondo VHS.

## Añadir una imagen/página

1. Añadir el PNG a `assets/cabin/`. Cumplir el [contrato visual](../art/visual_continuity.md):
   1448 × 1086, 4:3, perspectiva, iluminación y geometría coherentes. No estirar.
2. Añadir una entrada a `game/adventure/cabin_map.json` con ID único, imagen,
   título, `back_target`, `edge_left`, `edge_right` y `hotspots`.
3. Añadir un hotspot en una página existente que apunte al nuevo ID.
4. Comprobar ida y vuelta con ratón real, con respiración activada/desactivada y
   diferentes relaciones de aspecto. La banda inferior está reservada para volver.

```json
{
  "id": "new_detail",
  "title": "Nuevo detalle",
  "image": "new_detail.png",
  "back_target": "desk",
  "edge_left": "desk",
  "edge_right": "desk",
  "hotspots": [{
    "id": "inspect_mark",
    "label": "Examinar la marca",
    "rect": [0.25, 0.2, 0.3, 0.25],
    "priority": 5,
    "action": {"message_key": "Una marca reciente en la madera."}
  }]
}
```

`rect` significa `[x, y, ancho, alto]` normalizados respecto a **toda la imagen**.
Un `polygon` opcional contiene vértices también normalizados, no relativos al rect.
Nucleus exige que el punto esté dentro del rect **y** del polígono. En solapes gana
la prioridad mayor. Reservar prefijos `pickup:` y `nav:` al runtime; las prioridades
100 y 200 corresponden a recogibles y retorno. Usar prioridades de autoría menores.

`target` admite IDs o `@overview` / `@interior_door`, resueltos en cada activación
según `door_open`. `@previous` es una opción de navegación explícita con historial;
no usarlo en `back_target` (que debe ser determinista). `action.next_screen` debe
ser un ID real, porque lo valida Nucleus. No sustituir un alias por el resultado
resuelto en el Resource original.

## Añadir objetos y usos

En `game/inventory/cabin_items.json`, cada objeto define `id`, `name`, `description`,
`icon`, `examine` y `start: {page, rect}`. Las dos imágenes cumplen funciones distintas:
icono de bolsillo/mundo y vista de examen. No apilar; mantener `max_slots = 2`.
La distribución actual de descarte está ajustada al catálogo de cinco objetos;
si se amplía, adaptar sus posiciones para mantenerlas dentro del lienzo y sin solapes.

Un hotspot que necesita un objeto lleva `hint` y una acción:

```json
{
  "id": "disc_drive",
  "label": "Examinar la unidad de CD-ROM",
  "rect": [0.38, 0.1, 0.27, 0.26],
  "priority": 10,
  "hint": "La bandeja está vacía. En el frontal pone CD-ROM; espera un disco de respaldo.",
  "action": {
    "required_item": "cd_rom",
    "consume_item": true,
    "one_shot": true,
    "set_flags": ["backup_loaded"],
    "message_key": "La unidad gira. El respaldo está cargado."
  }
}
```

El lector también admite `required_flags`, `set_flags`, `clear_flags` y `next_screen`.
No todos los campos de `NucleusScreenAction` están expuestos por este lector: ampliar
el mapeo y sus pruebas antes de usar campos adicionales. Usar `consume_item: false`
para herramientas reutilizables; se valida igualmente la posesión real. `one_shot`
evita repetir efectos. El CD se consume al insertarlo; fotos y llave se conservan.
Las interacciones de ejemplo establecen `backup_loaded`, `photos_compared` y
`compartment_open`; sus textos son contenido de prototipo, no un sistema de PC completo.

`CabinInventory.capture_state/restore_state` conserva bolsa y ubicación. La sesión
Nucleus conserva página, flags y acciones completadas. Estos contratos no implican
que exista una partida guardada integrada: todavía falta componer ambos con una
sesión de guardado y restaurarlos en orden inventario → aventura.

## Añadir filtros

1. Guardar un `.gdshader` de tipo `canvas_item` dentro de `game/shaders/`.
2. Añadir nombre y ruta en `SHADERS` de `cabin_demo.gd`.
3. Mapear la intensidad 0–1 al uniform apropiado en `_apply_uniforms()`.
4. Si requiere texturas auxiliares, asignarlas en `_apply_shader()` (ver ruido
   de «VHS postproceso»). Nucleus recibe un `NucleusScreenEffectPass` con ID `vhs`.
5. Probar en pausa todos los valores, cambiar de página y desactivar con «Sin filtro».

El backend actual es `BACKBUFFER`; el shader afecta al arte/objetos del mundo,
no al HUD del CanvasLayer. La sesión configura su página antes de emitir
`page_changed`; el juego reaplica el filtro elegido después. No añadir otra captura
ni otro controlador escribiendo la misma intensidad. Respiración es optativa en
pausa y transforma conjuntamente arte y hotspots. Mantener los efectos discretos.

## Añadir pistas de audio

Importar `.ogg` o `.wav` bajo `res://assets/audio/` y editar
`game/adventure/cabin_audio_events.json`:

```json
{
  "interaction:disc_drive": {
    "type": "sfx",
    "stream": "res://assets/audio/cd_spin.ogg"
  },
  "page:porch_open": {
    "type": "music",
    "stream": "res://assets/audio/porch_theme.ogg",
    "fade": 1.5
  }
}
```

Eventos: `page:<page_id>` al entrar, `interaction:<hotspot_id>` tras éxito,
`blocked:<hotspot_id>` cuando falta seleccionar el objeto, `pickup:<item_id>` al
recoger, `inspect:<message_key>` al emitir un mensaje de una acción. Preferir
`interaction:` para audio de acciones con texto largo. Los IDs de interacción
son globales al archivo: usar nombres distintos si dos páginas necesitan sonidos distintos.

`type: music` usa `NucleusAudio.music.play` con fundido. `sfx` y `ambient` usan
`NucleusAudio.play_one_shot` en sus buses respectivos. **Ambient no crea un bucle**:
para ambiente continuo componer un reproductor con ciclo de vida de escena.
Una ruta vacía/inexistente no reproduce nada. No se han añadido pistas sonoras
finales; el JSON contiene puntos de conexión. Evitar colocar efectos de puerta en
`interaction:door_open`: el ID del hotspot actual es `open` o `close`.

## Verificación reproducible

```bash
python3 scripts/ci/static_checks.py
python3 scripts/ci/documentation_audit.py
python3 scripts/ci/productization_audit.py
python3 scripts/ci/use_case_audit.py
python3 scripts/ci/check_cabin_images.py
godot --headless --path . --import
godot --headless --path . res://tests/headless/test_runner.tscn
godot --headless --path . res://tests/smoke/internet_cabin_smoke.tscn
```

El smoke instancia la escena real e inyecta clics en el viewport, no solo llamadas
a `change_page`: CRT, cuadro, todos los retornos, modalidades, 4 relaciones de aspecto,
revisita de aliases, pulsación obsoleta, inventario lleno, uso correcto/incorrecto,
consumo/reutilización y descarte/recogida. También comprueba la persistencia del filtro.
Eso no certifica sensación de juego, alineación artística de cada nuevo hotspot,
contraste en todos los monitores, mando físico, audio final o exportaciones.

Referencias oficiales consultadas:
- [Control y propagación GUI](https://docs.godotengine.org/en/stable/classes/class_control.html)
- [Orden de entrega de InputEvent](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html)
- [Godot 4.7.2](https://godotengine.org/article/maintenance-release-godot-4-7-2/)
