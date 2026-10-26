# Godot Compatibility Policy

## Current support contract

Nucleus currently targets the Godot 4.7 line. The CI/release-gated reference is:

```text
Godot 4.7.2-stable
```

| Godot version | Nucleus policy |
| --- | --- |
| 4.7.2-stable | Supported and CI-gated |
| later 4.7.x patches | expected compatible; promote only after validation |
| 4.7.0–4.7.1 | not guaranteed |
| 4.8.x+ | unsupported until explicitly adopted |
| 4.6.x and older | unsupported |

Unsupported means no compatibility promise, not necessarily a known failure.

## Why the exact reference matters

Patch releases can change parser behavior, warnings, exporters and engine internals
while project metadata still declares the same minor feature line. Compatibility
claims therefore come from the engine CI actually imports, tests and exports.

## Upgrade process

A reference-version change requires:

1. update the CI pin;
2. headless import;
3. compile/run the full native test scene;
4. run smoke scenes;
5. smoke-export Linux, Windows and Web;
6. review warnings/deprecations;
7. update compatibility and migration/release documentation;
8. make the appropriate Nucleus version decision.

## Rendering and exports

The default project declares Forward Plus. CI smoke exports Linux, Windows and
Web to validate packaging of the reusable baseline. That does not promise that
every consuming game's shader, native extension, platform SDK or asset pipeline
supports those targets.

## Dependencies

Nucleus prefers Godot-native APIs and does not require a third-party runtime test
framework. Optional external plugins keep their own compatibility contracts.
