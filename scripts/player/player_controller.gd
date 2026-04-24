extends CharacterBody3D

const GRAVITY: float = 12.0
const JUMP_VELOCITY: float = 9.8 
const SPEED: float = 12.0
const LEADERBOARD_SCENE := "res://scenes/leaderboard.tscn"
const COOP_P2P_CHANNEL := 1
const COOP_SYNC_INTERVAL := 0.1

@export var camera: Camera3D
@export var camera_distance: float = 10.0
@export var camera_smoothness: float = 8.0
@export var camera_screen_offset: Vector2 = Vector2(0.0, -0.15)
@export var min_pitch: float = deg_to_rad(10.0)
@export var max_pitch: float = deg_to_rad(60.0)
@export var min_zoom: float = 8.0
@export var max_zoom: float = 14.0
@export var altitude_zoom_factor: float = 1.25
@export var mouse_orbit_sensitivity: float = 0.005
@export var armature_turn_speed: float = 6.0
@export var animation_blend_time: float = 0.15
@export var anim_run: AnimationPlayer
@export var anim_idle: AnimationPlayer
@export var anim_jump: AnimationPlayer
@export var anim_swim: AnimationPlayer
@export var armature: Node3D

var cam_rot_x: float = deg_to_rad(15.0)
var cam_rot_y: float = 0.0
var current_animation: String = "idle"
var _sim_target_seconds: int = 0
var _sim_elapsed_seconds: int = 0
var _sim_completed: bool = false
var _coop_active: bool = false
var _coop_lobby_id: String = ""
var _self_user_id: String = ""
var _sync_accumulator: float = 0.0
var _remote_players: Dictionary = {}
var _remote_target_positions: Dictionary = {}
var _remote_root: Node3D

@onready var _username_3d: Label3D = $Armature/Skeleton3D/BoneAttachment3D/username
@onready var _hud: CanvasLayer = get_node_or_null("../../HUD")

func _ready() -> void:
	camera_distance = clampf(camera_distance, min_zoom, max_zoom)
	_ensure_animation_loops()
	_set_animation_state("idle")
	_setup_session_flow()


func _exit_tree() -> void:
	if WavedashSDK.lobby_users_updated.is_connected(_on_lobby_users_updated):
		WavedashSDK.lobby_users_updated.disconnect(_on_lobby_users_updated)
	if WavedashSDK.lobby_left.is_connected(_on_lobby_left):
		WavedashSDK.lobby_left.disconnect(_on_lobby_left)
	if WavedashSDK.lobby_kicked.is_connected(_on_lobby_kicked):
		WavedashSDK.lobby_kicked.disconnect(_on_lobby_kicked)


func _input(event: InputEvent) -> void:
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
	move_and_slide()

	_update_armature_facing(move_direction, delta)
	_update_camera(delta)
	_handle_animations(move_direction, is_in_water)
	_update_coop(delta)


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


func _setup_session_flow() -> void:
	randomize()
	WavedashFlow.ensure_initialized()
	var username: String = WavedashFlow.get_username()
	_self_user_id = WavedashSDK.get_user_id()
	if _username_3d != null:
		_username_3d.text = username
	if _hud != null and _hud.has_method("set_username"):
		_hud.call("set_username", username)
	if WavedashFlow.multiplayer_enabled:
		_start_coop_mode()
	_start_simulation()


func _start_simulation() -> void:
	_sim_target_seconds = randi_range(10, 60)
	_sim_elapsed_seconds = 0
	_sim_completed = false
	if _hud != null and _hud.has_method("set_elapsed_time"):
		_hud.call("set_elapsed_time", _sim_elapsed_seconds, _sim_target_seconds)
	_run_simulation()


func _run_simulation() -> void:
	while _sim_elapsed_seconds < _sim_target_seconds and is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		_sim_elapsed_seconds += 1
		if _hud != null and _hud.has_method("set_elapsed_time"):
			_hud.call("set_elapsed_time", _sim_elapsed_seconds, _sim_target_seconds)

	if _sim_completed or not is_inside_tree():
		return
	_sim_completed = true

	var response: Dictionary = await WavedashFlow.post_survival_time(_sim_elapsed_seconds)
	if _hud != null and _hud.has_method("set_score_text"):
		if bool(response.get("success", false)):
			var rank_text := "N/A"
			if WavedashFlow.last_rank > 0:
				rank_text = str(WavedashFlow.last_rank)
			_hud.call("set_score_text", "Final: %ss  Rank: %s" % [_sim_elapsed_seconds, rank_text])
		else:
			_hud.call("set_score_text", "Final: %ss  (score post failed)" % _sim_elapsed_seconds)

	await get_tree().create_timer(1.2).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file(LEADERBOARD_SCENE)


func _start_coop_mode() -> void:
	_coop_active = await WavedashFlow.ensure_auto_room_joined(32)
	if not _coop_active:
		if _hud != null and _hud.has_method("set_score_text"):
			_hud.call("set_score_text", "Co-op room unavailable, running solo.")
		return

	_coop_lobby_id = WavedashFlow.get_current_lobby_id()
	_remote_root = Node3D.new()
	_remote_root.name = "RemotePlayers"
	get_node("../../").add_child(_remote_root)
	_sync_remote_users()
	if not WavedashSDK.lobby_users_updated.is_connected(_on_lobby_users_updated):
		WavedashSDK.lobby_users_updated.connect(_on_lobby_users_updated)
	if not WavedashSDK.lobby_left.is_connected(_on_lobby_left):
		WavedashSDK.lobby_left.connect(_on_lobby_left)
	if not WavedashSDK.lobby_kicked.is_connected(_on_lobby_kicked):
		WavedashSDK.lobby_kicked.connect(_on_lobby_kicked)


func _update_coop(delta: float) -> void:
	if not _coop_active:
		return
	_sync_accumulator += delta
	if _sync_accumulator >= COOP_SYNC_INTERVAL:
		_sync_accumulator = 0.0
		_broadcast_local_state()
	_consume_remote_state()
	_interpolate_remote_players(delta)


func _broadcast_local_state() -> void:
	var payload := {
		"x": global_position.x,
		"y": global_position.y,
		"z": global_position.z,
		"u": WavedashFlow.get_username()
	}
	WavedashSDK.send_p2p_message("", JSON.stringify(payload).to_utf8_buffer(), COOP_P2P_CHANNEL, false)


func _consume_remote_state() -> void:
	var packets: Array[Dictionary] = WavedashSDK.drain_p2p_channel(COOP_P2P_CHANNEL)
	for packet in packets:
		var from_id: String = str(packet.get("identity", ""))
		if from_id == "" or from_id == _self_user_id:
			continue
		var payload: Variant = packet.get("payload", PackedByteArray())
		if not (payload is PackedByteArray):
			continue
		var payload_text: String = (payload as PackedByteArray).get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(payload_text)
		if not (parsed is Dictionary):
			continue
		_apply_remote_state(from_id, parsed as Dictionary)


func _apply_remote_state(user_id: String, state: Dictionary) -> void:
	if not _remote_players.has(user_id):
		var username := str(state.get("u", WavedashSDK.get_username(user_id)))
		_spawn_remote_player(user_id, username)
	var target := Vector3(
		float(state.get("x", 0.0)),
		float(state.get("y", 0.0)),
		float(state.get("z", 0.0))
	)
	_remote_target_positions[user_id] = target


func _interpolate_remote_players(delta: float) -> void:
	for user_id in _remote_players.keys():
		var node := _remote_players[user_id] as Node3D
		if node == null:
			continue
		var target: Vector3 = _remote_target_positions.get(user_id, node.global_position)
		node.global_position = node.global_position.lerp(target, clampf(delta * 8.0, 0.0, 1.0))


func _sync_remote_users() -> void:
	if _coop_lobby_id == "":
		return
	var users: Array = WavedashSDK.get_lobby_users(_coop_lobby_id)
	var active_ids: Dictionary = {}
	for user in users:
		if user is Dictionary:
			var u := user as Dictionary
			var user_id: String = str(u.get("id", u.get("userId", "")))
			if user_id == "" or user_id == _self_user_id:
				continue
			active_ids[user_id] = true
			if not _remote_players.has(user_id):
				_spawn_remote_player(user_id, str(u.get("username", u.get("userName", WavedashSDK.get_username(user_id)))))

	var to_remove: Array = []
	for existing_id in _remote_players.keys():
		if not active_ids.has(existing_id):
			to_remove.append(existing_id)
	for remove_id in to_remove:
		_remove_remote_player(str(remove_id))


func _spawn_remote_player(user_id: String, username: String) -> void:
	if _remote_root == null:
		return
	var avatar := Node3D.new()
	avatar.name = "remote_" + user_id
	_remote_root.add_child(avatar)

	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	mesh.mesh = sphere
	avatar.add_child(mesh)

	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 1.0, 0.0)
	label.text = username if username != "" else "remote"
	label.font_size = 44
	label.outline_size = 20
	avatar.add_child(label)

	_remote_players[user_id] = avatar
	_remote_target_positions[user_id] = avatar.global_position


func _remove_remote_player(user_id: String) -> void:
	if not _remote_players.has(user_id):
		return
	var node := _remote_players[user_id] as Node3D
	_remote_players.erase(user_id)
	_remote_target_positions.erase(user_id)
	if node != null:
		node.queue_free()


func _on_lobby_users_updated(_payload: Dictionary) -> void:
	_sync_remote_users()


func _on_lobby_left(_payload: Dictionary) -> void:
	_coop_active = false


func _on_lobby_kicked(_payload: Dictionary) -> void:
	_coop_active = false
