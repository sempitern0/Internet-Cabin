extends Node
## Game-owned example for starting a Nucleus ENet dedicated server.
##
## This is intentionally an example rather than a framework service. A real game
## still owns authentication, map/session creation, persistence and player spawn.

@export var network_path: NodePath = NodePath("Network")
@export_range(1024, 65535, 1) var default_port: int = 42069
@export_range(1, 4096, 1) var default_max_clients: int = 16
@export var default_bind_address: String = "*"

@onready var network: NucleusNetworkHandler = get_node(network_path)


func _ready() -> void:
	var options := _parse_user_options()
	var server_mode := (
		OS.has_feature("dedicated_server")
		or bool(options.get("server", false))
	)

	if not server_mode:
		return

	var validation_error := _validate_options(options)
	if not validation_error.is_empty():
		push_error(validation_error)
		get_tree().quit(2)
		return

	var error := network.start_enet_server(
		int(options["port"]),
		int(options["max_clients"]),
		str(options["bind"]),
	)

	if error != OK:
		push_error("Dedicated server failed: %s" % error_string(error))
		get_tree().quit(3)
		return

	print(
		"Dedicated ENet server listening on %s:%d for up to %d clients."
		% [
			str(options["bind"]),
			int(options["port"]),
			int(options["max_clients"]),
		]
	)

	_start_authoritative_session()


func _parse_user_options() -> Dictionary:
	var result := {
		"server": false,
		"port": default_port,
		"max_clients": default_max_clients,
		"bind": default_bind_address,
	}

	for argument: String in OS.get_cmdline_user_args():
		if argument == "--server":
			result["server"] = true
		elif argument.begins_with("--port="):
			result["port"] = argument.get_slice("=", 1).to_int()
		elif argument.begins_with("--max-clients="):
			result["max_clients"] = argument.get_slice("=", 1).to_int()
		elif argument.begins_with("--bind="):
			result["bind"] = argument.get_slice("=", 1).strip_edges()

	return result


func _validate_options(options: Dictionary) -> String:
	var port := int(options.get("port", 0))
	if not NucleusNetworkUtils.is_valid_port(port):
		return "Invalid dedicated-server port: %d" % port

	var max_clients := int(options.get("max_clients", 0))
	if max_clients <= 0:
		return "Dedicated-server max_clients must be greater than zero."

	var bind_address := str(options.get("bind", "")).strip_edges()
	if bind_address.is_empty():
		return "Dedicated-server bind address cannot be empty."

	return ""


func _start_authoritative_session() -> void:
	# Replace this with game-owned world/session startup.
	# Do not create a local player merely because the server has peer ID 1.
	pass
