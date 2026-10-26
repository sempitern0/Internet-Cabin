extends RefCounted

var _checks: int = 0
var _failures := PackedStringArray()


func expect_true(value: bool, message: String) -> void:
	_checks += 1

	if not value:
		_failures.append(message)


func expect_false(value: bool, message: String) -> void:
	expect_true(not value, message)


func expect_equal(
	actual: Variant,
	expected: Variant,
	message: String,
) -> void:
	_checks += 1

	if actual != expected:
		_failures.append(
			"%s (expected=%s actual=%s)"
			% [message, str(expected), str(actual)]
		)


func expect_float(
	actual: float,
	expected: float,
	message: String,
) -> void:
	_checks += 1

	if not is_equal_approx(actual, expected):
		_failures.append(
			"%s (expected=%s actual=%s)"
			% [message, str(expected), str(actual)]
		)


## Attaches a parentless test subtree to the active SceneTree root.
## Use this before testing APIs that require global transforms or lifecycle.
func attach_test_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false

	if node.is_inside_tree():
		return true

	if node.get_parent() != null:
		return false

	var main_loop := Engine.get_main_loop()

	if not main_loop is SceneTree:
		return false

	var tree := main_loop as SceneTree
	tree.root.add_child(node)
	return node.is_inside_tree()


func free_test_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	node.free()


func finish() -> Dictionary:
	return {
		"checks": _checks,
		"failures": _failures,
	}
