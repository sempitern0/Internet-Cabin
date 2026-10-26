# World Stream Materialization

`NucleusWorldStreamMaterializationBinding` is an optional bridge between:

```text
NucleusWorldStreamLifecycle request tokens
        ↓
NucleusMaterializationQueue jobs
```

It does not decide which regions are desired or what a region contains.

## Public addition

`NucleusWorldStreamLifecycle` now also supports:

```gdscript
cancel_request(region_id, request_token)
```

Cancellation differs from failure:

```text
LOADING
    → UNLOADED

UNLOADING
    → LOADED
```

Use it when an admitted request became obsolete rather than failed.

## Binding ownership

The game still owns:

```text
region descriptors
load/unload semantics
job creation
scene hierarchy
persistence
prefetch policy
spatial policy
```

The binding only maps terminal job state to the current request token.

## Completion mapping

```text
job COMPLETED
    → mark_loaded() / mark_unloaded()

job FAILED
    → mark_request_failed()

job CANCELLED
    → cancel_request()
```

Old request tokens remain protected by the lifecycle's existing stale-token
checks.

## Stale cancellation

With:

```text
cancel_stale_requests = true
```

the binding cancels:

```text
load job whose region is no longer desired
unload job whose region became desired again
```

This avoids spending CPU finishing obsolete incremental work.

Consumers that do not use this binding retain the original lifecycle behavior:
an in-flight operation may finish and the next pump converges state normally.

## Typical composition

```text
GameStreamingCoordinator
├── WorldStreamLifecycle
├── MaterializationQueue
└── WorldStreamMaterializationBinding
```

On admission:

```gdscript
func _on_load_requested(
	region_id: StringName,
	request_token: int,
) -> void:
	var job := create_region_job(region_id)

	if job == null:
		lifecycle.mark_request_failed(
			region_id,
			request_token,
			NucleusWorldStreamLifecycle.Operation.LOAD,
			ERR_CANT_CREATE,
		)
		return

	materialization_binding.submit_job(
		region_id,
		request_token,
		NucleusWorldStreamLifecycle.Operation.LOAD,
		job,
	)
```

The game attaches/owns the job result.

## Non-goals

This binding is not:

```text
a spatial partition
a world manager
a terrain streamer
a persistence service
a network relevancy system
a job factory
```

It is only the safe seam between existing region lifecycle tokens and bounded
incremental work.
