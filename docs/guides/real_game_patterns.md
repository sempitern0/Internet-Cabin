# Real-game Application Patterns

Use this guide when you know the game behavior you need but not which Nucleus
owner should provide the reusable primitive.

## Capability map

| Need | Nucleus owner | Start with |
| --- | --- | --- |
| lifecycle, paths, diagnostics | Core runtime | [`../components/core_runtime.md`](../components/core_runtime.md) |
| options, rebinding, hot-swap | Settings + Input | [`settings_input_quickstart.md`](settings_input_quickstart.md) |
| save, audio, locale, scene changes | Runtime services | [`runtime_services_quickstart.md`](runtime_services_quickstart.md) |
| resume newest save | Save | [`../components/save_resume.md`](../components/save_resume.md) |
| health/resources/damage/state | Gameplay foundation | [`gameplay_foundation_quickstart.md`](gameplay_foundation_quickstart.md) |
| abilities/stats/buffs | Actions / attributes / status | [`actions_attributes_status_quickstart.md`](actions_attributes_status_quickstart.md) |
| character motion/camera | Movement + Camera | [`../components/gameplay_movement_camera.md`](../components/gameplay_movement_camera.md) |
| safe spawn/teleport/exit placement | Movement | [`../components/safe_placement_queries.md`](../components/safe_placement_queries.md) |
| repeated spawns / target selection | Pooling + Targeting | [`pooling_targeting_quickstart.md`](pooling_targeting_quickstart.md) |
| focus/UI/accessibility | UI | [`ui_quickstart.md`](ui_quickstart.md) |
| performance evidence | Performance | [`performance_quickstart.md`](performance_quickstart.md) |
| frame-spike mitigation | Runtime optimization | [`runtime_optimization_quickstart.md`](runtime_optimization_quickstart.md) |
| deterministic timed world states | World time | [`../components/world_scheduling_and_batched_fx.md`](../components/world_scheduling_and_batched_fx.md) |
| batched transient surface FX | Environment FX | [`../components/world_scheduling_and_batched_fx.md`](../components/world_scheduling_and_batched_fx.md) |
| AI choices/path following | AI / Navigation | [`ai_navigation_quickstart.md`](ai_navigation_quickstart.md) |
| inventory/equipment | Inventory | [`inventory_equipment_quickstart.md`](inventory_equipment_quickstart.md) |
| deterministic rewards | Loot | [`loot_quickstart.md`](loot_quickstart.md) |
| durable doors/chests/entities | World State | [`persistent_world_quickstart.md`](persistent_world_quickstart.md) |
| transport / LAN session | Networking | [`networking_quickstart.md`](networking_quickstart.md) |

## Pattern: controller should just work

For one player, keep one stable `NucleusLocalPlayerInput` and let
`NucleusLocalInputSession` hot-swap its source. UI prompts follow active source;
gameplay does not cache physical device IDs.

For local multiplayer, stop using global active-device state as ownership and
assign devices to seats explicitly.

## Pattern: UI cancel and gameplay action share a button

This is normal. The active consumer supplies context:

```text
menu       B/Circle → ui_cancel
world      B/Circle → dodge / melee / project action
pause UI   B/Circle → ui_cancel
```

Use a gameplay action such as `pause` to open UI; do not let the world interpret
`ui_cancel` as a global exit command.

## Pattern: survival/action player

Compose generic state locally:

```text
Player
├── MotionInput
├── motor / camera
├── Health / Stamina
├── Interaction
├── Attributes
└── Status effects
```

Keep hunger, temperature, vehicle handling, swimming rules, crafting balance and
other product mechanics game-owned.

## Pattern: safe disembark / respawn

Generate a small ordered list of candidate transforms according to game rules,
then test the actor's real collision shape:

```text
game chooses candidates
→ NucleusPlacementQueries2D/3D
→ first physically free index
→ game performs the transition
```

Do not reduce a capsule/vehicle placement problem to a point test when overlap
with surrounding geometry matters.

## Pattern: Continue loads the real newest state

Use `NucleusSave.load_latest()` or `NucleusSaveSession.load_latest()` instead of
duplicating manual-vs-autosave timestamp comparisons in menus.

Games still decide which slot represents the active campaign.

## Pattern: one collision, several responses

```text
Godot collision
→ NucleusSurfaceResolver3D
→ SurfaceProfile
→ game-owned audio / VFX / decal / gameplay mapping
```

Classification is reusable; content selection remains game policy.

## Pattern: deterministic daily/world rotation

Use one authoritative absolute simulation time and a
`NucleusDeterministicSchedule`:

```text
world seed + absolute segment index
→ deterministic RNG stream
→ game-owned semantic state
```

Weather, encounter, shop and population rules stay outside the schedule.

## Pattern: sparse surface impacts

For rain hits, sparks or similar high-churn presentation:

```text
FX spawn budget
→ game-owned surface query
→ NucleusTransientSurfaceBatch3D
```

The batch removes Node churn and bounds draw/storage cost without deciding what
surface response should look like.

## Pattern: performance spike

```text
repeatable workload
→ PerformanceSampler / native profiler
→ identify pressure
→ scheduler / gate / prewarm / audit / warmup as appropriate
→ repeat identical workload
→ compare report
```

Do not introduce an optimizer that silently changes quality or simulation rules.
