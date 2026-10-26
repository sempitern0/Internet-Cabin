# Tutorial: Save and Restore Scene-owned State

This tutorial builds a `NucleusSaveSession` with explicit participants.

## 1. Compose the session

```text
GameSession
├── SaveSession : NucleusSaveSession
├── Player
├── Inventory
└── World
```

Each subsystem implements plain-data capture/restore methods and registers them
under a stable participant ID.

```gdscript
save_session.register_participant(
    &"player",
    player.capture_state,
    player.restore_state,
)
```

## 2. Keep schemas explicit

A participant should save stable IDs and values, not Nodes, Callables or temporary
scene-tree identity. The participant owns the meaning of its payload; the global
save service owns document format/storage/integrity/migration.

## 3. Save synchronously for small snapshots

```gdscript
var result := save_session.save_manual()
if not result.succeeded():
    push_error(error_string(result.error))
```

Load with `load_manual()`. On success, the session routes participant payloads to
their restore callables.

## 4. Add metadata separately

Use `set_metadata_provider()` for slot-list presentation such as area name,
playtime summary or screenshot path. Metadata is not authoritative gameplay state.

## 5. Add autosave policy

Configure `NucleusAutosavePolicy` for interval, slot rotation and application
lifecycle behavior. Pause/quit saves remain synchronous because the process may
not receive another frame.

## 6. Budget large captures

When many participants create a frame spike:

```gdscript
var result := await save_session.save_manual_incremental(8)
```

or drive the job manually:

```gdscript
var job := save_session.create_capture_job()
while not job.is_completed():
    job.step(8)
    await get_tree().process_frame
```

This distributes main-thread participant capture. It does not move arbitrary Node
access to worker threads.

## 7. Respect dependency order

Restore prerequisites before dependents when their runtime identity is linked
(for example Inventory before Equipment). Late participant registration remains
supported through pending payload.

## Validation

Save, mutate runtime state, load, restart the application and load again. Also
exercise a large incremental snapshot and verify that the final payload is the
same semantic state as the synchronous path.
