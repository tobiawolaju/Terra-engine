extends Node

@export var berry_scene: PackedScene
@export var spawn_interval_seconds: float = 10.0
@export var max_berries: int = 10
@export var min_berry_scale: float = 1.0
@export var max_berry_scale: float = 3.0
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
var _deadalien_consumed: bool = false
var _death_triggered: bool = false
var oxygen_level: float = 50.0

const LIGHT_GOOD: Color = Color("f6e7b5")
const LIGHT_BAD: Color = Color("9c3d3a")
const GROUND_NORMAL: Color = Color("477725")
const GROUND_BAD: Color = Color("4a3b34")
const WATER_NORMAL: Color = Color("2f6bffc0")
const WATER_BAD: Color = Color("7a4a2ec0")
const OXYGEN_BAR_NORMAL_MODULATE: Color = Color("ffffff")
const OXYGEN_BAR_BAD_MODULATE: Color = Color("d16666")
const HUD_TINT_GOOD: Color = Color(0, 0, 0, 0)
const HUD_TINT_BAD: Color = Color("#b2007475")
const BLOOM_GOOD: float = 0.2
const BLOOM_BAD: float = 0.4


func _ready() -> void:
	Resolution.apply_quality_preset("performance")
	_rng.randomize()
	_lake_label = get_node_or_null(lake_label_path) as Label3D
	_directional_light = get_node_or_null(directional_light_path) as DirectionalLight3D
	_world_environment = get_node_or_null(world_environment_path) as WorldEnvironment
	_ground_mesh = get_node_or_null(ground_mesh_path) as MeshInstance3D
	_water_mesh = get_node_or_null(water_mesh_path) as MeshInstance3D
	_hud_tint = get_node_or_null(hud_tint_path) as ColorRect
	_player_controller = get_node_or_null(player_controller_path)
	_deadalien = get_node_or_null(deadalien_path) as Node3D
	if progress_2d == null:
		progress_2d = get_node_or_null("HUD/ProgressBar") as ProgressBar
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

	_apply_oxygen_to_progress()
	_update_lake_label(0)


func _process(_delta: float) -> void:
	_cleanup_spawned_berries()
	_handle_lake_logic()


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
				_add_oxygen(10.0)
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
	_add_oxygen(-2.0)


func _add_oxygen(delta_amount: float) -> void:
	oxygen_level = clampf(oxygen_level + delta_amount, 0.0, 100.0)
	_apply_oxygen_to_progress()

	if oxygen_level <= 0.0 and not _death_triggered:
		_death_triggered = true
		_trigger_player_death()


func _trigger_player_death() -> void:
	if _player_controller == null:
		_player_controller = get_node_or_null(player_controller_path)
	if _player_controller == null:
		return
	if _player_controller.has_method("set_dead_state"):
		_player_controller.call("set_dead_state", true)


func _apply_oxygen_to_progress() -> void:
	if progress_2d != null:
		progress_2d.min_value = 0.0
		progress_2d.max_value = 100.0
		progress_2d.value = oxygen_level
		_apply_progress_modulate()
	_apply_oxygen_visuals()


func _apply_oxygen_visuals() -> void:
	var badness: float = _oxygen_badness()
	var light_color: Color = LIGHT_GOOD.lerp(LIGHT_BAD, badness)
	var ground_color: Color = GROUND_NORMAL.lerp(GROUND_BAD, badness)
	var water_color: Color = WATER_NORMAL.lerp(WATER_BAD, badness)

	_apply_directional_light_color(light_color)
	_apply_environment_bloom(badness)
	_apply_mesh_albedo(_ground_mesh, ground_color)
	_apply_mesh_albedo(_water_mesh, water_color)
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
	_world_environment.environment.glow_bloom = lerpf(BLOOM_GOOD, BLOOM_BAD, badness)


func _apply_mesh_albedo(mesh_node: MeshInstance3D, color_value: Color) -> void:
	if mesh_node == null:
		return

	var material := mesh_node.get_active_material(0) as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		mesh_node.set_surface_override_material(0, material)
	material.albedo_color = color_value


func _apply_progress_modulate() -> void:
	if progress_2d == null:
		return
	progress_2d.modulate = OXYGEN_BAR_NORMAL_MODULATE


func _apply_hud_tint(badness: float) -> void:
	if _hud_tint == null:
		_hud_tint = get_node_or_null(hud_tint_path) as ColorRect
	if _hud_tint == null:
		return
	_hud_tint.color = HUD_TINT_GOOD.lerp(HUD_TINT_BAD, badness)


func _oxygen_badness() -> float:
	# Keep visuals calmer above ~60% oxygen, then accelerate near danger.
	var normalized: float = clampf((60.0 - oxygen_level) / 60.0, 0.0, 1.0)
	return pow(normalized, 1.35)
