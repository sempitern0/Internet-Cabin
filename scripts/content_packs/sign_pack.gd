extends SceneTree
## Release-side signer for official Content Packs.
##
## Example:
## godot --headless --path . --script res://scripts/content_packs/sign_pack.gd \
##   -- --pack /secure/dlc.pck --manifest /secure/dlc.json \
##   --key /secure/content.key --signature /secure/dlc.sig

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options: Dictionary = _parse_options(OS.get_cmdline_user_args())

	var required_options := PackedStringArray([
		"pack",
		"manifest",
		"key",
		"signature",
	])

	for option: String in required_options:
		if str(options.get(option, "")).is_empty():
			push_error("Missing required option --%s." % option)
			quit(2)
			return

	var pack_path: String = str(options.pack)
	var manifest_path: String = str(options.manifest)
	var key_path: String = str(options.key)
	var signature_path: String = str(options.signature)

	if key_path.begins_with("res://"):
		push_error("Private signing keys must stay outside res://.")
		quit(2)
		return

	if not FileAccess.file_exists(pack_path):
		push_error("Pack does not exist: %s" % pack_path)
		quit(2)
		return

	var manifest_data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(manifest_path)
	)
	if typeof(manifest_data) != TYPE_DICTIONARY:
		push_error("Manifest must be a JSON object.")
		quit(2)
		return

	var archive_sha256: String = FileAccess.get_sha256(pack_path)
	if archive_sha256.is_empty():
		push_error("Could not hash pack: %s" % pack_path)
		quit(2)
		return

	manifest_data["archive_sha256"] = archive_sha256.to_lower()
	var manifest := NucleusContentPackManifest.from_dictionary(manifest_data)
	var errors: PackedStringArray = manifest.validate(true)

	if not errors.is_empty():
		for error_message: String in errors:
			push_error(error_message)
		quit(2)
		return

	var serialized: String = (
		JSON.stringify(manifest.to_dictionary(), "\t", true) + "\n"
	)
	var manifest_file := FileAccess.open(
		manifest_path,
		FileAccess.WRITE,
	)
	if manifest_file == null:
		push_error("Could not write manifest: %s" % manifest_path)
		quit(2)
		return

	manifest_file.store_string(serialized)
	manifest_file.close()

	var private_key := CryptoKey.new()
	var key_error: Error = private_key.load(key_path, false)
	if key_error != OK:
		push_error("Could not load private key: %s" % error_string(key_error))
		quit(2)
		return

	if private_key.is_public_only():
		push_error("Signing requires a private key.")
		quit(2)
		return

	var manifest_bytes: PackedByteArray = serialized.to_utf8_buffer()
	var context := HashingContext.new()
	var hash_error: Error = context.start(HashingContext.HASH_SHA256)
	if hash_error != OK:
		push_error("Could not start SHA-256 context.")
		quit(2)
		return

	context.update(manifest_bytes)
	var manifest_hash: PackedByteArray = context.finish()
	var signature: PackedByteArray = Crypto.new().sign(
		HashingContext.HASH_SHA256,
		manifest_hash,
		private_key,
	)

	if signature.is_empty():
		push_error("Signing failed.")
		quit(2)
		return

	var signature_file := FileAccess.open(
		signature_path,
		FileAccess.WRITE,
	)
	if signature_file == null:
		push_error("Could not write signature: %s" % signature_path)
		quit(2)
		return

	signature_file.store_buffer(signature)
	signature_file.close()

	print("Content pack signed.")
	print("  pack:      %s" % pack_path)
	print("  manifest:  %s" % manifest_path)
	print("  signature: %s" % signature_path)
	print("  sha256:    %s" % archive_sha256)
	quit(0)


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var index: int = 0

	while index < arguments.size():
		var argument: String = arguments[index]

		if not argument.begins_with("--"):
			index += 1
			continue

		var key: String = argument.trim_prefix("--")
		if index + 1 >= arguments.size():
			result[key] = ""
			break

		result[key] = arguments[index + 1]
		index += 2

	return result
