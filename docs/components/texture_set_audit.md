# PBR Texture Set Audit

`NucleusTextureSetAudit` is development-time filename-level hygiene for common PBR
asset packages.

It complements `NucleusTextureAudit`.

## Why this exists

Vendor packages commonly include:

```text
Color / Albedo
NormalGL
NormalDX
Roughness
AO
ARM / ORM
Displacement / Height
preview/source assets
```

The game often needs only a subset.

Importing a file does not mean it should be sampled by a runtime shader.

## Usage

```gdscript
var findings := NucleusTextureSetAudit.inspect_paths(
	PackedStringArray([
		"res://rock_Color.jpg",
		"res://rock_NormalGL.jpg",
		"res://rock_NormalDX.jpg",
		"res://rock_Roughness.jpg",
		"res://rock_ARM.jpg",
	])
)
```

## Diagnostics

The audit can report:

```text
NormalGL + NormalDX
standalone Roughness + ARM/ORM
standalone AO + ARM/ORM
Displacement/Height data requiring an intentional consumer
```

These are review opportunities, not automatic errors.

## Filename handling

The classifier understands common suffixes and common trailing resolution tokens,
for example:

```text
rock_NormalGL.jpg
rock_arm_1k.jpg
rock_roughness_1k.jpg
Grass001_1K-JPG_NormalGL.jpg
```

It groups maps by their inferred common texture-set stem.

## Boundaries

The audit never:

```text
deletes assets
rewrites imports
changes shader parameters
decides whether ARM or standalone channels are artistically correct
assumes displacement should be enabled
```

After selecting the runtime maps, use `NucleusTextureAudit` to review their import
settings, dimensions, mipmaps and GPU compression.
