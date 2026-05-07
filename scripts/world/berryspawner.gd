extends Node

@export var berry_scene: PackedScene
@export var spawn_interval_seconds: float = 10.0
@export var max_berries: int = 10
@export var min_berry_scale: float = 1.0
@export var max_berry_scale: float = 3.0
@export var combo_window_seconds: float = 4.0
@export var progress_2d: ProgressBar
@export var hud_tint_path: NodePath = NodePath("HUD/tint")
@export var player_controller_path: NodePath = NodePath("player/CharacterBody3D")
@export var deadalien_path: NodePath = NodePath("deadalien")
@export var directional_light_path: NodePath = NodePath("WorldEnvironment2/DirectionalLight3D")
@export var world_environment_path: NodePath = NodePath("WorldEnvironment2")
@export var ground_mesh_path: NodePath = NodePath("ground/hill/hillmesh")
@export var water_mesh_path: NodePath = NodePath("berrylake/water")
@export var lake_surface_y: float = 0.0
@export var destroy_after_seconds: float = 5.0
@export var deadalien_oxygen_reward: float = 45.0
@export var lake_label_path: NodePath = NodePath("berrylake/water/Label3D")
@export_group("Oxygen Visuals")
@export var light_good: Color = Color("f6e7b5")
@export var light_bad: Color = Color("9c3d3a")
@export var ground_good: Color = Color("477725")
@export var ground_bad: Color = Color("4a3b34")
@export var water_good: Color = Color("00879973")
@export var water_bad: Color = Color("7a4a2ec0")
@export var oxygen_bar_good: Color = Color("ffffff")
@export var oxygen_bar_bad: Color = Color("d16666")
@export var hud_tint_good: Color = Color(0, 0, 0, 0)
@export var hud_tint_bad: Color = Color("#b2007475")
@export var bloom_good: float = 0.2
@export var bloom_bad: float = 0.4
@export var oxygen_visual_transition_seconds: float = 4.0
@export_group("Player Oxygen FX")
@export var player_vfx_mesh_path: NodePath
@export_range(0.0, 100.0, 0.1) var oxygen_loss_fx_start_threshold: float = 25.0
@export_range(0.0, 100.0, 0.1) var oxygen_loss_fx_stop_threshold: float = 5.0
@export var spawn_point_1: Node3D
@export var spawn_point_2: Node3D
@export var spawn_point_3: Node3D
@export var spawn_point_4: Node3D
@export var spawn_point_5: Node3D

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_timer: Timer
var _oxygen_timer: Timer
var _spawned_berries: Array[WeakRef] = []
var _underwater_since: Dictionary = {}
var _lake_label: Label3D
var _directional_light: DirectionalLight3D
var _world_environment: WorldEnvironment
var _ground_mesh: MeshInstance3D
var _water_mesh: MeshInstance3D
var _player_controller: Node
var _deadalien: Node3D
var _hud_tint: ColorRect
var _progress_fill_style: StyleBoxFlat
var _player_vfx_mesh: MeshInstance3D
var _hud: CanvasLayer
var _deadalien_consumed: bool = false
var _death_triggered: bool = false
var _delivery_combo_count: int = 0
var _last_delivery_time: float = -1.0
var oxygen_level: float = 50.0
var _displayed_oxygen_level: float = 50.0
var _displayed_oxygen_from: float = 50.0
var _displayed_oxygen_to: float = 50.0
var _displayed_oxygen_elapsed: float = 0.0


func _ready() -> void:
	Resolution.apply_quality_preset("performance")
	_rng.randomize()
	_lake_label = get_node_or_null(lake_label_path) as Label3D
	_directional_light = get_node_or_null(directional_light_path) as DirectionalLight3D
	_world_environment = get_node_or_null(world_environment_path) as WorldEnvironment
	_ground_mesh = get_node_or_null(ground_mesh_path) as MeshInstance3D
	_water_mesh = get_node_or_null(water_mesh_path) as MeshInstance3D
	_hud = _get_hud()
	_hud_tint = get_node_or_null(hud_tint_path) as ColorRect
	_player_controller = get_node_or_null(player_controller_path)
	_deadalien = get_node_or_null(deadalien_path) as Node3D
	_player_vfx_mesh = get_node_or_null(player_vfx_mesh_path) as MeshInstance3D
	if progress_2d == null:
		progress_2d = get_node_or_null("HUD/ProgressBar") as ProgressBar
	_ensure_progress_fill_style()
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.autostart = false
	_spawn_timer.wait_time = maxf(spawn_interval_seconds, 0.1)
	_spawn_timer.timeout.connect(_spawn_berry)
	add_child(_spawn_timer)
	_spawn_timer.start()

	_oxygen_timer = Timer.new()
	_oxygen_timer.one_shot = false
	_oxygen_timer.autostart = false
	_oxygen_timer.wait_time = 5.0
	_oxygen_timer.timeout.connect(_on_oxygen_tick)
	add_child(_oxygen_timer)
	_oxygen_timer.start()

	_displayed_oxygen_level = oxygen_level
	_displayed_oxygen_from = oxygen_level
	_displayed_oxygen_to = oxygen_level
	_displayed_oxygen_elapsed = oxygen_visual_transition_seconds
	_apply_oxygen_to_progress()
	_apply_oxygen_visuals(_oxygen_badness_for(_displayed_oxygen_level))
	_apply_player_oxygen_fx(_displayed_oxygen_level)
	_update_lake_label(0)


func _process(delta: float) -> void:
	_cleanup_spawned_berries()
	if not _death_triggered:
		_handle_lake_logic()
	_update_oxygen_visuals(delta)


func _spawn_berry() -> void:
	_cleanup_spawned_berries()
	if _spawned_berries.size() >= max(max_berries, 0):
		return

	if berry_scene == null:
		push_warning("BerrySpawner: Assign a berry_scene in the inspector.")
		return

	var spawn_points: Array[Node3D] = _get_valid_spawn_points()
	if spawn_points.is_empty():
		push_warning("BerrySpawner: Assign at least one spawn point.")
		return

	var spawn_point: Node3D = spawn_points[_rng.randi_range(0, spawn_points.size() - 1)]
	var berry: Node = berry_scene.instantiate()
	var berry_3d := berry as Node3D
	if berry_3d == null:
		push_warning("BerrySpawner: berry_scene root must be a Node3D.")
		berry.queue_free()
		return

	get_tree().current_scene.add_child(berry_3d)
	berry_3d.global_transform = spawn_point.global_transform
	var scale_min: float = minf(min_berry_scale, max_berry_scale)
	var scale_max: float = maxf(min_berry_scale, max_berry_scale)
	var random_scale: float = _rng.randf_range(scale_min, scale_max)
	berry_3d.scale = Vector3.ONE * random_scale
	var oxygen_reward: float = _get_berry_oxygen_reward(random_scale)
	berry_3d.set_meta("berry_scale", random_scale)
	berry_3d.set_meta("oxygen_reward", oxygen_reward)
	_apply_berry_visuals(berry_3d, random_scale, oxygen_reward)
	_spawned_berries.append(weakref(berry_3d))


func _get_valid_spawn_points() -> Array[Node3D]:
	var points: Array[Node3D] = []
	if spawn_point_1 != null:
		points.append(spawn_point_1)
	if spawn_point_2 != null:
		points.append(spawn_point_2)
	if spawn_point_3 != null:
		points.append(spawn_point_3)
	if spawn_point_4 != null:
		points.append(spawn_point_4)
	if spawn_point_5 != null:
		points.append(spawn_point_5)
	return points


func _cleanup_spawned_berries() -> void:
	var alive: Array[WeakRef] = []
	for berry_ref: WeakRef in _spawned_berries:
		if berry_ref.get_ref() != null:
			alive.append(berry_ref)
	_spawned_berries = alive


func _handle_lake_logic() -> void:
	if _death_triggered:
		return

	var now_seconds: float = Time.get_ticks_msec() / 1000.0
	var underwater_count: int = 0
	var alive_ids: Dictionary = {}

	for berry_ref: WeakRef in _spawned_berries:
		var berry := berry_ref.get_ref() as Node3D
		if berry == null:
			continue

		var berry_id: int = berry.get_instance_id()
		alive_ids[berry_id] = true

		if berry.global_position.y < lake_surface_y:
			underwater_count += 1
			if not _underwater_since.has(berry_id):
				_underwater_since[berry_id] = now_seconds

			var underwater_duration: float = now_seconds - float(_underwater_since[berry_id])
			if underwater_duration >= maxf(destroy_after_seconds, 0.0):
				var oxygen_reward: float = _get_berry_reward_from_node(berry)
				_register_delivery_feedback(oxygen_reward, now_seconds)
				_add_oxygen(oxygen_reward)
				berry.queue_free()
				_underwater_since.erase(berry_id)
				underwater_count = max(underwater_count - 1, 0)
		else:
			_underwater_since.erase(berry_id)

	underwater_count += _handle_deadalien_lake_logic(now_seconds, alive_ids)

	for berry_id: Variant in _underwater_since.keys():
		if not alive_ids.has(berry_id):
			_underwater_since.erase(berry_id)

	_update_lake_label(underwater_count)


func _handle_deadalien_lake_logic(now_seconds: float, alive_ids: Dictionary) -> int:
	if _deadalien_consumed:
		return 0
	if _deadalien == null or not is_instance_valid(_deadalien):
		_deadalien = get_node_or_null(deadalien_path) as Node3D
	if _deadalien == null or not is_instance_valid(_deadalien):
		return 0

	var deadalien_id: int = _deadalien.get_instance_id()
	alive_ids[deadalien_id] = true

	if _deadalien.global_position.y < lake_surface_y:
		if not _underwater_since.has(deadalien_id):
			_underwater_since[deadalien_id] = now_seconds

		var underwater_duration: float = now_seconds - float(_underwater_since[deadalien_id])
		if underwater_duration >= maxf(destroy_after_seconds, 0.0):
			_add_oxygen(deadalien_oxygen_reward)
			_deadalien.queue_free()
			_underwater_since.erase(deadalien_id)
			_deadalien_consumed = true
			return 0
		return 1
	else:
		_underwater_since.erase(deadalien_id)
		return 0


func _update_lake_label(underwater_count: int) -> void:
	if _lake_label == null:
		return
	if underwater_count == 1:
		_lake_label.text = "1 berry"
	else:
		_lake_label.text = "%d berries" % underwater_count


func _on_oxygen_tick() -> void:
	if _death_triggered or _is_oxygen_refilling():
		return
	_add_oxygen(-2.0)


func _add_oxygen(delta_amount: float) -> void:
	if _death_triggered:
		return

	oxygen_level = clampf(oxygen_level + delta_amount, 0.0, 100.0)
	_apply_oxygen_to_progress()

	if oxygen_level <= 0.0 and not _death_triggered:
		_death_triggered = true
		if _oxygen_timer != null:
			_oxygen_timer.stop()
		_trigger_player_death()


func _register_delivery_feedback(oxygen_reward: float, now_seconds: float) -> void:
	if oxygen_reward > 0.0:
		if _last_delivery_time >= 0.0 and (now_seconds - _last_delivery_time) <= maxf(combo_window_seconds, 0.0):
			_delivery_combo_count += 1
		else:
			_delivery_combo_count = 1
		_last_delivery_time = now_seconds
	else:
		_delivery_combo_count = 0
		_last_delivery_time = -1.0

	_show_delivery_feedback(oxygen_reward, _delivery_combo_count)


func _show_delivery_feedback(oxygen_reward: float, combo_count: int) -> void:
	var hud: CanvasLayer = _get_hud()
	if hud == null:
		return

	var reward_text: String = "%s%d oxygen" % [_signed_prefix(oxygen_reward), int(round(absf(oxygen_reward)))]
	if oxygen_reward > 0.0 and combo_count > 1:
		reward_text = "Combo x%d  %s" % [combo_count, reward_text]

	if hud.has_method("show_combo_feedback"):
		hud.call("show_combo_feedback", reward_text, oxygen_reward >= 0.0)
	if oxygen_reward > 0.0 and hud.has_method("play_combo_fx"):
		hud.call("play_combo_fx", combo_count, oxygen_reward)


func _signed_prefix(value: float) -> String:
	return "+" if value >= 0.0 else "-"


func _get_hud() -> CanvasLayer:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null
	var hud := current_scene.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		_hud = hud
	return _hud


func _get_berry_reward_from_node(berry: Node) -> float:
	if berry != null and berry.has_meta("oxygen_reward"):
		return float(berry.get_meta("oxygen_reward"))
	if berry != null and berry.has_meta("berry_scale"):
		return _get_berry_oxygen_reward(float(berry.get_meta("berry_scale")))
	return 10.0


func _get_berry_oxygen_reward(scale: float) -> float:
	var scale_min: float = minf(min_berry_scale, max_berry_scale)
	var scale_max: float = maxf(min_berry_scale, max_berry_scale)
	var normalized: float = clampf(inverse_lerp(scale_min, scale_max, scale), 0.0, 1.0)

	if normalized <= 0.33:
		if _rng.randf() < 0.55:
			return -float(_rng.randi_range(4, 10))
		return float(_rng.randi_range(8, 18))

	if normalized <= 0.7:
		return float(_rng.randi_range(2, 8))

	return float(_rng.randi_range(8, 16))


func _get_berry_color(scale: float, oxygen_reward: float) -> Color:
	var scale_min: float = minf(min_berry_scale, max_berry_scale)
	var scale_max: float = maxf(min_berry_scale, max_berry_scale)
	var normalized: float = clampf(inverse_lerp(scale_min, scale_max, scale), 0.0, 1.0)

	var small_risky: Color = Color("#d84c4c")
	var ripe: Color = Color("#ff7b55")
	var lush: Color = Color("#9e62ff")
	var rotten: Color = Color("#8e2d2d")

	if oxygen_reward < 0.0:
		return rotten.lerp(small_risky, normalized * 0.6)
	return small_risky.lerp(ripe, normalized * 0.55).lerp(lush, normalized)


func _apply_berry_visuals(berry_root: Node3D, scale: float, oxygen_reward: float) -> void:
	if berry_root == null:
		return

	var berry_color: Color = _get_berry_color(scale, oxygen_reward)
	_tint_mesh_instances(berry_root, berry_color)


func _tint_mesh_instances(node: Node, berry_color: Color) -> void:
	if node == null:
		return

	if node is MeshInstance3D:
		_tint_mesh_instance(node as MeshInstance3D, berry_color)

	for child: Node in node.get_children():
		_tint_mesh_instances(child, berry_color)


func _tint_mesh_instance(mesh_node: MeshInstance3D, berry_color: Color) -> void:
	if mesh_node == null:
		return

	var material: StandardMaterial3D = null
	var active_material := mesh_node.get_active_material(0)
	if active_material is StandardMaterial3D:
		material = (active_material as StandardMaterial3D).duplicate() as StandardMaterial3D
	elif mesh_node.material_override is StandardMaterial3D:
		material = (mesh_node.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		material = StandardMaterial3D.new()

	material.albedo_color = berry_color

	var surface_count: int = 0
	if mesh_node.mesh != null:
		surface_count = mesh_node.mesh.get_surface_count()

	if surface_count > 0:
		for surface_index: int in range(surface_count):
			mesh_node.set_surface_override_material(surface_index, material)
	else:
		mesh_node.material_override = material


func _trigger_player_death() -> void:
	if _player_controller == null:
		_player_controller = get_node_or_null(player_controller_path)
	if _player_controller == null:
		return
	if _player_controller.has_method("set_dead_state"):
		_player_controller.call("set_dead_state", true)


func _apply_oxygen_to_progress() -> void:
	_displayed_oxygen_from = _displayed_oxygen_level
	_displayed_oxygen_to = oxygen_level
	_displayed_oxygen_elapsed = 0.0

	if oxygen_visual_transition_seconds <= 0.0:
		_displayed_oxygen_level = oxygen_level
		_displayed_oxygen_from = oxygen_level
		_displayed_oxygen_to = oxygen_level
		_displayed_oxygen_elapsed = 0.0

	if progress_2d != null:
		progress_2d.min_value = 0.0
		progress_2d.max_value = 100.0
		progress_2d.value = _displayed_oxygen_level


func _update_oxygen_visuals(delta: float) -> void:
	if is_equal_approx(_displayed_oxygen_level, _displayed_oxygen_to):
		return

	var duration: float = maxf(oxygen_visual_transition_seconds, 0.001)
	_displayed_oxygen_elapsed = minf(_displayed_oxygen_elapsed + delta, duration)
	var weight: float = _displayed_oxygen_elapsed / duration
	_displayed_oxygen_level = lerpf(_displayed_oxygen_from, _displayed_oxygen_to, weight)

	if is_equal_approx(_displayed_oxygen_level, _displayed_oxygen_to):
		_displayed_oxygen_level = _displayed_oxygen_to

	if progress_2d != null:
		progress_2d.value = _displayed_oxygen_level

	_apply_oxygen_visuals(_oxygen_badness_for(_displayed_oxygen_level))
	_apply_player_oxygen_fx(_displayed_oxygen_level)


func _is_oxygen_refilling() -> bool:
	return _displayed_oxygen_level < _displayed_oxygen_to and not is_equal_approx(_displayed_oxygen_level, _displayed_oxygen_to)


func _apply_oxygen_visuals(badness: float) -> void:
	var light_color: Color = light_good.lerp(light_bad, badness)
	var ground_color: Color = ground_good.lerp(ground_bad, badness)
	var water_color: Color = water_good.lerp(water_bad, badness)

	_apply_directional_light_color(light_color)
	_apply_environment_bloom(badness)
	_apply_mesh_albedo(_ground_mesh, ground_color)
	_apply_mesh_albedo(_water_mesh, water_color)
	_apply_progress_fill_color(badness)
	_apply_hud_tint(badness)


func _apply_directional_light_color(light_color: Color) -> void:
	if _directional_light == null:
		_directional_light = get_node_or_null(directional_light_path) as DirectionalLight3D
	if _directional_light == null:
		return
	_directional_light.light_color = light_color


func _apply_environment_bloom(badness: float) -> void:
	if _world_environment == null:
		_world_environment = get_node_or_null(world_environment_path) as WorldEnvironment
	if _world_environment == null or _world_environment.environment == null:
		return
	_world_environment.environment.glow_bloom = lerpf(bloom_good, bloom_bad, badness)


func _apply_mesh_albedo(mesh_node: MeshInstance3D, color_value: Color) -> void:
	if mesh_node == null:
		return

	var material := mesh_node.get_active_material(0) as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		mesh_node.set_surface_override_material(0, material)
	material.albedo_color = color_value


func _ensure_progress_fill_style() -> void:
	if progress_2d == null:
		return
	if _progress_fill_style != null:
		return
	var fill_style := progress_2d.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style == null:
		fill_style = StyleBoxFlat.new()
	else:
		fill_style = fill_style.duplicate() as StyleBoxFlat
	progress_2d.add_theme_stylebox_override("fill", fill_style)
	_progress_fill_style = fill_style


func _apply_progress_fill_color(badness: float = 0.0) -> void:
	_ensure_progress_fill_style()
	if _progress_fill_style == null:
		return
	_progress_fill_style.bg_color = oxygen_bar_good.lerp(oxygen_bar_bad, badness)


func _apply_hud_tint(badness: float) -> void:
	if _hud_tint == null:
		_hud_tint = get_node_or_null(hud_tint_path) as ColorRect
	if _hud_tint == null:
		return
	_hud_tint.color = hud_tint_good.lerp(hud_tint_bad, badness)


func _apply_player_oxygen_fx(displayed_oxygen: float) -> void:
	var loss_upper: float = maxf(oxygen_loss_fx_start_threshold, oxygen_loss_fx_stop_threshold)
	var loss_lower: float = minf(oxygen_loss_fx_start_threshold, oxygen_loss_fx_stop_threshold)
	var gain_active: bool = _is_oxygen_refilling()
	var loss_active: bool = displayed_oxygen <= loss_upper and displayed_oxygen > loss_lower and not gain_active
	var loss_amount: float = inverse_lerp(loss_upper, loss_lower, displayed_oxygen)
	if displayed_oxygen <= loss_lower:
		loss_amount = 0.0
	loss_amount = clampf(loss_amount, 0.0, 1.0)
	var gain_amount: float = 0.0
	if gain_active:
		var refill_span: float = maxf(absf(_displayed_oxygen_to - _displayed_oxygen_from), 0.001)
		gain_amount = clampf((_displayed_oxygen_level - _displayed_oxygen_from) / refill_span, 0.0, 1.0)

	_apply_vfx_shader_params(loss_active, loss_amount, gain_active, gain_amount)


func _apply_vfx_shader_params(loss_active: bool, loss_amount: float, gain_active: bool, gain_amount: float) -> void:
	if _player_vfx_mesh == null:
		_player_vfx_mesh = get_node_or_null(player_vfx_mesh_path) as MeshInstance3D
	if _player_vfx_mesh == null:
		return

	var material := _player_vfx_mesh.get_active_material(0) as ShaderMaterial
	if material == null:
		material = _player_vfx_mesh.material_override as ShaderMaterial
	if material == null:
		return

	material.set_shader_parameter("oxygen_level", clampf(_displayed_oxygen_level / 100.0, 0.0, 1.0))
	material.set_shader_parameter("loss_active", loss_active)
	material.set_shader_parameter("loss_amount", loss_amount)
	material.set_shader_parameter("gain_active", gain_active)
	material.set_shader_parameter("gain_amount", gain_amount)


func _oxygen_badness() -> float:
	return _oxygen_badness_for(oxygen_level)


func _oxygen_badness_for(oxygen_value: float) -> float:
	# Keep visuals fully good at 50% oxygen and above, then accelerate near danger.
	var normalized: float = clampf((50.0 - oxygen_value) / 50.0, 0.0, 1.0)
	return pow(normalized, 1.35)
