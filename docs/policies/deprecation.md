# Nucleus Deprecation Policy

Deprecation makes intentional public-API evolution visible without preserving
obsolete abstractions indefinitely.

## Scope

Deprecation applies to public contracts such as:

```text
public Nucleus class_name identifiers
documented public methods/signals
required Autoload names
serialized exported-property meaning
documented settings/save schemas
documented reusable scene/resource entry points
```

Private underscore-prefixed implementation details may change directly when
public behavior is preserved.

## Before 1.0

Nucleus is pre-1.0. Breaking public changes may occur in a MINOR version when
production evidence shows the existing contract should change. When practical:

1. document the replacement;
2. provide migration guidance for commonly used contracts;
3. preserve the old path through at least one subsequent development/minor cycle;
4. remove it only once the replacement is clear.

This grace period is a goal rather than an absolute pre-1.0 guarantee. Security,
data-loss or engine-compatibility problems may require faster removal.

## From 1.0

Deprecate in a MINOR release and remove in a later MAJOR release unless an urgent
security/data/compatibility issue requires an explicit exception.

## Serialized data

Renaming settings keys, save fields, Resource classes or exported properties can
outlive source-level aliases. Where Nucleus owns persisted data, use explicit
schema/migration behavior instead of relying only on renamed code symbols.

## Removal checklist

Before removing a deprecated contract, search source/docs/examples/tests, update
migration guidance and versioning, and require green validation without the old
path.
