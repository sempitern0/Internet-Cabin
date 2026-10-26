extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	var version := NucleusSemanticVersion.parse(
		"v1.2.3-alpha.1+build.9"
	)
	expect_true(version != null, "SemVer parser accepts a valid version.")

	if version:
		expect_equal(str(version), "1.2.3-alpha.1+build.9", "SemVer round-trips.")

	expect_true(
		NucleusSemanticVersion.parse("1.02.3") == null,
		"Core numeric identifiers reject leading zeroes.",
	)
	expect_true(
		NucleusSemanticVersion.parse("1.0.0-alpha.01") == null,
		"Prerelease numeric identifiers reject leading zeroes.",
	)

	var precedence := [
		"1.0.0-alpha",
		"1.0.0-alpha.1",
		"1.0.0-alpha.beta",
		"1.0.0-beta",
		"1.0.0-beta.2",
		"1.0.0-beta.11",
		"1.0.0-rc.1",
		"1.0.0",
	]

	for index: int in range(precedence.size() - 1):
		var left := NucleusSemanticVersion.parse(precedence[index])
		var right := NucleusSemanticVersion.parse(precedence[index + 1])
		expect_true(
			left != null and right != null and left.compare_to(right) < 0,
			"SemVer precedence: %s < %s"
			% [precedence[index], precedence[index + 1]],
		)

	var build_a := NucleusSemanticVersion.parse("1.0.0+build.1")
	var build_b := NucleusSemanticVersion.parse("1.0.0+build.2")
	expect_true(
		build_a != null
		and build_b != null
		and build_a.has_same_precedence(build_b),
		"Build metadata does not affect precedence.",
	)
	expect_false(
		build_a != null and build_a.equals(build_b),
		"Equality still includes build metadata.",
	)

	return finish()
