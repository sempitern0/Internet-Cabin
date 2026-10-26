# Celestial Environment Quickstart

Use this path when several visual systems should share one reusable sun/moon
state without coupling them directly to `NucleusWorldClock`.

Technical contract:

```text
docs/components/celestial_environment.md
docs/components/world_time_environment.md
```

## 1. Keep the clock authoritative

Create or reuse:

```text
NucleusWorldClock
```

It continues to own elapsed simulation time only.

## 2. Add a celestial driver

Example scene:

```text
World
├── WorldClock : NucleusWorldClock
├── UpdateScheduler : NucleusUpdateScheduler
├── Celestial : NucleusCelestialDriver3D
├── Sun : DirectionalLight3D
├── Moon : DirectionalLight3D
├── WorldEnvironment
└── Daylight : NucleusDaylightDriver3D
```

Assign:

```text
Celestial.clock = WorldClock
```

Leaving `Celestial.source` empty uses the built-in simple source.

## 3. Choose update cadence

For direct/simple projects:

```text
update_mode = IMMEDIATE
```

For slow day/night cycles:

```text
update_mode = SCHEDULED
scheduler = UpdateScheduler
update_interval = 0.1
```

This keeps simulation time precise while visual celestial updates run at 10 Hz.

For game-owned orchestration:

```text
update_mode = MANUAL
```

then call:

```gdscript
celestial.refresh_now()
```

when the owner decides presentation should update.

## 4. Wire daylight

Assign:

```text
Daylight.celestial_driver = Celestial
Daylight.profile = DaylightProfile
Daylight.sun = Sun
Daylight.moon = Moon
Daylight.world_environment = WorldEnvironment
```

The existing direct `Daylight.clock` path remains available for legacy scenes.

## 5. Reuse state elsewhere

A game-owned sky binding can observe:

```gdscript
celestial.state_changed.connect(_on_celestial_state_changed)
```

and consume:

```text
sun_direction
moon_direction
daylight_factor
night_factor
sun_above_horizon
moon_above_horizon
```

For example:

```gdscript
func _on_celestial_state_changed(
	state: NucleusCelestialState3D,
) -> void:
	sky_material.set_shader_parameter(
		"sun_direction",
		state.sun_direction,
	)
```

Nucleus does not prescribe the shader parameter names or sky implementation.

## 6. Keep gameplay periods separate

Continue using:

```text
NucleusDayPeriodClassifier
```

for semantic rules such as shop hours, spawn tables or ambient audio.

Do not replace gameplay schedules with horizon checks unless that is genuinely
the game's rule.

## 7. Scale down presentation, not simulation

For a low graphics preset the game can change:

```gdscript
celestial.update_interval = 0.25
```

while the world clock continues running normally.

The same principle can be combined with cheaper sky/cloud/fog settings owned by
the consuming game.

## 8. Custom celestial sources

For a fictional planet or real astronomy, subclass:

```text
NucleusCelestialSource3D
```

and populate the supplied `NucleusCelestialState3D`.

The daylight, sky and ocean consumers do not need to change.
