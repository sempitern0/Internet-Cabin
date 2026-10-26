extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	expect_false(
		NucleusNetworkUtils.is_valid_port(1023),
		"Privileged ports are rejected by default.",
	)
	expect_true(
		NucleusNetworkUtils.is_valid_port(1024),
		"First unprivileged port is accepted.",
	)
	expect_true(
		NucleusNetworkUtils.is_valid_port(443, true),
		"Privileged ports can be explicitly allowed.",
	)
	expect_false(
		NucleusNetworkUtils.is_valid_port(65536, true),
		"Ports above 65535 are rejected.",
	)
	expect_true(
		NucleusNetworkUtils.is_valid_websocket_url("wss://example.invalid"),
		"WSS URLs are accepted.",
	)
	expect_false(
		NucleusNetworkUtils.is_valid_websocket_url("https://example.invalid"),
		"HTTP URLs are not accepted as WebSocket endpoints.",
	)

	var nonce := NucleusNetworkUtils.generate_nonce(16)
	expect_equal(nonce.length(), 32, "A 16-byte nonce is encoded as 32 hex chars.")

	return finish()
