# Hands-on Nucleus Tutorials

Tutorials build one concrete integration in the Godot editor. The preferred
reading order is:

```text
Quickstart → Tutorial → Technical contract
```

## Recommended learning path

1. [`core_services.md`](core_services.md) — baseline services and ownership.
2. [`bindings.md`](bindings.md) — settings, accessibility preferences, prompts and rebinding.
3. [`graphics_settings.md`](graphics_settings.md) — runtime graphics policy.
4. [`ui_polish.md`](ui_polish.md) — presentation, focus/glyph feedback and accessibility-safe motion.
5. [`performance_profiling.md`](performance_profiling.md) — measure a real workload.
6. [`runtime_optimization.md`](runtime_optimization.md) — apply bounded runtime interventions.
7. [`audio.md`](audio.md) — cues, buses and volume.
8. [`save_system.md`](save_system.md) — participant state and incremental capture.
9. [`scene_flow.md`](scene_flow.md) — observable scene transitions.
10. [`resource_loading.md`](resource_loading.md) — load plans, progress and first-use warmup.
11. For 2D start at [`2d_foundation.md`](2d_foundation.md), then follow the
    [`platformer_2d.md`](platformer_2d.md) or [`top_down_2d.md`](top_down_2d.md) recipe;
    for 3D use [`third_person_3d.md`](third_person_3d.md).
12. Use [`animation_pipeline_3d.md`](animation_pipeline_3d.md) to import a rig and build the first AnimationTree.
13. Add [`animation_directional_layers_quality_3d.md`](animation_directional_layers_quality_3d.md) for advanced locomotion/layers/quality.
14. Continue with [`character_animation_3d.md`](character_animation_3d.md) for IK, attachments and ragdoll runtime.
15. Use [`ragdoll_authoring_3d.md`](ragdoll_authoring_3d.md) to generate and tune a native humanoid physical skeleton.
16. Build [`ai_character_3d.md`](ai_character_3d.md) when the same 3D locomotion stack should be AI-controlled.
17. Use [`material_texture_optimization_3d.md`](material_texture_optimization_3d.md) to establish scalable rendering quality.
18. Add [`lighting_shadows_3d.md`](lighting_shadows_3d.md) for scalable native 3D lights and shadows.
19. Use [`terrain_heightmap_materials_3d.md`](terrain_heightmap_materials_3d.md) for scalable terrain relief/PBR.
20. Use [`world_stream_materialization_budgeting.md`](world_stream_materialization_budgeting.md) for bounded region/island construction.
21. Continue into gameplay actions, components and optional modules as required.

## By area

| Area | Tutorial |
| --- | --- |
| Core | [`core_services.md`](core_services.md) |
| Settings / Input | [`bindings.md`](bindings.md) |
| Graphics | [`graphics_settings.md`](graphics_settings.md) |
| UI / Accessibility | [`ui_polish.md`](ui_polish.md) |
| Performance | [`performance_profiling.md`](performance_profiling.md) |
| Runtime optimization | [`runtime_optimization.md`](runtime_optimization.md) |
| Audio | [`audio.md`](audio.md) |
| Save | [`save_system.md`](save_system.md) |
| Scene Flow | [`scene_flow.md`](scene_flow.md) |
| Resource Loading | [`resource_loading.md`](resource_loading.md) |
| **Reusable 2D character** | [`2d_foundation.md`](2d_foundation.md) |
| 2D platformer recipe | [`platformer_2d.md`](platformer_2d.md) |
| 2D top-down recipe | [`top_down_2d.md`](top_down_2d.md) |
| 3D movement | [`third_person_3d.md`](third_person_3d.md) |
| 3D animation setup | [`animation_pipeline_3d.md`](animation_pipeline_3d.md) |
| Directional/layered animation | [`animation_directional_layers_quality_3d.md`](animation_directional_layers_quality_3d.md) |
| 3D animation advanced | [`character_animation_3d.md`](character_animation_3d.md) |
| Humanoid ragdoll authoring | [`ragdoll_authoring_3d.md`](ragdoll_authoring_3d.md) |
| 3D AI character | [`ai_character_3d.md`](ai_character_3d.md) |
| Texture/material optimization | [`material_texture_optimization_3d.md`](material_texture_optimization_3d.md) |
| 3D lighting/shadows | [`lighting_shadows_3d.md`](lighting_shadows_3d.md) |
| Terrain preview | [`terrain_preview_and_presets.md`](terrain_preview_and_presets.md) |
| Procedural terrain | [`procedural_terrain_3d.md`](procedural_terrain_3d.md) |
| Terrain relief/PBR | [`terrain_heightmap_materials_3d.md`](terrain_heightmap_materials_3d.md) |
| Terrain streaming | [`terrain_streaming_runtime.md`](terrain_streaming_runtime.md) |
| World materialization budgets | [`world_stream_materialization_budgeting.md`](world_stream_materialization_budgeting.md) |
| Gameplay actions | [`gameplay_actions.md`](gameplay_actions.md) |
| Common components | [`components_first_steps.md`](components_first_steps.md) |
| Local multiplayer | [`local_multiplayer.md`](local_multiplayer.md) |
| Networking | [`networking.md`](networking.md) |
| Content packs | [`content_packs.md`](content_packs.md) |
| Mobile | [`mobile.md`](mobile.md) |

Tutorials use public `Nucleus*` APIs and native Godot APIs. Underscore-prefixed
helpers are implementation details, not integration contracts.
