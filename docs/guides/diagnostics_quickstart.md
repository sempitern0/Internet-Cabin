# Diagnostics Quickstart

Use Nucleus diagnostics to make development output more readable without
introducing another global service.

Technical contract:

```text
docs/components/diagnostics.md
```

## 1. Use the existing facade

```gdscript
NucleusLog.debug("Spawn request admitted", &"world")
NucleusLog.info("Loaded profile", &"settings")
NucleusLog.warning("Using fallback cue", &"audio")
NucleusLog.error("Invalid save header", &"save")
```

Prefer a short stable context such as:

```text
world
streaming
terrain
network
save
input
animation
```

over long prose prefixes.

## 2. Log structured snapshots

Instead of:

```gdscript
print(queue.get_debug_snapshot())
```

use:

```gdscript
NucleusLog.debug_data(
	"Materialization queue",
	queue.get_debug_snapshot(),
	&"streaming",
)
```

For nested state:

```gdscript
NucleusLog.debug_data(
	"Region descriptor",
	descriptor,
	&"streaming",
	{"multiline": true},
)
```

The formatter is bounded by default.

## 3. Enable call-sites while diagnosing wiring

Temporarily:

```gdscript
NucleusLog.set_include_callsite(true)
```

Output gains source information in debug builds.

Disable it when the extra prefix stops helping:

```gdscript
NucleusLog.set_include_callsite(false)
```

Do not design parsing/runtime behavior around the source prefix.

## 4. Reduce development noise

```gdscript
NucleusLog.set_minimum_level(NucleusLog.Level.INFO)
```

or:

```gdscript
NucleusLog.set_minimum_level(NucleusLog.Level.WARNING)
```

Warnings and errors continue to appear.

Restore detailed development output with:

```gdscript
NucleusLog.set_minimum_level(NucleusLog.Level.DEBUG)
```

## 5. Avoid expensive disabled diagnostics

If building the snapshot is costly:

```gdscript
if NucleusLog.is_level_enabled(NucleusLog.Level.DEBUG):
	var snapshot: Dictionary = build_expensive_snapshot()
	NucleusLog.debug_data(
		"Snapshot",
		snapshot,
		&"world",
	)
```

This avoids paying the snapshot-construction cost when debug output is filtered.

## 6. Print a bounded table

```gdscript
var rows: Array = [
	{
		"region": "island_03",
		"state": "LOADED",
		"progress": 1.0,
	},
	{
		"region": "island_04",
		"state": "LOADING",
		"progress": 0.625,
	},
]

NucleusLog.debug(
	NucleusDebugTable.format(
		rows,
		["region", "state", "progress"],
	),
	&"streaming",
)
```

Use tables for compact comparisons, not arbitrary object dumps.

Good examples:

```text
streaming regions
performance metrics
AI scores
network peers
save participants
content validation results
```

## 7. Install file logging only when needed

`NucleusFileLogger` is a native Godot `Logger`.

When a project installs it, the same engine/application output can be retained
for support and post-run investigation.

Its files include the process ID, making parallel server/client sessions easier
to distinguish.

## 8. Keep logs actionable

A useful diagnostic usually answers:

```text
what happened?
which subsystem?
which stable ID/request?
what state/value mattered?
what should the developer inspect next?
```

Avoid high-frequency prose that produces large logs without improving diagnosis.
