extends CharacterBody3D

const GRAVITY: float = 12.0
const JUMP_VELOCITY: float = 9.8 
const SPEED: float = 12.0

@export var camera: Camera3D
@export var camera_distance: float = 8.0
@export var camera_smoothness: float = 8.0
@export var camera_screen_offset: Vector2 = Vector2(0.0, -0.15)
@export var min_pitch: float = deg_to_rad(-10.0)
@export var max_pitch: float = deg_to_rad(60.0)
@export var min_zoom: float = 6.0
@export var max_zoom: float = 14.0
@export var altitude_zoom_factor: float = 1.25
@export var mouse_orbit_sensitivity: float = 0.005
@export var armature_turn_speed: float = 6.0
@export var animation_blend_time: float = 0.15
@export var anim_run: AnimationPlayer
@export var anim_idle: AnimationPlayer
@export var armature: Node3D

var cam_rot_x: float = deg_to_rad(15.0)
var cam_rot_y: float = 0.0
var current_animation: String = "idle"
func _ready() -> void:
	camera_distance = clampf(camera_distance, min_zoom, max_zoom)
	_ensure_animation_loops()
	_set_animation_state("idle")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		cam_rot_y -= event.relative.x * mouse_orbit_sensitivity
		cam_rot_x = clampf(cam_rot_x + event.relative.y * mouse_orbit_sensitivity, min_pitch, max_pitch)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_distance = clampf(camera_distance - 0.5, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_distance = clampf(camera_distance + 0.5, min_zoom, max_zoom)


func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Vector2.ZERO
	input_dir.y += Input.get_action_strength("forward")
	input_dir.y -= Input.get_action_strength("backward")
	input_dir.x -= Input.get_action_strength("left")
	input_dir.x += Input.get_action_strength("right")
	input_dir = input_dir.normalized()

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY

	var move_direction: Vector3 = Vector3.ZERO
	if camera != null:
		var cam_basis: Basis = camera.global_transform.basis
		var forward: Vector3 = -cam_basis.z
		var right: Vector3 = cam_basis.x

		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()

		move_direction = forward * input_dir.y + right * input_dir.x
	else:
		move_direction = Vector3(input_dir.x, 0.0, input_dir.y)

	if move_direction.length() > 0.0:
		move_direction = move_direction.normalized()

	velocity.x = move_direction.x * SPEED
	velocity.z = move_direction.z * SPEED
	move_and_slide()

	_update_armature_facing(move_direction, delta)
	_update_camera(delta)
	_handle_animations(move_direction)


func _update_camera(delta: float) -> void:
	if camera == null:
		return

	var target_pos: Vector3 = global_position + Vector3(0.0, 1.5, 0.0)
	cam_rot_x = clampf(cam_rot_x, min_pitch, max_pitch)

	var altitude_zoom: float = clampf(global_position.y * altitude_zoom_factor, 0.0, max_zoom - min_zoom)
	var effective_camera_distance: float = clampf(camera_distance + altitude_zoom, min_zoom, max_zoom)

	var cam_offset: Vector3 = Vector3(
		sin(cam_rot_y) * cos(cam_rot_x),
		sin(cam_rot_x),
		cos(cam_rot_y) * cos(cam_rot_x)
	) * effective_camera_distance

	var desired_pos: Vector3 = target_pos + cam_offset
	camera.global_position = camera.global_position.lerp(desired_pos, delta * camera_smoothness)
	camera.look_at(target_pos, Vector3.UP)

	var dist_to_target: float = camera.global_position.distance_to(target_pos)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = float(viewport_size.x) / max(1.0, float(viewport_size.y))
	var vertical_fov_rad: float = deg_to_rad(float(camera.fov))
	var half_height: float = dist_to_target * tan(vertical_fov_rad * 0.5)
	var half_width: float = half_height * aspect

	camera.h_offset = -camera_screen_offset.x * half_width
	camera.v_offset = -camera_screen_offset.y * half_height


func _handle_animations(move_dir: Vector3) -> void:
	if move_dir.length() > 0.1:
		_set_animation_state("running")
	else:
		_set_animation_state("idle")


func _update_armature_facing(move_dir: Vector3, delta: float) -> void:
	if armature == null or move_dir.length() <= 0.1:
		return

	var target_yaw: float = atan2(move_dir.x, move_dir.z)
	armature.rotation.y = lerp_angle(armature.rotation.y, target_yaw, delta * armature_turn_speed)


func _set_animation_state(next_state: String) -> void:
	if current_animation == next_state:
		return

	current_animation = next_state

	if next_state == "running":
		if anim_idle and anim_idle.is_playing():
			anim_idle.stop()
		if anim_run:
			anim_run.play("running", animation_blend_time)
	else:
		if anim_run and anim_run.is_playing():
			anim_run.stop()
		if anim_idle:
			anim_idle.play("idle", animation_blend_time)


func _ensure_animation_loops() -> void:
	if anim_run and anim_run.has_animation("running"):
		var running_animation: Animation = anim_run.get_animation("running")
		running_animation.loop_mode = Animation.LOOP_LINEAR

	if anim_idle and anim_idle.has_animation("idle"):
		var idle_animation: Animation = anim_idle.get_animation("idle")
		idle_animation.loop_mode = Animation.LOOP_LINEAR
