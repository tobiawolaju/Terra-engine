extends WorldEnvironment
class_name RotatingSky

@export_range(-180.0, 180.0, 0.1) var start_degrees: float = -1.0
@export_range(-180.0, 180.0, 0.1) var end_degrees: float = 36.0
@export_range(0.0, 360.0, 0.1) var rotation_speed_degrees_per_second: float = 2.0
@export var rotate_x: float = 0.0
@export var rotate_z: float = 0.0

var _current_degrees: float = -1.0
var _rotation_span: float = 37.0
var _rotate_x_radians: float = 0.0
var _rotate_z_radians: float = 0.0


func _ready() -> void:
	_current_degrees = start_degrees
	_rotation_span = end_degrees - start_degrees
	_rotate_x_radians = deg_to_rad(rotate_x)
	_rotate_z_radians = deg_to_rad(rotate_z)
	_apply_rotation()


func _process(delta: float) -> void:
	if environment == null:
		return
	if is_equal_approx(_rotation_span, 0.0):
		return

	_current_degrees = wrapf(
		_current_degrees + (rotation_speed_degrees_per_second * delta),
		minf(start_degrees, end_degrees),
		maxf(start_degrees, end_degrees)
	)
	_apply_rotation()


func _apply_rotation() -> void:
	if environment == null:
		return

	environment.sky_rotation = Vector3(
		_rotate_x_radians,
		deg_to_rad(_current_degrees),
		_rotate_z_radians
	)
