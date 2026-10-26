extends "res://tests/headless/test_case.gd"
## Deterministic recovery tests without opening real sockets.


class FakeHandler extends NucleusNetworkHandler:
	var starts: int = 0
	var shutdowns: int = 0
	var fail_starts_until: int = 0
	var last_address: String = ""

	func _ready() -> void:
		pass

	func start_enet_client(
		address: String,
		_port: int = 42069,
		_channel_count: int = 0,
		_in_bandwidth: int = 0,
		_out_bandwidth: int = 0,
		_local_port: int = 0,
	) -> Error:
		return _simulate_start(address)

	func start_websocket_client(
		url: String,
		_tls_options: TLSOptions = null,
	) -> Error:
		return _simulate_start(url)

	func _simulate_start(address: String) -> Error:
		starts += 1
		last_address = address
		if starts <= fail_starts_until:
			state = NucleusNetworkTypes.State.OFFLINE
			return ERR_CANT_CONNECT
		state = NucleusNetworkTypes.State.CONNECTING
		return OK

	func shutdown() -> void:
		shutdowns += 1
		state = NucleusNetworkTypes.State.OFFLINE

	func simulate_connected() -> void:
		state = NucleusNetworkTypes.State.CLIENT
		connected_to_server.emit()

	func simulate_lost() -> void:
		state = NucleusNetworkTypes.State.OFFLINE
		server_disconnected.emit()

	func simulate_connect_failed() -> void:
		state = NucleusNetworkTypes.State.OFFLINE
		connection_failed.emit()


class FakeController extends NucleusNetworkReconnectController:
	var fake_clock_msec: int = 1000

	func _now_msec() -> int:
		return fake_clock_msec

	func advance(milliseconds: int) -> void:
		fake_clock_msec += milliseconds
		_process(0.0)


func run() -> Dictionary:
	_test_policy()
	_test_connect_and_reconnect()
	_test_timeout_and_backoff()
	_test_failure_event_and_total_budget()
	_test_stale_restore_token()
	_test_restore_rejected()
	_test_restoration_timeout()
	_test_auto_reconnect_disabled()
	_test_websocket_and_invalid_config()
	return finish()


func _make_fixture() -> Dictionary:
	var root := Node.new()
	var network := FakeHandler.new()
	var recovery := FakeController.new()
	recovery.handler = network
	recovery.policy = NucleusNetworkReconnectPolicy.new()
	root.add_child(network)
	root.add_child(recovery)
	expect_true(attach_test_node(root), "Recovery test scene must attach.")
	return {"root": root, "network": network, "recovery": recovery}


func _test_policy() -> void:
	var p := NucleusNetworkReconnectPolicy.new()
	expect_float(p.delay_after_failure(1), 0.25, "First delay.")
	expect_float(p.delay_after_failure(2), 0.5, "Exponential delay.")
	expect_float(p.delay_after_failure(10), 5.0, "Backoff cap.")
	p.max_delay_seconds = 0.1
	expect_false(p.get_validation_errors().is_empty(), "Invalid policy rejected.")


func _test_connect_and_reconnect() -> void:
	var f: Dictionary = _make_fixture()
	var n: FakeHandler = f["network"]
	var c: FakeController = f["recovery"]
	c.require_session_restore = true

	expect_equal(c.connect_enet("127.0.0.1"), OK, "Initial request accepted.")
	expect_equal(
		c.phase,
		NucleusNetworkReconnectController.Phase.CONNECTING,
		"Initial transport is pending.",
	)
	expect_equal(n.starts, 1, "Initial connect attempts once.")
	n.simulate_connected()
	expect_equal(
		c.phase,
		NucleusNetworkReconnectController.Phase.RESTORING,
		"Transport is not game readiness.",
	)
	var initial_token: int = c.get_request_token()
	expect_equal(c.complete_session_restore(initial_token, true), OK, "Initial restore.")
	expect_true(c.is_session_ready(), "Game readiness follows acknowledgement.")

	n.simulate_lost()
	expect_equal(
		c.phase,
		NucleusNetworkReconnectController.Phase.WAITING,
		"Unexpected drop begins recovery.",
	)
	c.advance(249)
	expect_equal(n.starts, 1, "No retry before backoff deadline.")
	c.advance(1)
	expect_equal(n.starts, 2, "Retry after backoff.")
	n.simulate_connected()
	var recovery_token: int = c.get_request_token()
	expect_true(recovery_token != initial_token, "Recovery uses a new generation.")
	expect_equal(
		c.complete_session_restore(initial_token, true),
		ERR_INVALID_PARAMETER,
		"Old acknowledgement cannot restore a new transport.",
	)
	expect_equal(c.complete_session_restore(recovery_token, true), OK, "Recovery ack.")
	expect_true(c.is_session_ready(), "Session is usable after recovery.")

	free_test_node(f["root"])


func _test_timeout_and_backoff() -> void:
	var f: Dictionary = _make_fixture()
	var n: FakeHandler = f["network"]
	var c: FakeController = f["recovery"]
	c.policy.max_attempts = 3
	c.policy.attempt_timeout_seconds = 1.0
	n.fail_starts_until = 2

	expect_equal(c.connect_enet("example.test"), OK, "Retrying request accepted.")
	expect_equal(
		c.phase,
		NucleusNetworkReconnectController.Phase.WAITING,
		"First start failed and scheduled.",
	)
	c.advance(250)
	expect_equal(n.starts, 2, "Second attempt after 250 ms.")
	c.advance(500)
	expect_equal(n.starts, 3, "Third attempt after 500 ms.")
	expect_equal(
		c.phase,
		NucleusNetworkReconnectController.Phase.CONNECTING,
		"Third attempt is pending.",
	)
	c.advance(1000)
	expect_equal(
		c.phase,
		NucleusNetworkReconnectController.Phase.FAILED,
		"Attempts exhausted on timeout.",
	)
	expect_equal(c.last_error, ERR_TIMEOUT, "Timeout is reported.")
	expect_equal(n.shutdowns, 1, "Timed-out owned peer is closed.")

	free_test_node(f["root"])


func _test_failure_event_and_total_budget() -> void:
	var f: Dictionary = _make_fixture()
	var n: FakeHandler = f["network"]
	var c: FakeController = f["recovery"]
	c.policy.total_timeout_seconds = 1.5
	c.policy.attempt_timeout_seconds = 10.0
	c.connect_enet("test.local")
	n.simulate_connect_failed()
	expect_equal(c.phase, NucleusNetworkReconnectController.Phase.WAITING,
		"Handshake failure schedules bounded retry.")
	c.advance(250)
	expect_equal(n.starts, 2, "Retry follows connect-failed signal.")
	c.advance(1250)
	expect_equal(c.phase, NucleusNetworkReconnectController.Phase.FAILED,
		"Overall elapsed budget ends even a long-running handshake.")
	expect_equal(c.last_error, ERR_TIMEOUT, "Total timeout has explicit error.")
	expect_true(n.shutdowns > 0, "Expired cycle releases owned transport.")
	free_test_node(f["root"])


func _test_stale_restore_token() -> void:
	var f: Dictionary = _make_fixture()
	var n: FakeHandler = f["network"]
	var c: FakeController = f["recovery"]
	c.require_session_restore = true
	c.connect_enet("test.local")
	n.simulate_connected()
	var stale_token: int = c.get_request_token()
	c.stop()
	expect_equal(c.phase, NucleusNetworkReconnectController.Phase.IDLE, "Leave cancels restoration.")
	expect_equal(
		c.complete_session_restore(stale_token, true),
		ERR_INVALID_PARAMETER,
		"Late restore ignored after Leave.",
	)
	c.connect_enet("test.local")
	n.simulate_connected()
	expect_equal(
		c.complete_session_restore(stale_token, true),
		ERR_INVALID_PARAMETER,
		"Old token rejected after a fresh connect.",
	)
	c.stop()
	free_test_node(f["root"])


func _test_restore_rejected() -> void:
	var f: Dictionary = _make_fixture()
	var n: FakeHandler = f["network"]
	var c: FakeController = f["recovery"]
	c.require_session_restore = true
	c.connect_enet("test.local")
	n.simulate_connected()
	var token: int = c.get_request_token()
	expect_equal(c.complete_session_restore(token, false), OK, "Rejection handled.")
	expect_equal(
		c.phase,
		NucleusNetworkReconnectController.Phase.FAILED,
		"Identity mismatch fails closed.",
	)
	expect_equal(c.last_error, ERR_UNAUTHORIZED, "Failure remains explicit.")
	expect_false(c.is_session_ready(), "Rejected session never ready.")
	expect_equal(n.shutdowns, 1, "Rejected connection closed.")
	free_test_node(f["root"])


func _test_restoration_timeout() -> void:
	var f: Dictionary = _make_fixture()
	var n: FakeHandler = f["network"]
	var c: FakeController = f["recovery"]
	c.require_session_restore = true
	c.policy.restore_timeout_seconds = 1.0
	c.connect_enet("test.local")
	n.simulate_connected()
	var previous_token: int = c.get_request_token()
	c.advance(1000)
	expect_equal(
		c.phase,
		NucleusNetworkReconnectController.Phase.WAITING,
		"Restore timeout schedules retry.",
	)
	expect_equal(n.shutdowns, 1, "Timed-out restore shuts down transport.")
	c.advance(250)
	expect_equal(
		c.phase,
		NucleusNetworkReconnectController.Phase.CONNECTING,
		"Retry starts from offline.",
	)
	n.simulate_connected()
	expect_equal(
		c.complete_session_restore(previous_token, true),
		ERR_INVALID_PARAMETER,
		"Delayed response cannot acknowledge retried restoration.",
	)
	c.stop()
	free_test_node(f["root"])


func _test_auto_reconnect_disabled() -> void:
	var f: Dictionary = _make_fixture()
	var n: FakeHandler = f["network"]
	var c: FakeController = f["recovery"]
	c.auto_reconnect = false
	c.connect_enet("test.local")
	n.simulate_connected()
	n.simulate_lost()
	expect_equal(
		c.phase,
		NucleusNetworkReconnectController.Phase.FAILED,
		"Disabled recovery terminates on loss.",
	)
	expect_equal(n.starts, 1, "No implicit second attempt.")
	c.stop()
	n.simulate_lost()
	expect_equal(
		c.phase,
		NucleusNetworkReconnectController.Phase.IDLE,
		"Intentional leave never reconnects.",
	)
	free_test_node(f["root"])


func _test_websocket_and_invalid_config() -> void:
	var f: Dictionary = _make_fixture()
	var n: FakeHandler = f["network"]
	var c: FakeController = f["recovery"]
	expect_equal(c.connect_websocket("https://test.local"), ERR_INVALID_PARAMETER,
		"HTTP is not a WebSocket URL.")
	expect_equal(c.connect_websocket("wss://test.local"), OK, "WSS starts.")
	expect_equal(n.last_address, "wss://test.local", "Target forwarded.")
	expect_equal(c.connect_enet("test.local"), ERR_BUSY, "Concurrent connect blocked.")
	c.stop()
	c.policy.max_attempts = 0
	expect_equal(c.connect_websocket("wss://test.local"), ERR_INVALID_PARAMETER,
		"Invalid recovery profile prevents startup.")
	free_test_node(f["root"])
