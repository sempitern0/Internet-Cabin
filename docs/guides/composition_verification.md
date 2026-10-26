# Composition verification in Nucleus

## Goal

A green static audit proves syntax and policy conventions, not that a game
scene is using the right Nucleus owner. Verification must cover the actual
wiring and behavior. The headless suite `composition_contracts_test.gd`
illustrates this without adding game-specific starters or a testing framework.

## Four checks for scene-owned composition

1. **One authority:** Instantiate the existing `NucleusStateMachine` and its
   `NucleusState` children; transition through the machine instead of mutating
   the state variable from an independent controller. A denied transition
   must not exit the active state.
2. **Correct lifecycle:** Test real `SceneTree` attachment and disposal, not
   manually invoking `_ready()` as a substitute. An attached
   `NucleusUISceneLoadBinding` must connect to the `NucleusSceneFlow` signals,
   and all connections must disappear on release.
3. **Time/profiling boundaries:** Reuse `NucleusPerformanceSectionProfiler`
   with two monotonic timestamps to record a synchronous or cross-phase
   interval; stale tokens must be rejected. See `input_response_measurement.md`.
4. **Presentation independence:** `NucleusUIAnimatedValue` must use the motion
   policy, honor a zero-duration request immediately and cancel an obsolete
   tween when a newer value arrives. The game owns the numeric value; UI
   components own only its visualization.

## Running the suites

From the Nucleus project root, with the same Godot version as the project:

```bash
godot --headless --path . --import
godot --headless --path . res://tests/headless/test_runner.tscn
python3 scripts/ci/static_checks.py
python3 scripts/ci/documentation_audit.py
```

The headless runner exits non-zero for failing assertions. The repository's
canonical CI workflow remains the final reference for the exact Godot
invocation. Run related game scenes separately, because **framework fixture
success does not prove that a consuming game has wired its own scenes**.

## Explicit non-goals

- No new FSM, action orchestrator, save service, event bus, or DI container.
- No game genre defaults, starter controller, network authority policy, or
  automatic scene rewrites.
- No `class_name Nucleus*` prefix imposed on game-owned project scripts.

The suite is a reusable testing pattern. Extend it for specific regressions,
not for hypothetical integrations that the repository does not yet own.
