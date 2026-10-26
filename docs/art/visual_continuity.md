# Internet Cabin — contrato de continuidad visual

## Canon de imagen y cámara

La inmersión tiene prioridad sobre la cantidad de vistas o los efectos. Todas las imágenes de navegación de la cabina deben tener **1448 × 1086 px (4:3)** en su fuente maestra, mantenerse sin estiramiento y representarse mediante el mismo rectángulo de presentación en Godot. Las pantallas de formato distinto se rechazan durante la revisión de assets, no se arreglan con estiramiento.

- **Cámara:** punto de vista humano, altura aproximada de 1,60–1,70 m de pie. La vista de escritorio sentado se autoriza como excepción documentada. Conservar focal moderada, perspectiva natural y orientación entre vistas.
- **Bloqueo espacial:** una sola cabina pequeña. Puerta a la derecha del plano general, estufa negra con tubo vertical inmediatamente a su izquierda, herramientas y leña junto a la estufa; escritorio beige/CRT a la izquierda, ventana de cuatro paños sobre/junto al escritorio, cama y muebles en posiciones estables.
- **Persistencia:** marcos, pomos, interruptores, nudos de madera, cables, cuadros, alfombra, cama, herramientas, objetos del escritorio y geometría de ventanas no deben cambiar arbitrariamente entre imágenes ni entre estados de la misma pantalla.
- **Luz:** hora atardecer azul / última luz, lámpara del escritorio cálida, exterior azul frío, sin luz de estudio ni exposición HDR. Ruidos ópticos de fotografía doméstica de finales de los 90 / principios de los 2000 (suavidad moderada, sombras con ruido realista); la estética VHS es opcional y se aplica preferentemente en Godot como shader, no quemada en todas las imágenes.
- **Transiciones:** antes de aceptar una vista comprobar orientación, objetos de referencia, posición de cámara y continuidad de cielo/sol. Para variantes de estado, mismo encuadre pixel a pixel tanto como sea posible; solo varía el objeto interactuado y su oclusión lógica.

## Inventario de vistas canónicas

| Archivo | Uso | Resolución esperada |
| --- | --- | --- |
| `assets/cabin/cabin_base.png` | Interior general, puerta cerrada | 1448 × 1086 |
| `assets/cabin/cabin_base_open_door.png` | Interior general, puerta abierta | 1448 × 1086 |
| `assets/cabin/cabin_back.png` | Vista de pared opuesta | 1448 × 1086 |
| `assets/cabin/cabin_bed.png` | Cama | 1448 × 1086 |
| `assets/cabin/computer.png` | Escritorio y PC | 1448 × 1086 |
| `assets/cabin/bed_window.png` | Detalle de ventana | 1448 × 1086 |
| `assets/cabin/cabin_closed_door.png` | Acercamiento de puerta cerrada | 1448 × 1086 |
| `assets/cabin/cabin_open_door.png` | Acercamiento de puerta abierta | 1448 × 1086 |

Los dos acercamientos de puerta usan el **mismo recorte de coordenadas** del par `cabin_base.png` / `cabin_base_open_door.png` para asegurar continuidad espacial con el plano general, sin crear una puerta distinta. Se recomiendan como assets derivados; la fuente sigue siendo el par de vistas generales. No regenerar ambos independientemente.

## Godot y Nucleus

1. Mantener `NucleusImageScreen` como dueño de la transformación imagen → hotspot; usar coordenadas normalizadas respecto al lienzo completo y `preserve_aspect = true`.
2. Presentar el render final siempre dentro de un **contenedor común**. Para 16:9, ultrawide y vertical: bandas/padding visibles si es necesario, sin recorte ni estiramiento. Los elementos de interfaz se ubican fuera del rectángulo interactivo cuando corresponda.
3. Evitar transiciones que cambien escala o posición perceptual. Si se simula un acercamiento, usar una transición breve intencional; los estados de puerta abierta/cerrada no deben desplazar la cámara.
4. Conservar Nucleus para las acciones, navegación, inventario opcional y los adaptadores de filtros. `BACKBUFFER` solo cuando el filtro necesite leer la pantalla; `VIEWPORT_CHAIN` cuando se necesite textura procesada. No duplicar la captura analógica en la imagen y en los shaders.
5. Efectos limitados: ruido sensible a sombras, leve aberración cromática, flicker suave de iluminación y movimiento ambiental sutil. No animar hotspots de forma independiente del objeto visual. Permitir reducir/desactivar parpadeo y distorsión.
6. No tratar la resolución nativa del PNG como resolución obligatoria de la ventana; usar la relación 4:3 del contenido sobre cualquier resolución de pantalla sin escalado no uniforme.

## Checklist de aprobación obligatoria

- [ ] Dimensión exactamente 1448 × 1086 y contenido 4:3 sin barras internas añadidas
- [ ] No se ha deformado la perspectiva al reescalar
- [ ] La puerta, el marco, el pomo y las bisagras se alinean entre estados
- [ ] Posición del interruptor, estufa, cuadro, cama y alfombra persistente
- [ ] Horizonte, cielo, bosque y fuente de luz coherentes con la vista anterior
- [ ] En 16:9 / 21:9 / 9:16 los hotspots continúan sobre los objetos y el contenido no se recorta
- [ ] Los cambios entre variantes de estado afectan solo a regiones justificadas
- [ ] Sin exageración artificial de VHS / glitch / bloom / HDR ni texto inventado
- [ ] Se ha probado el cambio de imagen en Godot y no hay salto brusco

## Validación automática

Ejecutar `python3 scripts/ci/check_cabin_images.py` para verificar el conjunto de imágenes y `python3 scripts/ci/check_cabin_images.py --allow-missing-door` cuando aún no se hayan importado las variantes de puerta. **Esta prueba valida dimensiones y archivos, no puede certificar la composición ni la continuidad visual:** comparar imágenes manualmente en una escena real de Godot.

## Fuentes visuales

Las referencias de producción provienen de `SecondBrain/AI/Prompts_Imagenes`: fotografía compacta digital, película de 35 mm y horror analógico de bajo contraste. Mantener una imagen base sin deterioro excesivo; tratar el ruido óptico como propiedad física y la distorsión VHS como una capa de presentación controlable.
