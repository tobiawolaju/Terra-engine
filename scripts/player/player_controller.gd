extends CharacterBody3D

const GRAVITY: float = 12.0
const JUMP_VELOCITY: float = 9.8 
const SPEED: float = 12.0
const LEAP_INTERVAL_SECONDS: float = 2.0
const LEAP_VELOCITY: float = 3.8
const LEAP_MOVE_THRESHOLD: float = 0.1
const DEATH_OVERLAY_SCENE_PATH: String = "res://scenes/overlays/death_overlay.tscn"

@export var camera: Camera3D
@export var hold_anchor: Node3D
@export var auto_compensate_anchor_scale: bool = true
@export var hold_offset_scale: float = 1.0
@export var pickup_range: float = 3.0
@export var hold_lerp_speed: float = 16.0
@export var camera_distance: float = 10.0
@export var camera_smoothness: float = 8.0
@export var camera_screen_offset: Vector2 = Vector2(0.0, -0.15)
@export var min_pitch: float = deg_to_rad(15.0)
@export var max_pitch: float = deg_to_rad(60.0)
@export var min_zoom: float = 8.0
@export var max_zoom: float = 14.0
@export var altitude_zoom_factor: float = 1.25
@export var mouse_orbit_sensitivity: float = 0.005
@export var dead_auto_orbit_speed: float = 0.6
@export var death_overlay_delay_seconds: float = 2.0
@export var armature_turn_speed: float = 6.0
@export var animation_blend_time: float = 0.15
@export var anim_run: AnimationPlayer
@export var anim_idle: AnimationPlayer
@export var anim_jump: AnimationPlayer
@export var anim_swim: AnimationPlayer
@export var anim_dead: AnimationPlayer
@export var armature: Node3D

var cam_rot_x: float = deg_to_rad(15.0)
var cam_rot_y: float = 0.0
var current_animation: String = "idle"
var _is_dead: bool = false
var _death_ui_swap_started: bool = false
var _death_score_submitted: bool = false
var _held_pickable: Pickable
var _pick_action_available: bool = false
var _leap_cooldown_seconds: float = 0.0

@onready var _username_3d: Label3D = $Armature/Skeleton3D/BoneAttachment3D/username
@onready var _hud: CanvasLayer = get_node_or_null("../../HUD")

func _ready() -> void:
	_pick_action_available = InputMap.has_action("pick")
	if not _pick_action_available:
		push_warning("Input action 'pick' is missing. Add it in Project Settings > Input Map.")
	if anim_dead == null:
		anim_dead = get_node_or_null("anime_dead") as AnimationPlayer
	camera_distance = clampf(camera_distance, min_zoom, max_zoom)
	_ensure_animation_loops()
	_set_animation_state("idle")
	_setup_session_flow()


func _input(event: InputEvent) -> void:
	if _is_dead:
		return

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _mouse_over_joystick(event.position):
			return
		cam_rot_y -= event.relative.x * mouse_orbit_sensitivity
		cam_rot_x = clampf(cam_rot_x + event.relative.y * mouse_orbit_sensitivity, min_pitch, max_pitch)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_distance = clampf(camera_distance - 0.5, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_distance = clampf(camera_distance + 0.5, min_zoom, max_zoom)


func _mouse_over_joystick(mouse_pos: Vector2) -> bool:
	var joystick := get_tree().get_first_node_in_group("touch_joystick")
	if joystick == null:
		return false
	if joystick.has_method("is_dragging_joystick") and bool(joystick.call("is_dragging_joystick")):
		return true
	if joystick.has_method("is_joystick_area_screen"):
		return bool(joystick.call("is_joystick_area_screen", mouse_pos, get_viewport().get_visible_rect().size))
	return false


func _physics_process(delta: float) -> void:
	_leap_cooldown_seconds = maxf(_leap_cooldown_seconds - delta, 0.0)

	if _is_dead:
		_process_dead_state(delta)
		return

	if _pick_action_available and Input.is_action_just_pressed("pick"):
		_toggle_pickup()

	_update_held_pickable(delta)

	var is_in_water: bool = global_position.y < 0.0
	var input_dir: Vector2 = Vector2.ZERO
	input_dir.y += Input.get_action_strength("forward")
	input_dir.y -= Input.get_action_strength("backward")
	input_dir.x -= Input.get_action_strength("left")
	input_dir.x += Input.get_action_strength("right")
	input_dir = input_dir.normalized()

	if not is_on_floor() and not is_in_water:
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump") and not is_in_water:
			velocity.y = JUMP_VELOCITY

	var speed_multiplier: float = 0.5 if is_in_water else 1.0
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

	velocity.x = move_direction.x * SPEED * speed_multiplier
	velocity.z = move_direction.z * SPEED * speed_multiplier
	_try_leap_assist(move_direction)
	move_and_slide()

	_update_armature_facing(move_direction, delta)
	_update_camera(delta)
	_handle_animations(move_direction, is_in_water)


func _process_dead_state(delta: float) -> void:
	_update_held_pickable(delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()

	camera_distance = max_zoom
	cam_rot_y += dead_auto_orbit_speed * delta
	_update_camera(delta)
	_set_animation_state("dead")


func set_dead_state(value: bool = true) -> void:
	if _is_dead == value:
		return

	_is_dead = value
	if _is_dead:
		_release_movement_inputs()
		_drop_held_pickable()
		camera_distance = max_zoom
		_set_animation_state("dead")
		_begin_death_ui_swap()
	else:
		_death_ui_swap_started = false
		_death_score_submitted = false
		_set_animation_state("idle")


func is_dead() -> bool:
	return _is_dead


func _release_movement_inputs() -> void:
	Input.action_release("forward")
	Input.action_release("backward")
	Input.action_release("left")
	Input.action_release("right")
	Input.action_release("jump")
	Input.action_release("pick")


func _begin_death_ui_swap() -> void:
	if _death_ui_swap_started:
		return
	_death_ui_swap_started = true
	_swap_hud_to_death_overlay_after_delay.call_deferred()


func _swap_hud_to_death_overlay_after_delay() -> void:
	await get_tree().create_timer(maxf(death_overlay_delay_seconds, 0.0)).timeout

	if not _is_dead:
		_death_ui_swap_started = false
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var elapsed_seconds: int = 0
	var hud_node: Node = current_scene.get_node_or_null("HUD")
	if hud_node == null and _hud != null:
		hud_node = _hud
	if hud_node != null and hud_node.has_method("get_elapsed_seconds"):
		elapsed_seconds = int(hud_node.call("get_elapsed_seconds"))

	var hud_parent: Node = current_scene
	var hud_index: int = -1
	if hud_node != null:
		hud_parent = hud_node.get_parent()
		hud_index = hud_node.get_index()
		if _hud == hud_node:
			_hud = null
		hud_node.queue_free()

	var death_overlay_scene: PackedScene = load(DEATH_OVERLAY_SCENE_PATH) as PackedScene
	if death_overlay_scene == null:
		push_warning("Failed to load death overlay scene at: %s" % DEATH_OVERLAY_SCENE_PATH)
		return

	var death_overlay_instance: Node = death_overlay_scene.instantiate()
	if death_overlay_instance == null:
		return
	_set_death_overlay_time_spent_label(death_overlay_instance, elapsed_seconds)

	hud_parent.add_child(death_overlay_instance)
	if hud_index >= 0:
		hud_parent.move_child(death_overlay_instance, min(hud_index, hud_parent.get_child_count() - 1))

	await _submit_death_score(elapsed_seconds)


func _submit_death_score(elapsed_seconds: int) -> void:
	if _death_score_submitted:
		return
	_death_score_submitted = true

	WavedashFlow.ensure_initialized()
	var response: Dictionary = await WavedashFlow.post_survival_time(max(elapsed_seconds, 0))
	if not bool(response.get("success", false)):
		push_warning("Failed to post survival score to Wavedash: %s" % str(response.get("message", "unknown error")))


func _set_death_overlay_time_spent_label(death_overlay_instance: Node, elapsed_seconds: int) -> void:
	if death_overlay_instance == null:
		return
	var time_label: Label = death_overlay_instance.get_node_or_null("CanvasLayer/time-spent") as Label
	if time_label == null:
		return
	time_label.text = "Time spent : %d sec" % max(elapsed_seconds, 0)


func _try_leap_assist(move_direction: Vector3) -> void:
	if move_direction.length() < LEAP_MOVE_THRESHOLD:
		return
	if not is_on_floor():
		return
	if _leap_cooldown_seconds > 0.0:
		return
	if velocity.y > LEAP_VELOCITY:
		return

	velocity.y = maxf(velocity.y, LEAP_VELOCITY)
	_leap_cooldown_seconds = LEAP_INTERVAL_SECONDS


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


func _handle_animations(move_dir: Vector3, is_in_water: bool) -> void:
	if _is_dead:
		_set_animation_state("dead")
		return

	if is_in_water:
		_set_animation_state("swim")
		return

	if not is_on_floor():
		_set_animation_state("jump")
		return

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

	if next_state == "jump":
		if anim_idle and anim_idle.is_playing():
			anim_idle.stop()
		if anim_run and anim_run.is_playing():
			anim_run.stop()
		if anim_swim and anim_swim.is_playing():
			anim_swim.stop()
		if anim_jump:
			anim_jump.play("jump", animation_blend_time)
		return

	if next_state == "dead":
		if anim_idle and anim_idle.is_playing():
			anim_idle.stop()
		if anim_run and anim_run.is_playing():
			anim_run.stop()
		if anim_jump and anim_jump.is_playing():
			anim_jump.stop()
		if anim_swim and anim_swim.is_playing():
			anim_swim.stop()
		if anim_dead:
			if anim_dead.has_animation("dead"):
				anim_dead.play("dead", animation_blend_time)
			elif anim_dead.has_animation("anim_dead"):
				anim_dead.play("anim_dead", animation_blend_time)
		return

	if next_state == "swim":
		if anim_idle and anim_idle.is_playing():
			anim_idle.stop()
		if anim_run and anim_run.is_playing():
			anim_run.stop()
		if anim_jump and anim_jump.is_playing():
			anim_jump.stop()
		if anim_swim:
			anim_swim.play("swim", animation_blend_time)
		return

	if next_state == "running":
		if anim_jump and anim_jump.is_playing():
			anim_jump.stop()
		if anim_swim and anim_swim.is_playing():
			anim_swim.stop()
		if anim_idle and anim_idle.is_playing():
			anim_idle.stop()
		if anim_run:
			anim_run.play("running", animation_blend_time)
	else:
		if anim_jump and anim_jump.is_playing():
			anim_jump.stop()
		if anim_swim and anim_swim.is_playing():
			anim_swim.stop()
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

	if anim_jump and anim_jump.has_animation("jump"):
		var jump_animation: Animation = anim_jump.get_animation("jump")
		jump_animation.loop_mode = Animation.LOOP_LINEAR

	if anim_swim and anim_swim.has_animation("swim"):
		var swim_animation: Animation = anim_swim.get_animation("swim")
		swim_animation.loop_mode = Animation.LOOP_LINEAR

	if anim_dead and anim_dead.has_animation("dead"):
		var dead_animation: Animation = anim_dead.get_animation("dead")
		dead_animation.loop_mode = Animation.LOOP_NONE


func _setup_session_flow() -> void:
	WavedashFlow.ensure_initialized()
	var username: String = WavedashFlow.get_username()
	if _username_3d != null:
		_username_3d.text = username
	if _hud != null and _hud.has_method("set_username"):
		_hud.call("set_username", username)
	if _hud != null and _hud.has_method("set_elapsed_time"):
		_hud.call("set_elapsed_time", 0)


func _toggle_pickup() -> void:
	if _held_pickable != null:
		_drop_held_pickable()
		return

	var nearest_pickable: Pickable = _find_nearest_pickable()
	if nearest_pickable != null:
		_pick_pickable(nearest_pickable)


func _pick_pickable(target_pickable: Pickable) -> void:
	_held_pickable = target_pickable
	_held_pickable.freeze = true
	_held_pickable.sleeping = false
	_held_pickable.linear_velocity = Vector3.ZERO
	_held_pickable.angular_velocity = Vector3.ZERO
	_held_pickable.add_collision_exception_with(self)


func _drop_held_pickable() -> void:
	if _held_pickable == null:
		return

	_held_pickable.remove_collision_exception_with(self)
	_held_pickable.freeze = false
	_held_pickable.sleeping = false
	_held_pickable = null


func _update_held_pickable(delta: float) -> void:
	if _held_pickable == null:
		return

	if not is_instance_valid(_held_pickable):
		_held_pickable = null
		return

	var target_pos: Vector3 = _get_hold_target_position(_held_pickable)
	_held_pickable.linear_velocity = Vector3.ZERO
	_held_pickable.angular_velocity = Vector3.ZERO
	_held_pickable.global_position = _held_pickable.global_position.lerp(
		target_pos,
		clampf(delta * hold_lerp_speed, 0.0, 1.0)
	)


func _get_hold_target_position(target_pickable: Pickable) -> Vector3:
	var anchor: Node3D = hold_anchor if hold_anchor != null else self
	var compensation: float = _get_anchor_compensation_scale(anchor) if auto_compensate_anchor_scale else 1.0
	var base_anchor_position: Vector3 = global_position + (anchor.global_position - global_position) * compensation
	var offset: Vector3 = target_pickable.hold_offset * hold_offset_scale * compensation
	var basis: Basis = anchor.global_transform.basis
	var up: Vector3 = basis.y.normalized()
	var right: Vector3 = basis.x.normalized()
	var forward: Vector3 = -basis.z.normalized()
	return base_anchor_position + (up * offset.y) + (right * offset.x) + (forward * -offset.z)


func _get_anchor_compensation_scale(anchor: Node3D) -> float:
	var anchor_scale: Vector3 = anchor.global_transform.basis.get_scale().abs()
	var self_scale: Vector3 = global_transform.basis.get_scale().abs()

	var rel_x: float = anchor_scale.x / maxf(self_scale.x, 0.001)
	var rel_y: float = anchor_scale.y / maxf(self_scale.y, 0.001)
	var rel_z: float = anchor_scale.z / maxf(self_scale.z, 0.001)
	var relative_uniform_scale: float = (rel_x + rel_y + rel_z) / 3.0

	if relative_uniform_scale <= 0.001:
		return 1.0

	return 1.0 / relative_uniform_scale


func _find_nearest_pickable() -> Pickable:
	var nearest: Pickable
	var nearest_distance_sq: float = pickup_range * pickup_range

	for node: Node in get_tree().get_nodes_in_group("pickable"):
		var candidate := node as Pickable
		if candidate == null or not is_instance_valid(candidate):
			continue
		if candidate == _held_pickable:
			continue

		var distance_sq: float = candidate.global_position.distance_squared_to(global_position)
		if distance_sq <= nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest = candidate

	return nearest
