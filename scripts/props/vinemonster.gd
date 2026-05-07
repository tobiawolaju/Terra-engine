extends Node3D
class_name VineEnemy

signal grabbed(player: Node3D)
signal released(player: Node3D)

@export var detection_area_path: NodePath = NodePath("Area3D")
@export var skeleton_path: NodePath = NodePath("Skeleton3D")
@export var target_player: CharacterBody3D
@export var player_feet_node_path: NodePath = NodePath("feet")
@export var fallback_target_offset: Vector3 = Vector3(0.0, 0.75, 0.0)
@export var target_min_height_above_root: float = 0.25
@export var curve_side_offset: float = 0.65
@export var curve_height: float = 0.9
@export var curve_idle_side_offset: float = 0.35
@export var curve_idle_height: float = 0.45
@export var release_velocity_threshold: float = 0.1
@export var grab_speed_multiplier: float = 0.3
@export var segment_length: float = 0.35
@export var segment_count: int = 5
@export var idle_wave_speed: float = 1.2
@export var bend_power: float = 2.2

var _area: Area3D
var _skeleton: Skeleton3D
var _player: Node3D
var _player_body: CharacterBody3D
var _is_grabbing: bool = false
var _bone_indices: Array[int] = []
var _idle_time: float = 0.0
var _bend_pole: Vector3 = Vector3.RIGHT


func _ready() -> void:
	_area = get_node_or_null(detection_area_path) as Area3D
	_skeleton = get_node_or_null(skeleton_path) as Skeleton3D

	if _area != null:
		if not _area.body_entered.is_connected(_on_body_entered):
			_area.body_entered.connect(_on_body_entered)
		if not _area.body_exited.is_connected(_on_body_exited):
			_area.body_exited.connect(_on_body_exited)

	_cache_bones()
	_apply_idle_pose()


func _physics_process(_delta: float) -> void:
	_idle_time += _delta

	if _is_grabbing:
		if _player == null or not is_instance_valid(_player):
			_release_player()
		elif _player_body != null and _player_body.velocity.y > release_velocity_threshold:
			_release_player()

	if _skeleton == null:
		return

	if _is_grabbing:
		_apply_chain_pose(_get_player_target_world_position(), curve_height, curve_side_offset)
	else:
		_apply_idle_pose()


func _on_body_entered(body: Node) -> void:
	if _is_grabbing:
		return
	if body == null:
		return
	if target_player != null and body != target_player:
		return

	_player = body as Node3D
	_player_body = body as CharacterBody3D
	if _player == null:
		return
	if target_player == null:
		target_player = _player_body

	_is_grabbing = true
	_set_player_vined(true)
	grabbed.emit(_player)


func _on_body_exited(body: Node) -> void:
	if body != _player:
		return
	_release_player()


func _release_player() -> void:
	if not _is_grabbing:
		return

	_set_player_vined(false)
	released.emit(_player)
	_player = null
	_player_body = null
	_is_grabbing = false
	_apply_idle_pose()


func _set_player_vined(value: bool) -> void:
	if _player == null:
		return
	_player.set("is_vined", value)


func _cache_bones() -> void:
	_bone_indices.clear()
	if _skeleton == null:
		return

	for i: int in range(segment_count):
		var bone_idx: int = _skeleton.find_bone("Bone%d" % (i + 1))
		if bone_idx >= 0:
			_bone_indices.append(bone_idx)


func _apply_idle_pose() -> void:
	var root_world_pos: Vector3 = _skeleton.global_position
	var idle_target_world: Vector3 = root_world_pos + Vector3(
		0.45 + sin(_idle_time * idle_wave_speed) * 0.12,
		curve_idle_height,
		0.25 + cos(_idle_time * idle_wave_speed * 0.7) * 0.08
	)
	_apply_chain_pose(idle_target_world, curve_idle_height, curve_idle_side_offset)


func _apply_chain_pose(target_world_pos: Vector3, lift_height: float, side_offset: float) -> void:
	if _skeleton == null or _bone_indices.is_empty():
		return

	_skeleton.clear_bones_global_pose_override()

	var root_world_pos: Vector3 = _skeleton.global_position
	target_world_pos.y = maxf(target_world_pos.y, root_world_pos.y + target_min_height_above_root)

	var root_local: Vector3 = _skeleton.to_local(root_world_pos)
	var target_local: Vector3 = _skeleton.to_local(target_world_pos)
	var chain_points: PackedVector3Array = _build_chain_points(root_local, target_local, lift_height, side_offset)

	if chain_points.size() < 2:
		return

	for i: int in range(min(_bone_indices.size(), chain_points.size() - 1)):
		var start_point: Vector3 = chain_points[i]
		var end_point: Vector3 = chain_points[i + 1]
		var segment_dir: Vector3 = end_point - start_point
		if segment_dir.length() <= 0.0001:
			continue
		var basis: Basis = _basis_from_direction(segment_dir.normalized())
		_skeleton.set_bone_global_pose_override(_bone_indices[i], Transform3D(basis, start_point), 1.0, true)

	_skeleton.force_update_all_bone_transforms()


func _get_player_target_world_position() -> Vector3:
	if _player == null:
		return Vector3.ZERO

	var feet_node: Node3D = null
	if _player.has_node(player_feet_node_path):
		feet_node = _player.get_node_or_null(player_feet_node_path) as Node3D
	elif _player.has_node(NodePath("Feet")):
		feet_node = _player.get_node_or_null(NodePath("Feet")) as Node3D

	if feet_node != null:
		return feet_node.global_position

	return _player.global_position + fallback_target_offset


func _build_chain_points(root_local: Vector3, target_local: Vector3, lift_height: float, side_offset: float) -> PackedVector3Array:
	var max_reach: float = segment_length * float(max(1, segment_count))
	var offset_to_target: Vector3 = target_local - root_local
	var distance_to_target: float = offset_to_target.length()
	var direction: Vector3 = Vector3.FORWARD
	if distance_to_target > 0.0001:
		direction = offset_to_target / distance_to_target

	var reachable_distance: float = minf(distance_to_target, max_reach)
	var curve_target: Vector3 = root_local + direction * reachable_distance
	var side_dir: Vector3 = direction.cross(Vector3.UP)
	if side_dir.length() <= 0.0001:
		side_dir = Vector3.RIGHT
	else:
		side_dir = side_dir.normalized()
	_bend_pole = side_dir

	var chain_points: PackedVector3Array = PackedVector3Array()
	for i: int in range(segment_count + 1):
		var t: float = 0.0 if segment_count <= 0 else float(i) / float(segment_count)
		var eased_t: float = pow(t, bend_power)
		var arch_strength: float = sin(PI * t) * lift_height * eased_t
		var side_strength: float = sin(PI * t) * side_offset * eased_t
		var point: Vector3 = root_local.lerp(curve_target, t)
		point += Vector3.UP * arch_strength
		point += side_dir * side_strength
		chain_points.append(point)

	return chain_points


func _basis_from_direction(direction: Vector3) -> Basis:
	var y_axis: Vector3 = direction.normalized()
	var x_axis: Vector3 = _bend_pole.cross(y_axis)
	if x_axis.length() <= 0.0001:
		var up_hint: Vector3 = Vector3.UP
		x_axis = up_hint.cross(y_axis)
	if x_axis.length() <= 0.0001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var z_axis: Vector3 = y_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()
