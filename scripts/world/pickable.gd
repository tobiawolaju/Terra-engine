extends RigidBody3D
class_name Pickable

@export var hold_offset: Vector3 = Vector3(0.0, 1.2, -2.0)

var _default_collision_layer: int = 1
var _default_collision_mask: int = 1
var _default_can_sleep: bool = true
var _default_linear_damp: float = 0.0
var _default_angular_damp: float = 0.0

func _ready() -> void:
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask
	_default_can_sleep = can_sleep
	_default_linear_damp = linear_damp
	_default_angular_damp = angular_damp
	if not is_in_group("pickable"):
		add_to_group("pickable")


func prepare_for_spawn(spawn_transform: Transform3D, spawn_scale: Vector3, oxygen_reward: float) -> void:
	global_transform = spawn_transform
	scale = spawn_scale
	set_meta("berry_scale", spawn_scale.x)
	set_meta("oxygen_reward", oxygen_reward)
	collision_layer = _default_collision_layer
	collision_mask = _default_collision_mask
	freeze = false
	sleeping = false
	can_sleep = _default_can_sleep
	linear_damp = _default_linear_damp
	angular_damp = _default_angular_damp
	if not is_in_group("pickable"):
		add_to_group("pickable")
	_set_visuals_visible(true)


func deactivate_for_pool() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	sleeping = true
	collision_layer = 0
	collision_mask = 0
	if is_in_group("pickable"):
		remove_from_group("pickable")
	_set_visuals_visible(false)
	remove_meta("berry_scale")
	remove_meta("oxygen_reward")


func _set_visuals_visible(visible: bool) -> void:
	_set_visuals_visible_recursive(self, visible)


func _set_visuals_visible_recursive(node: Node, visible: bool) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visible = visible
	for child: Node in node.get_children():
		_set_visuals_visible_recursive(child, visible)
