extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_standalone_provider()
	_test_platform_service_delegation()
	return finish()


func _test_standalone_provider() -> void:
	var provider := NucleusNullPlatformProvider.new()

	expect_true(
		provider.is_available(),
		"Standalone platform provider should always be available.",
	)
	expect_equal(
		provider.initialize(),
		OK,
		"Standalone provider should initialize without an external SDK.",
	)
	expect_equal(
		provider.get_provider_id(),
		&"standalone",
		"Standalone provider should expose a stable provider ID.",
	)
	expect_true(
		provider.get_local_user().is_valid(),
		"Standalone provider should expose a valid local identity.",
	)
	expect_true(
		provider.has_capability(
			NucleusPlatformCapabilities.IDENTITY
		),
		"Standalone provider should advertise identity capability.",
	)

	provider.shutdown()

	expect_false(
		provider.is_initialized(),
		"Provider shutdown should clear initialized state.",
	)

	provider.free()


func _test_platform_service_delegation() -> void:
	var provider := NucleusNullPlatformProvider.new()
	var service := NucleusPlatformService.new()
	service.provider = provider
	service.use_standalone_fallback = false
	service.initialize_on_ready = false

	expect_equal(
		service.initialize_provider(),
		OK,
		"PlatformService should initialize its explicit provider.",
	)
	expect_true(
		service.is_ready(),
		"PlatformService should report ready after provider initialization.",
	)
	expect_equal(
		service.get_provider_id(),
		&"standalone",
		"PlatformService should delegate provider identity.",
	)
	expect_true(
		service.has_capability(
			NucleusPlatformCapabilities.IDENTITY
		),
		"PlatformService should delegate capability checks.",
	)

	service.free()
	provider.shutdown()
	provider.free()
