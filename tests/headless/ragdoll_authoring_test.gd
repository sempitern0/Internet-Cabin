extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_profile_contract()
	_test_bone_map_has_priority()
	_test_builder_creates_editable_native_ragdoll()
	_test_builder_refuses_existing_simulator()
	_test_runtime_collision_exception_api()
	return finish()


func _test_profile_contract() -> void:
	var profile: NucleusHumanoidRagdollProfile3D = (
		NucleusHumanoidRagdollProfile3D.new()
	)

	expect_float(
		profile.total_mass,
		70.0,
		"Humanoid ragdoll starter mass defaults to 70 kg.",
	)
	expect_equal(
		profile.get_joint_type(
			NucleusHumanoidRagdollProfile3D.LEFT_LOWER_ARM
		),
		PhysicalBone3D.JOINT_TYPE_HINGE,
		"Lower arms use a native hinge starter constraint.",
	)
	expect_equal(
		profile.get_joint_type(
			NucleusHumanoidRagdollProfile3D.LEFT_UPPER_ARM
		),
		PhysicalBone3D.JOINT_TYPE_6DOF,
		"Upper arms use a native 6DOF starter constraint.",
	)
	expect_false(
		profile.share_mirrored_shapes,
		"Mirrored shape resources are independent by default.",
	)


func _test_bone_map_has_priority() -> void:
	var skeleton: Skeleton3D = Skeleton3D.new()
	_add_bone(
		skeleton,
		"custom_pelvis",
		-1,
		Vector3.ZERO,
	)
	_add_bone(
		skeleton,
		"custom_spine",
		0,
		Vector3(0.0, 0.25, 0.0),
	)

	var bone_map: BoneMap = BoneMap.new()
	bone_map.profile = SkeletonProfileHumanoid.new()
	bone_map.set_skeleton_bone_name(
		NucleusHumanoidRagdollProfile3D.HIPS,
		&"custom_pelvis",
	)
	bone_map.set_skeleton_bone_name(
		NucleusHumanoidRagdollProfile3D.SPINE,
		&"custom_spine",
	)

	var sources: Dictionary = {}
	var mapping: Dictionary = (
		NucleusRagdollRigInspector3D.resolve_humanoid_mapping(
			skeleton,
			bone_map,
			{},
			NucleusHumanoidRagdollProfile3D.new(),
			sources,
		)
	)

	expect_equal(
		StringName(str(mapping.get(
			NucleusHumanoidRagdollProfile3D.HIPS,
			&"",
		))),
		&"custom_pelvis",
		"BoneMap resolves custom skeleton naming.",
	)
	expect_equal(
		StringName(str(sources.get(
			NucleusHumanoidRagdollProfile3D.HIPS,
			&"",
		))),
		&"bone_map",
		"BoneMap is reported as the preferred mapping source.",
	)

	skeleton.free()


func _test_builder_creates_editable_native_ragdoll() -> void:
	var skeleton: Skeleton3D = _build_humanoid_skeleton()
	var profile: NucleusHumanoidRagdollProfile3D = (
		NucleusHumanoidRagdollProfile3D.new()
	)

	expect_equal(
		NucleusRagdollBuilder3D.build_humanoid(
			skeleton,
			profile,
		),
		OK,
		"Humanoid builder creates a starter physical skeleton.",
	)

	var simulator: PhysicalBoneSimulator3D = (
		NucleusRagdollRigInspector3D.find_simulator(skeleton)
	)

	expect_true(
		simulator != null,
		"Builder creates a native PhysicalBoneSimulator3D.",
	)

	if simulator == null:
		skeleton.free()
		return

	var report: Dictionary = NucleusRagdollRigInspector3D.inspect(
		skeleton,
		null,
		{},
		profile,
	)

	expect_true(
		int(report.get("physical_bone_count", 0)) >= 15,
		"Starter humanoid includes the useful major body segments.",
	)
	expect_equal(
		int(report.get("physical_bones_without_shapes", 0)),
		0,
		"Every generated physical bone has a collision shape.",
	)
	expect_float(
		float(report.get("total_physical_mass", 0.0)),
		profile.total_mass,
		"Generated body-segment masses normalize to total profile mass.",
	)

	var lower_arm: PhysicalBone3D = _find_physical_bone(
		simulator,
		"LeftLowerArm",
	)
	expect_true(
		lower_arm != null,
		"Generated ragdoll contains the mapped lower arm.",
	)

	if lower_arm != null:
		expect_equal(
			lower_arm.joint_type,
			PhysicalBone3D.JOINT_TYPE_HINGE,
			"Generated lower arm keeps the hinge starter joint.",
		)

	skeleton.free()


func _test_builder_refuses_existing_simulator() -> void:
	var skeleton: Skeleton3D = _build_humanoid_skeleton()
	var profile: NucleusHumanoidRagdollProfile3D = (
		NucleusHumanoidRagdollProfile3D.new()
	)

	expect_equal(
		NucleusRagdollBuilder3D.build_humanoid(
			skeleton,
			profile,
		),
		OK,
		"First ragdoll build succeeds.",
	)
	expect_equal(
		NucleusRagdollBuilder3D.build_humanoid(
			skeleton,
			profile,
		),
		ERR_ALREADY_EXISTS,
		"Builder refuses to destroy or overwrite an existing simulator.",
	)

	skeleton.free()


func _test_runtime_collision_exception_api() -> void:
	var root: Node3D = Node3D.new()
	var skeleton: Skeleton3D = Skeleton3D.new()
	var simulator: PhysicalBoneSimulator3D = (
		PhysicalBoneSimulator3D.new()
	)
	var physical_bone: PhysicalBone3D = PhysicalBone3D.new()
	var character_body: CharacterBody3D = CharacterBody3D.new()
	var controller: NucleusRagdollController3D = (
		NucleusRagdollController3D.new()
	)

	skeleton.add_bone("Hips")
	physical_bone.set("bone_name", "Hips")
	simulator.add_child(physical_bone)
	skeleton.add_child(simulator)
	root.add_child(skeleton)
	root.add_child(character_body)
	root.add_child(controller)
	controller.simulator = simulator

	expect_true(
		attach_test_node(root),
		"Collision-exception fixture requires a live SceneTree.",
	)
	expect_equal(
		controller.add_collision_exception(character_body),
		OK,
		"Ragdoll controller forwards native physical-bone collision exceptions.",
	)
	expect_true(
		controller.collision_exceptions.has(character_body),
		"Collision exception is retained as explicit scene configuration.",
	)
	expect_equal(
		controller.remove_collision_exception(character_body),
		OK,
		"Ragdoll collision exceptions can be removed explicitly.",
	)
	expect_false(
		controller.collision_exceptions.has(character_body),
		"Removed exception leaves the controller configuration.",
	)

	free_test_node(root)


func _build_humanoid_skeleton() -> Skeleton3D:
	var skeleton: Skeleton3D = Skeleton3D.new()

	var hips: int = _add_bone(
		skeleton,
		"Hips",
		-1,
		Vector3.ZERO,
	)
	var spine: int = _add_bone(
		skeleton,
		"Spine",
		hips,
		Vector3(0.0, 0.22, 0.0),
	)
	var chest: int = _add_bone(
		skeleton,
		"Chest",
		spine,
		Vector3(0.0, 0.22, 0.0),
	)
	var upper_chest: int = _add_bone(
		skeleton,
		"UpperChest",
		chest,
		Vector3(0.0, 0.20, 0.0),
	)
	_add_bone(
		skeleton,
		"Head",
		upper_chest,
		Vector3(0.0, 0.28, 0.0),
	)

	var left_upper_arm: int = _add_bone(
		skeleton,
		"LeftUpperArm",
		upper_chest,
		Vector3(-0.24, 0.05, 0.0),
	)
	var left_lower_arm: int = _add_bone(
		skeleton,
		"LeftLowerArm",
		left_upper_arm,
		Vector3(-0.30, 0.0, 0.0),
	)
	_add_bone(
		skeleton,
		"LeftHand",
		left_lower_arm,
		Vector3(-0.25, 0.0, 0.0),
	)

	var right_upper_arm: int = _add_bone(
		skeleton,
		"RightUpperArm",
		upper_chest,
		Vector3(0.24, 0.05, 0.0),
	)
	var right_lower_arm: int = _add_bone(
		skeleton,
		"RightLowerArm",
		right_upper_arm,
		Vector3(0.30, 0.0, 0.0),
	)
	_add_bone(
		skeleton,
		"RightHand",
		right_lower_arm,
		Vector3(0.25, 0.0, 0.0),
	)

	var left_upper_leg: int = _add_bone(
		skeleton,
		"LeftUpperLeg",
		hips,
		Vector3(-0.12, -0.12, 0.0),
	)
	var left_lower_leg: int = _add_bone(
		skeleton,
		"LeftLowerLeg",
		left_upper_leg,
		Vector3(0.0, -0.45, 0.0),
	)
	_add_bone(
		skeleton,
		"LeftFoot",
		left_lower_leg,
		Vector3(0.0, -0.42, 0.08),
	)

	var right_upper_leg: int = _add_bone(
		skeleton,
		"RightUpperLeg",
		hips,
		Vector3(0.12, -0.12, 0.0),
	)
	var right_lower_leg: int = _add_bone(
		skeleton,
		"RightLowerLeg",
		right_upper_leg,
		Vector3(0.0, -0.45, 0.0),
	)
	_add_bone(
		skeleton,
		"RightFoot",
		right_lower_leg,
		Vector3(0.0, -0.42, 0.08),
	)

	return skeleton


func _add_bone(
	skeleton: Skeleton3D,
	bone_name: String,
	parent_index: int,
	local_position: Vector3,
) -> int:
	var bone_index: int = skeleton.add_bone(bone_name)

	if parent_index >= 0:
		skeleton.set_bone_parent(bone_index, parent_index)

	skeleton.set_bone_rest(
		bone_index,
		Transform3D(Basis.IDENTITY, local_position),
	)
	return bone_index


func _find_physical_bone(
	simulator: PhysicalBoneSimulator3D,
	bone_name: String,
) -> PhysicalBone3D:
	for child: Node in simulator.get_children():
		if not child is PhysicalBone3D:
			continue

		var physical_bone: PhysicalBone3D = child as PhysicalBone3D

		var mapped_name: String = str(
			physical_bone.get("bone_name")
		)

		if mapped_name == bone_name:
			return physical_bone

	return null
