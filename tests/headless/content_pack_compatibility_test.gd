extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_equal_and_order_independent()
	_test_missing_and_mismatched()
	_test_local_extras_policy()
	_test_invalid_inventories()
	return finish()


func _test_equal_and_order_independent() -> void:
	var first := _pack("alpha", "1.0.0", "a")
	var second := _pack("beta", "2.0.0", "b")
	var required: Array[NucleusContentPackManifest] = [first, second]
	var available: Array[NucleusContentPackManifest] = [second, first]
	var result := NucleusContentPackCompatibility.compare(required, available)
	expect_equal(result.error, OK, "Valid inventories should compare.")
	expect_true(result.compatible, "Manifest comparison ignores inventory ordering.")
	expect_true(result.missing.is_empty(), "Matching packs are not missing.")
	expect_true(result.extra.is_empty(), "Matching packs are not extra.")
	expect_true(result.mismatched.is_empty(), "Matching packs are identical.")


func _test_missing_and_mismatched() -> void:
	var required: Array[NucleusContentPackManifest] = [
		_pack("beta", "2.0.0", "b"),
		_pack("alpha", "1.0.0", "a"),
		_pack("gamma", "1.0.0", "c"),
	]
	var available: Array[NucleusContentPackManifest] = [
		_pack("beta", "3.0.0", "b"),
		_pack("alpha", "1.0.0", "f"),
	]
	var result := NucleusContentPackCompatibility.compare(required, available)
	expect_equal(result.error, OK, "Different inventories are valid comparisons.")
	expect_false(result.compatible, "Missing and changed packs must block compatibility.")
	expect_equal(result.missing, ["gamma"], "Missing IDs have stable ordering.")
	expect_equal(result.mismatched.size(), 2, "Distinct mismatches are reported.")
	expect_equal(result.mismatched[0]["pack_id"], "alpha", "Mismatch order is stable.")
	expect_true(
		"archive_sha256" in result.mismatched[0]["fields"],
		"Identical version with altered archive must be detected.",
	)
	expect_true(
		"version" in result.mismatched[1]["fields"],
		"Version mismatches must be detected.",
	)


func _test_local_extras_policy() -> void:
	var required: Array[NucleusContentPackManifest] = [_pack("alpha", "1.0.0", "a")]
	var available: Array[NucleusContentPackManifest] = [
		_pack("zeta", "1.0.0", "b"),
		_pack("alpha", "1.0.0", "a"),
		_pack("beta", "1.0.0", "c"),
	]
	var strict := NucleusContentPackCompatibility.compare(required, available)
	expect_false(strict.compatible, "Unexpected local content fails by default.")
	expect_equal(strict.extra, ["beta", "zeta"], "Extra pack IDs are sorted.")
	var permissive := NucleusContentPackCompatibility.compare(required, available, true)
	expect_true(permissive.compatible, "Explicit policy may allow extra local packs.")
	expect_equal(permissive.extra.size(), 2, "Allowed extras remain visible to policy.")


func _test_invalid_inventories() -> void:
	var good := _pack("alpha", "1.0.0", "a")
	var empty: Array[NucleusContentPackManifest] = []
	var duplicated: Array[NucleusContentPackManifest] = [good, good]
	var duplicate_result := NucleusContentPackCompatibility.compare(duplicated, empty)
	expect_equal(duplicate_result.error, ERR_INVALID_DATA, "Duplicate IDs are invalid.")
	expect_false(duplicate_result.compatible, "Invalid inventory never passes.")

	var invalid := _pack("alpha", "1.0.0", "a")
	invalid.archive_sha256 = "not_sha256"
	var invalid_list: Array[NucleusContentPackManifest] = [invalid]
	expect_equal(
		NucleusContentPackCompatibility.compare(invalid_list, empty).error,
		ERR_INVALID_DATA,
		"Malformed digest is rejected before comparison.",
	)

	var changed_dependency := _pack("alpha", "1.0.0", "a")
	changed_dependency.dependencies = PackedStringArray(["beta"])
	var changed_inventory: Array[NucleusContentPackManifest] = [changed_dependency]
	var baseline_inventory: Array[NucleusContentPackManifest] = [good]
	var dependency_result := NucleusContentPackCompatibility.compare(
		baseline_inventory, changed_inventory,
	)
	expect_equal(dependency_result.error, OK,
		"Valid differing dependency metadata may be compared.")
	expect_true("dependencies" in dependency_result.mismatched[0]["fields"],
		"Dependency differences cannot pass content compatibility.")

	var ordered := _pack("alpha", "1.0.0", "a")
	ordered.dependencies = PackedStringArray(["beta", "zeta"])
	var unordered := _pack("alpha", "1.0.0", "a")
	unordered.dependencies = PackedStringArray(["zeta", "beta"])
	var ordered_list: Array[NucleusContentPackManifest] = [ordered]
	var unordered_list: Array[NucleusContentPackManifest] = [unordered]
	expect_true(
		NucleusContentPackCompatibility.compare(ordered_list, unordered_list).compatible,
		"Dependency order must not change semantic compatibility.",
	)

	var null_list: Array[NucleusContentPackManifest] = [null]
	expect_equal(
		NucleusContentPackCompatibility.compare(null_list, empty).error,
		ERR_INVALID_DATA,
		"Null manifests fail closed.",
	)

	var oversized: Array[NucleusContentPackManifest] = []
	oversized.resize(NucleusContentPackCompatibility.MAX_PACKS + 1)
	expect_equal(
		NucleusContentPackCompatibility.compare(oversized, empty).error,
		ERR_INVALID_DATA,
		"Inventory size is bounded before indexing.",
	)


func _pack(pack_id: String, version: String, digest_char: String) -> NucleusContentPackManifest:
	var manifest := NucleusContentPackManifest.new()
	manifest.pack_id = StringName(pack_id)
	manifest.display_name = pack_id
	manifest.version = version
	manifest.kind = NucleusContentPackTypes.Kind.DLC
	manifest.resource_prefix = "res://content/%s/" % pack_id
	manifest.archive_sha256 = digest_char.repeat(64)
	return manifest
