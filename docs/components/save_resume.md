# Save Resume Selection Contract

## Scope

`NucleusSave.load_latest()` and `NucleusSaveSession.load_latest()` provide a
resume-oriented read across manual, quick and autosave snapshots.

Storage, integrity, migrations and backup recovery remain owned by the existing
save repository. Resume selection only decides which successful candidate is the
newest.

## Default policy

With no explicit kind list, the candidate order is:

```text
AUTOSAVE
QUICKSAVE
MANUAL
```

The **timestamp** decides first. Kind order is used only when two snapshots have
the exact same timestamp.

This means an older autosave never beats a newer manual save merely because it
appears first in the default kind list.

Use a custom order when a product has a different exact-tie policy:

```gdscript
var result := NucleusSave.load_latest(
	"slot_1",
	PackedInt32Array([
		NucleusSaveTypes.Kind.MANUAL,
		NucleusSaveTypes.Kind.AUTOSAVE,
	]),
)
```

## Microsecond timestamps

New documents persist:

```text
created_at_unix_usec
updated_at_unix_usec
```

alongside the existing whole-second fields.

Older save documents remain readable. When the microsecond field is absent,
Nucleus derives it from the whole-second timestamp.

The container version does not change because the new fields are additive and
optional on read.

## Failure behavior

`load_latest()` reads candidate kinds through the repository without emitting
one public load failure for every missing kind.

The service emits one final load result:

```text
newest valid candidate
or
first meaningful non-missing error
or
ERR_FILE_NOT_FOUND
```

Migration runs only after selection. Manual/quicksave migration may still rewrite
the migrated document according to the existing save profile. Autosave migration
remains non-rewriting.

## Session integration

`NucleusSaveSession.load_latest()` applies the selected payload through the same
participant restore path as the existing manual/quick/autosave methods.

A typical Continue action can therefore be:

```gdscript
var result := save_session.load_latest()

if not result.succeeded():
	show_load_error(result.error)
```

Games still own slot selection, save-slot presentation and whether a Continue
button is shown.
