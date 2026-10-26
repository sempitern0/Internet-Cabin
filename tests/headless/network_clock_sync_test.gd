extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_first_sample_and_time_domain()
	_test_smoothing_and_rtt_outliers()
	_test_session_reset_and_replay()
	_test_pending_limits_and_timeouts()
	_test_validation_and_bad_samples()
	_test_stale_estimate_reacquisition()
	return finish()


func _test_first_sample_and_time_domain() -> void:
	var clock := NucleusNetworkClockSync.new()
	expect_equal(clock.get_session_id(), 0, "Sessions require explicit initialization.")
	expect_true(clock.create_request(1000000).is_empty(), "No request before session.")
	expect_equal(clock.get_server_ticks_usec(1000000), -1, "No unmeasured server time.")

	var session_id: int = clock.begin_session()
	var ticket: Dictionary = clock.create_request(1000000)
	expect_equal(int(ticket.get("session_id", -1)), session_id, "Ticket includes session.")
	expect_equal(int(ticket.get("request_id", -1)), 1, "First request starts at one.")
	expect_equal(clock.get_pending_request_count(), 1, "One request pending.")

	# Server's independent monotonic clock is 500000 usec ahead.
	# Network delay = 10000 usec in each direction, server work = 1000 usec.
	expect_true(
		clock.accept_response(session_id, 1, 1510000, 1511000, 1021000),
		"Four-timestamp observation is accepted.",
	)
	expect_float(clock.get_offset_seconds(), 0.5, "Offset estimate is 500 ms.")
	expect_float(clock.get_round_trip_seconds(), 0.02, "RTT excludes server work.")
	expect_equal(clock.get_server_ticks_usec(1031000), 1531000, "Remote time maps to server ticks.")
	expect_equal(clock.get_pending_request_count(), 0, "Successful response consumes ticket.")
	expect_equal(clock.get_sample_count(), 1, "First accepted sample recorded.")
	expect_false(clock.accept_response(session_id, 1, 1510000, 1511000, 1021000), "Replay rejected.")


func _test_smoothing_and_rtt_outliers() -> void:
	var clock := NucleusNetworkClockSync.new()
	var session_id: int = clock.begin_session()
	clock.create_request(1000000)
	clock.accept_response(session_id, 1, 1510000, 1511000, 1021000)

	clock.create_request(2000000)
	expect_true(
		clock.accept_response(session_id, 2, 2530000, 2531000, 2021000),
		"Normal sample accepted.",
	)
	expect_float(clock.get_offset_seconds(), 0.505, "Second offset is EWMA-smoothed.")
	expect_equal(clock.get_sample_count(), 2, "Two good samples.")

	clock.create_request(3000000)
	expect_false(
		clock.accept_response(session_id, 3, 3625000, 3626000, 3251000),
		"250 ms RTT outlier rejected against 20 ms floor.",
	)
	expect_equal(clock.get_sample_count(), 2, "Outlier must not update the estimate.")
	expect_float(clock.get_offset_seconds(), 0.505, "Outlier does not perturb offset.")


func _test_session_reset_and_replay() -> void:
	var clock := NucleusNetworkClockSync.new()
	var old_session: int = clock.begin_session()
	clock.create_request(1000000)
	var new_session: int = clock.begin_session()
	expect_false(clock.is_synchronized(1000000), "Reconnection invalidates offset.")
	var ticket: Dictionary = clock.create_request(1200000)
	expect_equal(int(ticket["request_id"]), 1, "New session has own ticket sequence.")
	expect_false(
		clock.accept_response(old_session, 1, 1500000, 1500000, 1210000),
		"Previous connection's reply cannot satisfy new ticket.",
	)
	expect_equal(clock.get_pending_request_count(), 1, "Old reply leaves new ticket intact.")
	expect_true(
		clock.accept_response(new_session, 1, 1710000, 1710000, 1220000),
		"New session completes independently.",
	)
	expect_float(clock.get_offset_seconds(), 0.5, "New session estimate is independent.")


func _test_pending_limits_and_timeouts() -> void:
	var profile := NucleusNetworkClockSyncProfile.new()
	profile.max_pending_requests = 1
	profile.request_timeout_seconds = 1.0
	var clock := NucleusNetworkClockSync.new(profile)
	var session_id: int = clock.begin_session()
	clock.create_request(1000000)
	expect_true(clock.create_request(1500000).is_empty(), "Pending budget enforced.")
	var next_ticket: Dictionary = clock.create_request(2200000)
	expect_equal(int(next_ticket["request_id"]), 2, "Expired ticket releases space.")
	expect_false(
		clock.accept_response(session_id, 1, 1510000, 1510000, 1220000),
		"Expired ticket was pruned.",
	)
	expect_false(
		clock.accept_response(session_id, 2, 2710000, 2710000, 3250000),
		"Late response is rejected by request deadline.",
	)


func _test_validation_and_bad_samples() -> void:
	var profile := NucleusNetworkClockSyncProfile.new()
	profile.smoothing_factor = 0.0
	expect_false(profile.get_validation_errors().is_empty(), "Invalid smoothing rejected.")
	var bad_clock := NucleusNetworkClockSync.new(profile)
	bad_clock.begin_session()
	expect_true(bad_clock.create_request(1000000).is_empty(), "Invalid profile rejects use.")

	var clock := NucleusNetworkClockSync.new()
	var session_id: int = clock.begin_session()
	clock.create_request(1000000)
	expect_false(
		clock.accept_response(session_id, 1, 1510000, 1509000, 1020000),
		"Negative server processing rejected.",
	)
	clock.create_request(2000000)
	expect_false(
		clock.accept_response(session_id, 2, 2500000, 2600000, 2020000),
		"Server processing larger than local elapsed rejected.",
	)
	clock.create_request(3000000)
	expect_false(
		clock.accept_response(session_id, 3, 3300000, 3300000, 7000000),
		"Overlong RTT rejected.",
	)
	expect_false(clock.is_synchronized(4000000), "Invalid samples never enable clock.")


func _test_stale_estimate_reacquisition() -> void:
	var profile := NucleusNetworkClockSyncProfile.new()
	profile.stale_after_seconds = 1.0
	var clock := NucleusNetworkClockSync.new(profile)
	var session_id: int = clock.begin_session()
	clock.create_request(1000000)
	clock.accept_response(session_id, 1, 1510000, 1511000, 1021000)
	expect_true(clock.is_synchronized(1500000), "Recent observation is valid.")
	expect_false(clock.is_synchronized(2100001), "Old estimate becomes unavailable.")
	expect_equal(clock.get_server_ticks_usec(2100001), -1, "Stale time is not exposed.")

	# Recovery must not smooth with an obsolete offset or obsolete RTT floor.
	clock.create_request(3000000)
	expect_true(
		clock.accept_response(session_id, 2, 3610000, 3611000, 3021000),
		"Fresh session sample accepted after expiration.",
	)
	expect_float(clock.get_offset_seconds(), 0.6, "Stale estimate replaced directly.")
