extends Node3D

@export var target: Node3D
@export var rotation_speed: float = 6.0


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0

	if to_target.length_squared() <= 0.000001:
		return

	var desired_yaw: float = atan2(to_target.x, to_target.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, maxf(rotation_speed, 0.0) * delta)
