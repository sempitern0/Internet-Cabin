# Production Hardening and Validation

## Objective

Nucleus includes validation infrastructure so a reusable project foundation is
easier to trust, test, and maintain without requiring a third-party test stack.

## Native headless tests

The dependency-free GDScript suites live under `tests/headless/`.

Deterministic coverage targets high-value contracts such as:

```text
SemVer parsing/precedence
ValuePool behavior
network utilities and replication helpers
input binding serialization
settings contracts
editor configuration warnings
optional module invariants
world/environment component contracts
```

## Test-suite contract

`tests/headless/test_case.gd` is the assertion API:

```text
expect_true
expect_false
expect_equal
expect_float
finish
```

Suites define `run() -> Dictionary`, return through `finish()`, and are
registered in `test_manifest.gd`.

`scripts/ci/static_checks.py` verifies this structure without requiring Godot.
Godot remains authoritative for engine symbols, typed APIs, and GDScript
semantics.

## Project-scene test gate

The authoritative native runner is:

```text
tests/headless/test_runner.tscn
```

It is intentionally a normal project scene rather than a `SceneTree` script
launched with `--script`.

Nucleus has mandatory project Autoloads such as `NucleusApp`, `NucleusInput`, and
`NucleusSave`. Loading the test graph through a project scene ensures those names
are registered through the same initialization path used by an actual game.

The manifest still uses `preload()`, so loading the runner compiles every
registered suite and its transitive dependencies before assertions can pass.
Compile errors and assertion failures therefore remain one deterministic gate
without relying on a standalone CLI-script context.

Run it with:

```bash
godot --headless --path . res://tests/headless/test_runner.tscn
```

The runner waits for two normal process-frame boundaries before exiting. This
lets deferred frees and rendering/physics cleanup settle instead of turning
normal test teardown into misleading process-exit leak noise.

## SceneTree-aware fixtures

A unit test may instantiate plain Nodes detached from the tree when the API does
not require lifecycle state.

Tests using global transforms, `_ready()`, physics, rendering or similar
SceneTree-dependent APIs must attach their fixture through `attach_test_node()`
and release it through `free_test_node()`.

This keeps lightweight tests lightweight while making lifecycle-dependent tests
explicit instead of accidentally consuming Godot fallback transforms.

## Development validation on detached scenes

`NucleusDevelopmentValidation` supports validating an instantiated subtree even
when that subtree has not been inserted into the active SceneTree.

Its reporting paths are derived from the supplied subtree instead of calling
`get_path()` on a detached root. This matters because scene/resource validation
commonly instantiates content for inspection without making it the running scene.

## Bootstrap smoke test

`tests/smoke/smoke_main.tscn` verifies a compatible Godot runtime and mandatory
default Autoloads. It exits non-zero on failure.

The smoke test remains separate from unit/regression assertions: a missing
mandatory Autoload is a project-bootstrap failure, not an individual unit-test
expectation.

## Validation scenes

`examples/validation/gameplay_2d.tscn` and
`examples/validation/gameplay_3d.tscn` provide removable editor fixtures for
representative gameplay wiring.

## Editor configuration warnings

High-value editor-facing nodes use Godot's native
`_get_configuration_warnings()` mechanism. Runtime guards remain in place; the
warnings surface common wiring errors before Play.

Tests should call Nucleus-owned warning methods where that is the public/defined
contract. They should not assume every native Godot node exposes a callable
`get_configuration_warnings()` API at runtime.

## Static repository checks

`scripts/ci/static_checks.py` enforces:

```text
UTF-8 text
LF endings
final newline
no trailing whitespace
GDScript <= 100 columns
tab indentation
Nucleus prefix for public class_name
headless test-suite contract
test manifest completeness
```

It has no Python package dependencies.

## Documentation consistency

`docs/documentation_coverage.json` maps direct subsystem directories to
technical documents. `scripts/ci/documentation_audit.py` compares that manifest
with repository structure.

## CI

`.github/workflows/nucleus-ci.yml` performs:

```text
static checks
documentation audit
productization audit
Godot headless import
native project-scene tests
bootstrap smoke scene
Linux export
Windows export
Web export
```

The workflow pins Godot `4.7.2-stable`.

## Smoke export isolation

`scripts/ci/smoke_exports.sh` copies the repository to a temporary directory,
sets the smoke scene as `run/main_scene`, and installs CI-only export presets
there. Validation therefore does not mutate the reusable template checkout.

## Acceptance rule

A local editor PASS is useful feedback but is not the production gate. A change
claiming runtime/export validation should pass:

```text
static checks
documentation audit
productization audit
headless import
native project-scene tests
bootstrap smoke scene
Linux / Windows / Web smoke exports
```
