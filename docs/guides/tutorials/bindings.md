# Tutorial: Settings, Accessibility and Input Bindings

Bindings keep native Controls synchronized with Nucleus settings/input state
without duplicating `_ready()`, signal-loop and refresh glue in every menu.

## 1. Bind a volume slider

```text
MasterVolume : HSlider
└── SettingBinding : NucleusRangeSettingBinding
```

Assign `audio_master_volume.tres`. With `configure_range_from_definition = true`,
the binding derives range/step metadata from the same definition used by Settings
validation.

## 2. Bind a boolean accessibility preference

```text
ReducedMotion : CheckButton
└── SettingBinding : NucleusBoolSettingBinding
```

Assign `accessibility_reduced_motion.tres`. The same pattern works for the
built-in high-contrast preference.

## 3. Bind input comfort sliders

Nucleus already ships neutral input-comfort definitions:

```text
input/mouse_look_sensitivity_scale
input/gamepad_look_sensitivity_scale
input/gamepad_move_deadzone
input/gamepad_look_deadzone
```

Bind their definition Resources to `HSlider` controls with
`NucleusRangeSettingBinding`. Do not create a second game-specific camera
sensitivity setting unless the game intentionally needs a different semantic
preference.

The effective look speed remains:

```text
authored LookRig baseline × persisted sensitivity scale
```

## 4. Bind UI scale and high contrast

Use the settings controls for preference editing, then compose
`NucleusUIAccessibilityBinding` in the UI root. The game maps `ui_scale` and
`high_contrast` into its own Theme/layout variants; Nucleus does not impose a
palette or root transform.

## 5. Show the current input prompt

```text
InteractPrompt : Label
└── PromptBinding : NucleusInputPromptBinding
```

Set:

```text
action = interact
follow_active_source = true
```

The label follows keyboard/mouse ↔ gamepad hot-swap, gamepad family changes and
rebinding.

For artwork, use `NucleusInputGlyphBinding` with a game-owned glyph profile and a
text fallback.

## 6. Create a rebind button

```text
RebindInteractKeyboard : Button
└── Binding : NucleusInputRebindButtonBinding
```

Configure action, source and binding index. Use a separate row/button for the
gamepad source.

Conflict handling can allow, reject or pause for a project-owned confirmation
modal. Keep `ui_*` actions protected unless the project deliberately provides a
safe UI-navigation rebinding flow.

## 7. Add a project-specific setting only when ownership requires it

A game-specific FOV, aim assist strength or subtitle style can live in a game-owned
settings catalog. Reuse `Nucleus*SettingDefinition` types and the standard UI
bindings; do not add product policy to Core merely because it is configurable.

## Common mistakes

- copying definition ranges/options into a second UI-owned table;
- hard-coding prompt strings;
- persisting a transient gamepad device ID;
- making `ui_cancel` a world gameplay exit action;
- duplicating built-in sensitivity/deadzone preferences under new keys;
- applying UI scale with a blind root `Control.scale`.

Related: [`../settings_input_quickstart.md`](../settings_input_quickstart.md) and
[`../../components/accessibility_preferences.md`](../../components/accessibility_preferences.md).
