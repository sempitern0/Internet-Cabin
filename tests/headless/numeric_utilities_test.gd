extends "res://tests/headless/test_case.gd"

const LOW: int = NucleusBoundedIntMath.INT64_MIN
const HIGH: int = NucleusBoundedIntMath.INT64_MAX


func run() -> Dictionary:
	_test_addition()
	_test_subtraction()
	_test_multiplication()
	_test_grouping()
	_test_compact()
	return finish()


func _test_addition() -> void:
	expect_equal(NucleusBoundedIntMath.add(20, 30), 50, "Adds small integers.")
	expect_equal(NucleusBoundedIntMath.add(HIGH, 1), HIGH, "Addition saturates high.")
	expect_equal(NucleusBoundedIntMath.add(LOW, -1), LOW, "Addition saturates low.")
	expect_equal(NucleusBoundedIntMath.add(LOW, HIGH), -1, "Adds signed extremes.")
	expect_equal(NucleusBoundedIntMath.add(8, -15), -7, "Adds negative operand.")
	expect_equal(NucleusBoundedIntMath.add(80, 50, 0, 100), 100, "Custom upper bound.")
	expect_equal(NucleusBoundedIntMath.add(-30, -20, -40, 40), -40, "Custom lower bound.")
	expect_equal(NucleusBoundedIntMath.add(-5, 20, 10, 0), 10, "Reversed bounds normalized.")
	expect_equal(NucleusBoundedIntMath.add(HIGH, HIGH, -20, 20), 20, "Huge sum clamps.")


func _test_subtraction() -> void:
	expect_equal(NucleusBoundedIntMath.subtract(20, 30), -10, "Subtracts integers.")
	expect_equal(NucleusBoundedIntMath.subtract(HIGH, -1), HIGH, "Subtraction high.")
	expect_equal(NucleusBoundedIntMath.subtract(LOW, 1), LOW, "Subtraction low.")
	expect_equal(NucleusBoundedIntMath.subtract(0, LOW), HIGH, "Subtracts int64 minimum.")
	expect_equal(NucleusBoundedIntMath.subtract(LOW, LOW), 0, "Equal extremes cancel.")
	expect_equal(NucleusBoundedIntMath.subtract(40, -5, 0, 30), 30, "Custom subtraction cap.")
	expect_equal(NucleusBoundedIntMath.subtract(-40, 5, -20, 10), -20, "Custom floor.")


func _test_multiplication() -> void:
	expect_equal(NucleusBoundedIntMath.multiply(12, 13), 156, "Multiplies integers.")
	expect_equal(NucleusBoundedIntMath.multiply(-12, 13), -156, "Negative result.")
	expect_equal(NucleusBoundedIntMath.multiply(-12, -13), 156, "Two negatives.")
	expect_equal(NucleusBoundedIntMath.multiply(HIGH, 2), HIGH, "Positive overflow.")
	expect_equal(NucleusBoundedIntMath.multiply(LOW, 2), LOW, "Negative overflow.")
	expect_equal(NucleusBoundedIntMath.multiply(LOW, -1), HIGH, "Min times minus one.")
	expect_equal(NucleusBoundedIntMath.multiply(-1, LOW), HIGH, "Commuted min overflow.")
	expect_equal(NucleusBoundedIntMath.multiply(LOW, 1), LOW, "Preserves minimum.")
	expect_equal(NucleusBoundedIntMath.multiply(HIGH, -1), -HIGH, "Max times minus one.")
	expect_equal(NucleusBoundedIntMath.multiply(LOW, 0), 0, "Min times zero.")
	expect_equal(NucleusBoundedIntMath.multiply(25, 4, 0, 90), 90, "Custom upper cap.")
	expect_equal(NucleusBoundedIntMath.multiply(-25, 4, -90, 90), -90, "Custom lower cap.")
	expect_equal(NucleusBoundedIntMath.multiply(2, 0, 1, 10), 1, "Zero outside bounds clamps.")
	expect_equal(NucleusBoundedIntMath.multiply(-1, -1, 10, 0), 1, "Reversed bounds.")
	expect_equal(
		NucleusBoundedIntMath.multiply(3037000499, 3037000499),
		9223372030926249001,
		"Safe near-limit square.",
	)
	expect_equal(
		NucleusBoundedIntMath.multiply(3037000500, 3037000500),
		HIGH,
		"Adjacent square saturates.",
	)


func _test_grouping() -> void:
	expect_equal(NucleusNumberFormatter.grouped(0), "0", "Zero unchanged.")
	expect_equal(NucleusNumberFormatter.grouped(123456789), "123,456,789", "Groups by three.")
	expect_equal(NucleusNumberFormatter.grouped(-1234567, "."), "-1.234.567", "Custom separator.")
	expect_equal(NucleusNumberFormatter.grouped(123456, " ", 2), "12 34 56", "Custom group size.")
	expect_equal(NucleusNumberFormatter.grouped(123, ",", 0), "123", "Invalid group size.")
	expect_equal(NucleusNumberFormatter.grouped(12345, ""), "12345", "Empty separator.")
	expect_equal(
		NucleusNumberFormatter.grouped(LOW),
		"-9,223,372,036,854,775,808",
		"Formats int64 minimum.",
	)
	expect_equal(
		NucleusNumberFormatter.grouped(HIGH),
		"9,223,372,036,854,775,807",
		"Formats int64 maximum.",
	)


func _test_compact() -> void:
	expect_equal(NucleusNumberFormatter.compact(0), "0", "Zero unchanged.")
	expect_equal(NucleusNumberFormatter.compact(-999), "-999", "Small signed values unchanged.")
	expect_equal(NucleusNumberFormatter.compact(1000), "1K", "Thousands suffix.")
	expect_equal(NucleusNumberFormatter.compact(1250), "1.3K", "Half-up rounding.")
	expect_equal(NucleusNumberFormatter.compact(-1250), "-1.3K", "Negative rounding.")
	expect_equal(NucleusNumberFormatter.compact(1234567, 2), "1.23M", "Two decimals.")
	expect_equal(NucleusNumberFormatter.compact(1234567, 3), "1.235M", "Three decimals.")
	expect_equal(NucleusNumberFormatter.compact(999949, 1), "999.9K", "Below rounding threshold.")
	expect_equal(NucleusNumberFormatter.compact(999950, 1), "1M", "Magnitude carry on rounding.")
	expect_equal(NucleusNumberFormatter.compact(999500, 0), "1M", "Integer rounding carry.")
	expect_equal(NucleusNumberFormatter.compact(1999, 0), "2K", "Integer rounding.")
	expect_equal(
		NucleusNumberFormatter.compact(1001, 3, ",", false),
		"1,001K",
		"Decimal separator and padding.",
	)
	expect_equal(
		NucleusNumberFormatter.compact(1000, 2, ".", false),
		"1.00K",
		"Optional trailing zeroes.",
	)
	expect_equal(NucleusNumberFormatter.compact(1000000000000), "1T", "Trillion suffix.")
	expect_equal(NucleusNumberFormatter.compact(1000000000000000), "1Qa", "Quadrillion suffix.")
	expect_equal(NucleusNumberFormatter.compact(1000000000000000000), "1Qi", "Quintillion suffix.")
	expect_equal(NucleusNumberFormatter.compact(HIGH, 2), "9.22Qi", "Maximum integer in short scale.")
	expect_equal(NucleusNumberFormatter.compact(LOW, 2), "-9.22Qi", "Minimum integer in short scale.")
	expect_equal(NucleusNumberFormatter.compact(1200, -4), "1K", "Negative precision clamped.")
	expect_equal(NucleusNumberFormatter.compact(1234, 99), "1.234K", "Precision clamped to three.")
