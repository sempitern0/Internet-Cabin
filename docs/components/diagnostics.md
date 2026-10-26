# Diagnostics and Logging

Target engine: Godot 4.7.x.

Nucleus diagnostics stay deliberately small:

```text
NucleusLog
    stable logging facade

NucleusLogFormatter
    bounded Variant formatting

NucleusDebugTable
    bounded plain-text tables

NucleusFileLogger
    native Godot Logger capture
```

There is no logging Autoload or global logger registry.

## `NucleusLog`

Existing calls remain the preferred basic API:

```gdscript
NucleusLog.debug("Generated patch", &"terrain")
NucleusLog.info("Session connected", &"network")
NucleusLog.warning("Fallback material selected", &"rendering")
NucleusLog.error("Save document rejected", &"save")
```

The severity boundary remains Godot-native:

```text
debug
    print() in debug builds only

info
    print()

warning
    push_warning()

error
    push_error()
```

`warning()` and `error()` are never suppressed by Nucleus verbosity settings.

## Debug/info verbosity

The minimum level is process-local:

```gdscript
NucleusLog.set_minimum_level(NucleusLog.Level.INFO)
```

The filter is intended primarily to reduce development noise.

Semantics:

```text
DEBUG
    debug + info + warning + error

INFO
    info + warning + error

WARNING
    warning + error

ERROR
    warning + error
```

Warnings remain visible even when the minimum is `ERROR`.

This is intentional: a diagnostic preference must not hide engine warnings or
Nucleus contract violations.

Use:

```gdscript
if NucleusLog.is_level_enabled(NucleusLog.Level.DEBUG):
	# Build expensive debug-only diagnostic data here.
	pass
```

when preparing the diagnostic itself would be expensive.

## Structured data

Use the bounded data helpers for dictionaries, arrays and other diagnostic
payloads:

```gdscript
NucleusLog.debug_data(
	"Materialization queue",
	queue.get_debug_snapshot(),
	&"streaming",
)
```

For multiline output:

```gdscript
NucleusLog.debug_data(
	"World state",
	world_snapshot,
	&"world",
	{
		"multiline": true,
		"max_depth": 4,
		"max_items": 16,
	},
)
```

The formatter options are:

```text
multiline
max_depth
max_items
max_string_length
float_precision
sort_dictionary_keys
```

Defaults are intentionally bounded.

## `NucleusLogFormatter`

`NucleusLogFormatter` is pure formatting infrastructure.

It does not:

```text
print
mutate source data
register handlers
call arbitrary object formatting hooks
store global type-overwrite state
```

Examples:

```gdscript
var compact: String = NucleusLogFormatter.format_compact(payload)
var readable: String = NucleusLogFormatter.format_multiline(payload)
```

Arrays and dictionaries report omitted entries:

```text
[1, 2, 3, ... +17]
```

instead of expanding unbounded data.

Objects are summarized conservatively using class, instance identity and resource
path/name information where appropriate.

Nucleus deliberately does not invoke an arbitrary `to_pretty()` method on
objects. Diagnostics should not execute game-owned behavior just to stringify a
value.

## Call-site decoration

Optional call-site decoration can be enabled:

```gdscript
NucleusLog.set_include_callsite(true)
```

In debug builds this adds information such as:

```text
[streaming] [world_streamer.gd:184 @ _refresh_regions()] ...
```

The feature is disabled by default.

It relies on GDScript stack information and is intentionally diagnostic
convenience rather than a required logging contract.

Release correctness must never depend on call-site discovery.

## `NucleusDebugTable`

For repeated structured rows:

```gdscript
var table: String = NucleusDebugTable.format(
	region_rows,
	["region", "state", "progress"],
)

NucleusLog.debug(table, &"streaming")
```

Output is plain text:

```text
| region    | state   | progress |
|-----------|---------|----------|
| island_03 | LOADED  | 1.000    |
| island_04 | LOADING | 0.625    |
```

The formatter bounds:

```text
cell width
row count
nested cell data
```

so a debug table cannot accidentally dump an entire large runtime database.

It returns a `String`; it does not own console output.

## `NucleusFileLogger`

`NucleusFileLogger` remains based on Godot's native `Logger` API.

It captures normal engine/application output, uses a mutex around its file
buffer, and never logs recursively from Logger callbacks.

The runtime log includes:

```text
project
project version when available
Godot version
platform
process ID
start time
```

The process ID is also included in the filename.

This is useful when running:

```text
dedicated server
client A
client B
```

on the same machine.

## File versus console formatting

Console diagnostics may use structured formatting helpers.

The file logger remains plain text.

Do not add BBCode/color-theme dependencies to the file format. Logs intended for
support, CI, aggregation and diffing should remain readable without Godot's
editor renderer.

## Performance boundary

Logging is work.

Avoid per-frame diagnostic formatting on hot paths unless actively diagnosing
that path.

Prefer:

```text
state transition
request admission/completion
failure
measured periodic snapshot
explicit development command
```

over logging every physics/process tick.

For expensive structures:

```gdscript
if NucleusLog.is_level_enabled(NucleusLog.Level.DEBUG):
	NucleusLog.debug_data(
		"AI context",
		build_expensive_ai_snapshot(),
		&"ai",
	)
```

## Security and privacy

Never write:

```text
passwords
authentication secrets
private signing keys
session tokens
personal data that the product should not persist
```

to diagnostics.

A pretty formatter is not a redaction layer.

The consuming product remains responsible for deciding which runtime data is
safe to expose in logs.

## Non-goals

Nucleus diagnostics are not:

```text
an analytics platform
a telemetry backend
an event bus
a remote logging service
a crash-reporting vendor integration
a colored-console framework
a global formatter registry
```

Provider-specific telemetry/crash reporting belongs behind its own optional
integration boundary.
