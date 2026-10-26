# Optional Network Recovery V1

## Ownership

`NucleusNetworkReconnectController` is an opt-in, **scene-owned** client
connection supervisor for one existing `NucleusNetworkHandler`. It supports
ENet and WebSocket clients without introducing an Autoload or a new transport.
Servers continue using `NucleusNetworkHandler` directly.

`NucleusNetworkReconnectPolicy` describes a finite reconnect budget and
exponential delay. Connection loss can lead to repeated transport attempts,
but **a connected socket is never proof of authenticated gameplay state**.
A consuming game remains responsible for identity validation, account/session
admission, replaying subscriptions, rejoining a character, refreshing the
world, and deciding what UI appears during recovery.

This module does **not** implement authentication, token storage, keepalive,
heartbeat detection, host migration, matchmaking, account bans, or a server
resume protocol. Nothing in this component authorizes a client to mutate
server state.

## Scene setup

```text
PersistentGameSession
├── Network : NucleusNetworkHandler
├── Recovery : NucleusNetworkReconnectController
└── World / UI
```

Assign `Recovery.handler` to `Network` in the Inspector. Leave `policy` empty
to use the in-memory defaults, or assign a saved
`NucleusNetworkReconnectPolicy` resource. Both nodes should have the same
lifetime; keep the containing session alive across scene replacement only if
the connection is intended to survive it. Do not connect the same handler
through another client bootstrap at the same time.

To start a connection:

```gdscript
@onready var recovery: NucleusNetworkReconnectController = $Recovery


func _ready() -> void:
    recovery.require_session_restore = true
    recovery.session_restore_requested.connect(_restore_after_connect)
    recovery.session_ready.connect(_on_session_ready)
    recovery.recovery_failed.connect(_on_recovery_failed)
    var error: Error = recovery.connect_enet("127.0.0.1", 42069)
    if error != OK:
        push_error(error_string(error))


func _restore_after_connect(request_token: int) -> void:
    # Start a game-owned server-authenticated resume / fresh join request.
    # Validate the account/character, then wait for authoritative world sync.
    # Do NOT acknowledge success here before those operations finish.
    pass


func on_game_resume_confirmed(request_token: int, same_identity: bool) -> void:
    # A delayed response may be rejected after a retry, Leave or scene exit.
    recovery.complete_session_restore(request_token, same_identity)


func _on_session_ready(was_reconnect: bool) -> void:
    print("Game session ready; reconnected = ", was_reconnect)


func _on_recovery_failed(reason: Error) -> void:
    push_warning(error_string(reason))
```

Call `recovery.stop()` for intentional Leave/Logout; this invalidates pending
acknowledgement tokens and closes **only the client connection started by this
controller**. The next explicit `connect_enet()` or `connect_websocket()` call
starts a fresh session. The controller does not store any credentials.

With `require_session_restore = false` (default), the controller becomes READY
as soon as the transport emits `connected_to_server`. This is appropriate
**only** where the game has no additional authentication/world reconstruction
phase. For multiplayer game state, set it to `true`.

## Recovery phases and signals

```text
IDLE -> CONNECTING -> RESTORING (optional) -> READY
              |              |
        error/timeout       timeout
              v              v
            WAITING -> CONNECTING ... -> READY
                    (or FAILED on exhausted budget)
```

Once READY, `server_disconnected` starts a new recovery cycle (unless
`auto_reconnect` is false). Direct `NucleusNetworkHandler.shutdown()` is **not**
an automatic reconnect trigger; intentionally stop the controller first.

- `recovery_started(is_reconnect)` fires on a new initial/recovery cycle.
- `attempt_started(attempt_number, request_token)` reports each transport start.
- `retry_scheduled(next_attempt, delay_seconds, reason)` describes retry pacing.
- `session_restore_requested(request_token)` asks the game to restore identity
  and its world state. Never use an old token to acknowledge a new attempt.
- `session_ready(was_reconnect)` marks completed transport + optional restore.
- `recovery_failed(reason)` reports terminal failure.
- `stopped` fires for intentional stop and tree exit.

`phase`, `last_error`, `is_session_ready()`, `get_attempt_count()` and
`get_request_token()` expose observable state. They should be queried, not set by the game.
Calling `connect_*` while an attempt or session is active returns an error.

## Default timing and failure limits

| Policy | Default |
| --- | --- |
| Total attempts per connection/recovery cycle | 6 |
| First reconnect/retry delay | 0.25 s |
| Exponential multiplier | 2 |
| Maximum delay | 5 s |
| Timeout per transport attempt | 5 s |
| Timeout while waiting for game restore | 6 s |
| Total wall-clock budget per cycle | 30 s |

The initial explicit connect starts immediately; reconnect after an unexpected
loss waits the initial delay. Scheduling and deadlines use Godot's monotonic
`Time.get_ticks_msec()`, not game time scale. Processing continues when the
scene tree is paused. Attempt limits and overall budget are both enforced.
Retries close the old peer before starting another one.

Bad policy values or invalid targets are rejected; unsupported ENet-on-Web is
rejected up front. `connect_*() == OK` means **accepted request**, not an
established session. The initial failure can schedule a retry immediately.

A negative session-restore acknowledgement is terminal (`ERR_UNAUTHORIZED`)
so an identity mismatch never silently resumes as another character. Lost
connections and timeouts may retry until the budget expires. Permanent
session/auth policy and login UI remain game-owned.

## Validation and boundaries

`tests/headless/network_recovery_test.gd` uses a fake transport and simulated
monotonic time to exercise retries, limits, dropped connections, stale restore
tokens and intentional shutdown. Register it through the headless manifest.

For real-world acceptance also test a loopback host/client, a force-killed
server, a temporarily unreachable endpoint, rejoin/resubscription under packet
loss, and a stale identity response after a second connection. The tests above
are **not** proof of network quality, reconnect availability or release/export
compatibility without live transport measurements.

See [Networking](networking.md) and
[Online Replication](online_replication.md) for transport and trust boundaries.
