# Internet Cabin — plan de integración

Fecha: 29 de octubre de 2026. Base: PR #1, `feat/visual-continuity-cabin-frames`.

## Estado y alcance

Implementado en esta revisión: cursores semánticos, examen de props no recogibles, protección del inventario de dos slots, separación de arte mundial/iconos/examen y todas las flechas condicionadas a TAB. El zorro es una muestra no recogible; el catálogo es sustituible. El resto de este documento es planificación, no funcionalidades ya disponibles.

Objetivo: una primera partida de aproximadamente 35–50 minutos, ajustable tras pruebas. Comenzar dentro de la cabaña al atardecer, enseñar mediante acciones cotidianas y pasar a la noche por progreso, no por un temporizador que castigue explorar. Bosque natural cercano a una ciudad; el aislamiento se debe al turno y a la anomalía, no a una geografía imposible.

## Propuesta narrativa: El turno de continuidad

**Rol propuesto, pendiente de decisión:** auxiliar temporal que verifica un enlace de internet de una cooperativa local. Su trabajo básico consiste en abrir el parte, comprobar alimentación/conexión y comunicar incidencias. No necesita conocimientos técnicos. La cabaña contiene un antiguo terminal que mantiene un repetidor del bosque; se ven luces de la ciudad entre árboles y se oyen vehículos distantes.

Primer día. El relevo ha dejado una nota: «Si el foro deja de responder, no cierres el turno». Al restaurar el servicio, el portal de soporte deriva a un foro que conserva conversaciones de empleados de distintas épocas. Los mensajes nuevos describen detalles de la cabaña, pero aparecen con horas futuras. Los avatares son retratos cotidianos con una anomalía discreta: miradas descentradas, fondos idénticos o una figura difícil de distinguir. No todos necesitan ser rostros monstruosos.

La conexión transmite una copia incompleta del lugar. Cada confirmación de presencia da al interlocutor un detalle nuevo para reconstruirse. El conflicto final no consiste en matar algo: decidir si cerrar el enlace y dejar sin respuesta a quien parece pedir ayuda, o completar el último parte y permitir que algo termine de llegar.

**Amenaza recomendada:** una sola entidad, «el Relevo», con varias identidades en el foro. Reduce producción y permite que señales distintas tengan una explicación común. Nunca mostrar un modelo completo al principio. Progresión: audio fuera de campo → marcas de humedad o silla movida → imagen del foro contradictoria → reflejo parcial → presencia breve cerca del final. No explicar toda su naturaleza. Las reglas dramáticas sí deben ser consistentes: obtiene detalles por las respuestas del terminal; no aparece arbitrariamente en cada habitación. Otras criaturas quedan fuera del primer corte vertical.

## Progresión y puzles

| Tramo | Acción del jugador | Progreso y tensión | Criterio de salida |
| --- | --- | --- | --- |
| Atardecer: llegada | Examinar nota, aprender giros/regreso, inspeccionar ordenador | Seguridad cotidiana; instrucciones cortas contextualizadas | Controles utilizados y parte abierto |
| Atardecer: conexión | Seguir etiqueta de cable y activar alimentación; localizar credencial del turno | Primer fallo plausible; ninguna amenaza visible | `power_checked` y `terminal_authenticated` |
| Atardecer: diagnóstico | Comparar indicador del equipo con instrucciones; enviar parte local simulado | El foro responde con un dato que no se ha escrito | `link_verified` y `first_report_sent` |
| Cambio de turno | Cerrar panel; sonido breve en el exterior, comprobar ventana | Un sobresalto único y pausa para observar | Transición nocturna ejecutada una vez |
| Noche: investigación | Hallar linterna, consultar archivo del foro, visitar caja del repetidor | Alternancia entre refugio y exposición | Identificar que los avatares comparten el mismo fondo |
| Noche: decisión | Volver al terminal, decidir qué confirmar y qué desconectar | Presencia parcial y revelación tardía | Resolución coherente con acciones y estado guardado |

No ligar estos puzles de producción al CD, llave o fotos actuales hasta decidir su función. Para el primer prototipo se pueden reutilizar sus contratos de uso/consumo sin convertirlos en canon. No exigir recoger tres objetos simultáneamente. Garantizar una superficie segura donde dejar objetos y recuperarlos; bloquear descartes irreversibles de objetos imprescindibles.

## Fases de implementación

### P0 — cerrar la base de interacción (esta revisión + QA pendiente)

- [x] Círculo en vacío; lupa para examinar; mano cuando realmente cabe y se puede recoger; aro para interacción/navegación.
- [x] Props no recogibles no modifican el inventario y no ofrecen usar/dejar.
- [x] Icono de inventario, imagen de examen y recorte mundial separados.
- [x] Todas las flechas ocultas inicialmente y alternadas con TAB; laterales para giro, central vertical para regreso.
- [ ] Revisión manual Windows/Godot 4.7.2: punteros hardware a 100/150/200 % DPI, pausa, modales y reentrada a la ventana.
- [ ] Sustituir recortes provisionales por objetos fotográficos con alfa, sombra de contacto y perspectiva de cada localización.
- [ ] Si un objeto está integrado en el fondo, usar variantes con/sin objeto; no pintarlo dos veces. Un objeto visible desde varias vistas comparte un único ID y disponibilidad.

### P1 — corte vertical del atardecer

Dependencia: P0. Añadir nota de bienvenida y tres pasos del diagnóstico. `CabinSession`/`NucleusAdventureSession` siguen siendo propietarios de flags, acciones y navegación; `NucleusInventory` de los slots y consumo. Definir datos de objetivos y textos en `game/`, sin autoload nuevo ni segundo inventario.

Entrega: partida desde llegada hasta primer mensaje del foro. Aceptación: un jugador nuevo completa la secuencia sin instrucciones externas; cada error explica qué observar; volver siempre funciona con flechas ocultas; ninguna combinación de dos slots bloquea la partida.

### P2 — ordenador y foro ficticio

Dependencia: P1. Crear una escena Control específica del escritorio sobre la vista del CRT, con entrada/salida, historial de hilos, scroll y foco de teclado. Contenido local de ficción: no cargar webs ni ejecutar HTML remoto. Separar usuarios, avatares, mensajes y condiciones de desbloqueo en recursos o JSON validados. Texto legible antes que distorsión VHS.

Tres hilos iniciales: soporte rutinario, fotos de turnos anteriores y «¿quién está en la ventana?». Los mensajes reaccionan a flags, con identificadores estables; ninguna pista imprescindible depende de esperar un tiempo exacto o de escuchar audio. Guardar mensajes leídos y respuesta elegida, no referencias a nodos.

Aceptación: reiniciar conserva progreso e historial; salir del PC devuelve a la misma vista; scroll/clics no atraviesan la pantalla hacia hotspots; la narrativa funciona sin conexión real.

### P3 — atardecer a noche y director de tensión

Dependencias: P1/P2 y arte nocturno mínimo de P4. Propietario: un componente de juego local a la escena que consulta flags de la sesión y solicita cambios; no reescribe los mismos flags desde varios sitios. Estado temporal explícito (`dusk`, `transition`, `night`) guardado por NucleusSave mediante el snapshot del juego, con migración de versión.

La transición requiere los puzles completados y el jugador fuera de un modal. Precargar variantes antes de fundir. Sonido/sobresalto breve sin bloquear el clic de salida ni desorientar la navegación. Registrar `night_started` para impedir repetirlo al cargar.

Tensión como curva dirigida: curiosidad → incomodidad → alivio → anticipación → pico → recuperación. No medir supuestos estados psicológicos del jugador. Eventos con condiciones, cooldown y exclusión mutua; nunca solapar susto, diálogo crucial y navegación. Controles para reducir parpadeo, sobresaltos y respiración; subtítulos para señales auditivas. El ambiente no se silencia por completo para «avisar» siempre del susto.

Aceptación: guardar antes/durante/después no duplica eventos; pausa congela sus temporizadores; en diez recorridos no se producen cadenas de sustos ni bloqueos.

### P4 — continuidad del arte y bosque

Preparación en paralelo a P1/P2; integración antes de P3. Inventariar cada página existente, sus encuadres, estados de puerta y objetos removibles. Añadir bosque en alcance pequeño: porche, sendero visible, poste/caja del repetidor y claro desde el que se percibe la ciudad. Para cada ruta dibujar ida y vuelta y definir `back_target` antes de producir arte.

Por cada localización: maestro 1448 × 1086, versión atardecer, versión nocturna y, cuando proceda, variante nocturna iluminada por linterna. Misma cámara, focal, geometría, detalle de madera, vegetación y posición de objetos; cielo y fuentes de luz cambian con intención. La noche no debe ser una multiplicación negra del atardecer ni revelar un cielo naranja al encender la linterna.

Capas de props: alfa sin rectángulos, sombra de contacto, escala y perspectiva coherentes. Mantener dos dimensiones distintas: rectángulo visual ajustado y hotspot cómodo; documentar cualquier máscara. Si hay primer plano, preparar máscara de oclusión. No aceptar vistas nuevas por cumplir solo resolución.

Aceptación: comparar pares mediante superposición; validar puertas abiertas/cerradas; recorrer grafo sin salto espacial a 4:3, 16:9, 21:9 y vertical. Registrar arte aprobado/pendiente por página.

### P5 — linterna 2D (prototipo aislado antes de producción)

Dependencia: una pareja nocturna aprobada de P4. Recomendación para estos fondos fotográficos: **shader CanvasItem con máscara suave y pareja nocturna oscura/iluminada**, conservando `NucleusImageScreen` y la pila de efectos existentes. Es una decisión de composición para este juego, no un nuevo renderer.

1. Encontrar la linterna activa un flag de equipo. Propuesta: pasa a equipo dedicado tras recogerla para no ocupar permanentemente uno de los dos slots; confirmar durante el diseño del inventario.
2. Acción configurable `flashlight_toggle` (F por defecto), solo de noche y con linterna obtenida. Estado inicial apagado. No introducir batería en el primer prototipo.
3. Obtener posición normalizada usando la transformación inversa del mismo Screen y su `image_rect()`, igual que los hotspots. Nunca dividir directamente el ratón por el tamaño de ventana. Fuera de la imagen/HUD, congelar u ocultar el haz según criterio uniforme.
4. Material propio por instancia: interpolar escena nocturna y variante iluminada con máscara radial de borde suave. Corregir distancia por relación de aspecto para que el haz no sea elíptico en ultrawide. La variante iluminada mantiene cielo nocturno y luces originales.
5. Orden: fondo nocturno + props → luz/máscara → VHS → HUD. La pila actual usa la imagen como entrada; verificar que la composición elegida incluya props y no duplique captura. Prototipar primero el modo de pila adecuado y medir coste antes de cambiarlo.
6. El cursor hardware conserva su semántica sobre la luz. Las pistas que requieran iluminación deben filtrar también el hit testing: no descubrir objetos en negro solo porque el puntero se convierte en mano.
7. Guardar posesión/encendido; no guardar coordenadas transitorias del ratón. Pausa y examen no activan F ni permiten clics en el mundo. Sin movimiento forzado del haz ni parpadeo obligatorio.

Alternativa nativa: `CanvasModulate` + `PointLight2D`, con `CanvasTexture`/normales y oclusores si se separan fondos y objetos en capas. Godot permite luces 2D y sombras, pero una fotografía plana no aporta por sí sola volumen ni oclusión tridimensional. Para empezar, el shader permite controlar mejor el resultado artístico; la iluminación nativa merece un prototipo si se producen mapas de normales y capas suficientes. No prometer sombras físicas sobre la foto actual.

Aceptación: seguir el cursor con respiración activa, sin desfase ni deformación en todas las relaciones de aspecto; UI sin oscurecer; no iluminar a través de máscara de primer plano; comparar con/sin VHS; medir GPU con haz apagado/encendido y verificar F y restauración.

Referencia técnica oficial consultada: [Godot — 2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html). Verificar APIs contra el motor fijado del repositorio al implementar.

### P6 — amenaza, final y prueba completa

Dependencias: P2–P5. Producir primero señales de presencia; reservar diseño visible de la criatura para cuando su lenguaje esté definido. Un único encuentro tardío, legible y breve; permitir retirada y una decisión final con consecuencias comprensibles. Evitar persecución 3D improvisada dentro de un grafo de fotografías.

Entrega: recorrido completo con dos resoluciones narrativas, guardado antes del final y sin softlocks. Pruebas con jugadores: comprensión de orientación, momentos de confusión, lectura del foro, duración real y momentos de tensión/descanso. Ajustar con observación, no con más sustos por defecto.

## Decisiones pendientes y límites

- Confirmar auxiliar de enlace o un rol alternativo igualmente cotidiano.
- Confirmar una sola amenaza y final centrado en cortar/completar el enlace.
- Aprobar arte nocturno de una vista antes de producir el resto.
- Decidir equipo dedicado para linterna y superficie de devolución de objetos.
- Los objetos actuales validan sistemas; sus textos, aspecto y existencia no son compromisos narrativos.
- Esta revisión no implementa foro, noche, criatura ni linterna. No requiere producir ya todos los fondos del bosque.
