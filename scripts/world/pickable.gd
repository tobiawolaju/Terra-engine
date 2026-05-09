extends RigidBody3D
class_name Pickable

@export var hold_offset: Vector3 = Vector3(0.0, 1.2, -2.0)

func _ready() -> void:
	add_to_group("pickable")
