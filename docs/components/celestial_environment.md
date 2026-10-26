# Celestial Environment Contract

Target engine: Godot 4.7.x.

This contract extends the existing world-time/environment stack without turning
Nucleus into a sky renderer or astronomy package.

## Ownership

The preferred dependency direction is:

```text
NucleusWorldClock
    authoritative simulation time
        ↓
NucleusCelestialDriver3D
    derived presentation-facing celestial state
        ↓
NucleusDaylightDriver3D
    native DirectionalLight3D / Environment writes
```

Other game-owned presentation may consume the same state:

```text
NucleusCelestialDriver3D
    ├── NucleusDaylightDriver3D
    ├── game sky shader binding
    ├── game ocean binding
    ├── game fog binding
    └── game audio/VFX presentation
```

The clock remains independent from all of these consumers.

## NucleusCelestialState3D

`NucleusCelestialState3D` is a reusable derived state object containing:

```text
normalized_day_time

sun_rotation_degrees
moon_rotation_degrees

sun_direction
moon_direction

sun_elevation_radians
moon_elevation_radians
sun_azimuth_radians
moon_azimuth_radians

daylight_factor
night_factor

sun_above_horizon
moon_above_horizon
```

The state is presentation-facing data, not a rendering object.

One state instance is reused and updated in place to avoid allocating a new
Dictionary/object every refresh.

Consumers that need historical snapshots should copy the values they need rather
than retaining the mutable state as an immutable record.

## NucleusCelestialSource3D

`NucleusCelestialSource3D` is the extension seam for deriving celestial state.

The base contract receives:

```text
normalized day time
target NucleusCelestialState3D
```

and fills the target.

Nucleus does not require:

```text
calendar date
latitude
longitude
UTC offset
Earth orbital elements
seasons
real astronomy
```

A game may implement those in its own source without changing consumers.

## NucleusSimpleCelestialSource3D

The built-in simple source provides a cheap, art-directable 24-hour orbit.

Its default behavior preserves the existing Nucleus daylight assumptions:

```text
midnight
    sun below horizon
    moon above horizon

06:00
    horizon crossing

noon
    sun at maximum elevation

18:00
    horizon crossing
```

The source also exposes sun/moon rotation offsets, yaw and roll for authored
presentation.

`daylight_factor` uses positive sun elevation:

```text
0.0 at/below horizon
1.0 at maximum elevation
```

`night_factor` is the inverse elevation-side fallback:

```text
0.0 while the sun contributes daylight
1.0 at the simple orbit's midnight
```

These factors are neutral inputs. A profile curve can still override their
visual response.

## NucleusCelestialDriver3D

`NucleusCelestialDriver3D` owns derived-state refresh cadence.

It does not advance world time.

Update modes are:

```text
IMMEDIATE
    recompute on every NucleusWorldClock time_changed signal

SCHEDULED
    mark state dirty on clock changes
    recompute only when NucleusUpdateScheduler dispatches the task

MANUAL
    never refresh automatically after initial setup
    owner calls refresh_now() / request_refresh()
```

### Why cadence is separate from the clock

A game may need authoritative time at full simulation precision while visual
celestial state changes much more slowly.

For example:

```text
WorldClock
    advances every process frame

CelestialDriver
    refreshes 10 times per second

Sky/fog/ocean
    consume only those 10 derived updates
```

This reduces unnecessary property/shader writes without reducing simulation
precision.

### Scheduled mode

Assign an existing scene-owned:

```text
NucleusUpdateScheduler
```

and configure:

```text
update_interval
scheduler_phase
scheduler_priority
```

The driver only samples while dirty. If the clock has not changed since the
previous sample, a scheduler tick performs no celestial update.

Do not create a scheduler solely as a hidden dependency. The reference is
explicit.

## Horizon state versus gameplay day periods

`NucleusDayPeriodClassifier` and celestial horizon state intentionally answer
different questions.

Gameplay:

```text
07:00
    shops open
    day spawn tables begin
```

belongs in:

```text
NucleusDayPeriodClassifier
```

Visual/celestial state:

```text
sun crosses horizon
    sunlight becomes possible
    sky/fog transition begins
```

belongs in:

```text
NucleusCelestialState3D
```

A game may intentionally keep these boundaries different.

## NucleusDaylightProfile

The existing time-based sampling API remains supported.

When `NucleusDaylightDriver3D` receives celestial state, default fallback energy
now uses:

```text
state.daylight_factor
state.night_factor
```

instead of independently reconstructing those values from clock time.

Authored `Curve` resources still win when assigned.

This keeps artist-controlled curves compatible while allowing custom celestial
sources to alter sunrise/sunset/elevation behavior.

## NucleusDaylightDriver3D

Two integration paths are supported.

Legacy/direct:

```text
WorldClock
    ↓
DaylightDriver3D
```

Preferred reusable path:

```text
WorldClock
    ↓
CelestialDriver3D
    ↓
DaylightDriver3D
```

When `celestial_driver` is assigned it owns celestial rotation/state.

`clock` remains available for existing scenes and direct integrations.

The driver still only owns:

```text
DirectionalLight3D.rotation_degrees
DirectionalLight3D.light_energy
DirectionalLight3D.light_color
DirectionalLight3D.shadow_enabled
Environment.background_energy_multiplier
Environment.ambient_light_energy
```

It still does not own:

```text
sky shader
fog shader
cloud renderer
weather
camera exposure
calendar
astronomy
ocean rendering
gameplay day/night rules
```

## Low-end quality strategy

Do not lower world-time correctness for weaker hardware.

Prefer lowering presentation refresh cost:

```text
HIGH
    celestial refresh 30–60 Hz when genuinely needed

MEDIUM
    celestial refresh 10–20 Hz

LOW
    celestial refresh 2–10 Hz

static/paused presentation
    MANUAL
```

Exact rates are game policy, not hard-coded quality presets.

Slow day/night cycles rarely need per-frame celestial writes.

## Multiplayer

The authoritative value should normally remain:

```text
total game seconds
```

or another authoritative world-time representation.

Clients derive local celestial state from that clock.

Do not replicate sun/moon transforms as authority when clients can derive them
from the same time/source policy.

## Extension boundary

A consuming game can implement:

```text
RealAstronomyCelestialSource
AlienPlanetCelestialSource
FixedSunCelestialSource
SeasonalCelestialSource
```

without changing `NucleusDaylightDriver3D`.

Real-world astronomy is intentionally not bundled in this iteration.

## Non-goals

This layer is not:

```text
a sky renderer
a weather manager
an astronomy simulator
a calendar
a cloud system
a fog system
an exposure controller
a world manager
```

It is the reusable state/cadence seam between simulation time and environmental
presentation.
