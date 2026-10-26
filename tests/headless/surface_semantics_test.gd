extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_profile_contract()
	_test_collider_provider()
	_test_shape_specific_precedence()
	_test_priority_within_scope()
	_test_ancestor_fallback()
	_test_provider_warning()
	return finish()


func _test_profile_contract() -> void:
	var profile := _profile(&"stone", [&"hard", &"natural"])

	expect_true(profile.has_tag(&"hard"), "Surface profile resolves one tag.")
	expect_true(
		profile.has_any_tag([&"soft", &"natural"]),
		"Surface profile resolves any matching tag.",
	)
	expect_true(
		profile.has_all_tags([&"hard", &"natural"]),
		"Surface profile resolves all requested tags.",
	)
	expect_true(
		profile.get_validation_errors().is_empty(),
		"Valid surface profile has no validation errors.",
	)

	var invalid := NucleusSurfaceProfile.new()
	invalid.tags = [&"hard", &"hard", &""]
	expect_true(
		invalid.get_validation_errors().size() >= 3,
		"Invalid ids, duplicate tags, and empty tags are rejected.",
	)


func _test_collider_provider() -> void:
	var body := StaticBody3D.new()
	var provider := _provider(_profile(&"wood", [&"organic"]))
	body.add_child(provider)

	var query := NucleusSurfaceQuery3D.new(body)
	var resolved := NucleusSurfaceResolver3D.resolve(query)

	expect_equal(
		resolved.surface_id if resolved else &"",
		&"wood",
		"Collider-owned provider resolves its profile.",
	)
	body.free()


func _test_shape_specific_precedence() -> void:
	var body := StaticBody3D.new()
	var body_provider := _provider(_profile(&"concrete"))
	body.add_child(body_provider)

	var shape_owner_node := Node3D.new()
	body.add_child(shape_owner_node)
	var owner_id := body.create_shape_owner(shape_owner_node)
	body.shape_owner_add_shape(owner_id, BoxShape3D.new())
	var shape_index := body.shape_owner_get_shape_index(owner_id, 0)

	var shape_provider := _provider(_profile(&"metal"))
	shape_owner_node.add_child(shape_provider)

	var query := NucleusSurfaceQuery3D.new(
		body,
		Vector3.ZERO,
		Vector3.UP,
		shape_index,
	)
	var resolved := NucleusSurfaceResolver3D.resolve(query)

	expect_equal(
		resolved.surface_id if resolved else &"",
		&"metal",
		"Impacted shape semantics override collider fallback semantics.",
	)
	body.free()


func _test_priority_within_scope() -> void:
	var body := StaticBody3D.new()
	var low := _provider(_profile(&"low"), 1)
	var high := _provider(_profile(&"high"), 20)
	body.add_child(low)
	body.add_child(high)

	var resolved := NucleusSurfaceResolver3D.resolve(
		NucleusSurfaceQuery3D.new(body)
	)

	expect_equal(
		resolved.surface_id if resolved else &"",
		&"high",
		"Higher-priority source wins within the same ownership scope.",
	)
	body.free()


func _test_ancestor_fallback() -> void:
	var root := Node3D.new()
	var body := StaticBody3D.new()
	root.add_child(body)
	root.add_child(_provider(_profile(&"world_default")))

	var resolved := NucleusSurfaceResolver3D.resolve(
		NucleusSurfaceQuery3D.new(body)
	)

	expect_equal(
		resolved.surface_id if resolved else &"",
		&"world_default",
		"Nearest ancestor scope can provide fallback surface semantics.",
	)
	root.free()


func _test_provider_warning() -> void:
	var provider := NucleusSurfaceProvider3D.new()
	expect_true(
		not provider._get_configuration_warnings().is_empty(),
		"Surface provider warns when no profile is assigned.",
	)
	provider.free()


func _profile(
	surface_id: StringName,
	tags: Array[StringName] = [],
) -> NucleusSurfaceProfile:
	var profile := NucleusSurfaceProfile.new()
	profile.surface_id = surface_id
	profile.tags = tags.duplicate()
	return profile


func _provider(
	profile: NucleusSurfaceProfile,
	priority: int = 0,
) -> NucleusSurfaceProvider3D:
	var provider := NucleusSurfaceProvider3D.new()
	provider.profile = profile
	provider.priority = priority
	return provider
