extends Node

@export var berry_scene: PackedScene
@export var spawn_interval_seconds: float = 10.0
@export var max_berries: int = 10
@export var min_berry_scale: float = 1.0
@export var max_berry_scale: float = 3.0
@export var progress_2d: ProgressBar
@export var world_environment_path: NodePath = NodePath("WorldEnvironment")
@export var ground_mesh_path: NodePath = NodePath("ground/hill/hillmesh")
@export var water_mesh_path: NodePath = NodePath("berrylake/water")
@export var lake_surface_y: float = 0.0
@export var destroy_after_seconds: float = 5.0
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
var _world_environment: WorldEnvironment
var _ground_mesh: MeshInstance3D
var _water_mesh: MeshInstance3D
var oxygen_level: float = 50.0

const SKY_BAD: Color = Color("ffd586")
const SKY_NORMAL: Color = Color("c8ddfd")
const GROUND_BAD: Color = Color("2b2b2b")
const GROUND_NORMAL: Color = Color("477725")
const WATER_BAD: Color = Color("a35706c0")
const WATER_NORMAL: Color = Color("5644ffc0")
const OXYGEN_BAR_NORMAL_MODULATE: Color = Color("ffffff")
const OXYGEN_BAR_BAD_MODULATE: Color = Color("ff00ff")


func _ready() -> void:
	Resolution.apply_quality_preset("performance")
	_rng.randomize()
	_lake_label = get_node_or_null(lake_label_path) as Label3D
	_world_environment = get_node_or_null(world_environment_path) as WorldEnvironment
	_ground_mesh = get_node_or_null(ground_mesh_path) as MeshInstance3D
	_water_mesh = get_node_or_null(water_mesh_path) as MeshInstance3D
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

	for berry_id: Variant in _underwater_since.keys():
		if not alive_ids.has(berry_id):
			_underwater_since.erase(berry_id)

	_update_lake_label(underwater_count)


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


func _apply_oxygen_to_progress() -> void:
	if progress_2d != null:
		progress_2d.min_value = 0.0
		progress_2d.max_value = 100.0
		progress_2d.value = oxygen_level
		_apply_progress_modulate()
	_apply_oxygen_visuals()


func _apply_oxygen_visuals() -> void:
	var badness: float = clampf((50.0 - oxygen_level) / 50.0, 0.0, 1.0)
	var sky_color: Color = SKY_NORMAL.lerp(SKY_BAD, badness)
	var ground_color: Color = GROUND_NORMAL.lerp(GROUND_BAD, badness)
	var water_color: Color = WATER_NORMAL.lerp(WATER_BAD, badness)

	_apply_sky_color(sky_color)
	_apply_mesh_albedo(_ground_mesh, ground_color)
	_apply_mesh_albedo(_water_mesh, water_color)


func _apply_sky_color(sky_color: Color) -> void:
	if _world_environment == null or _world_environment.environment == null:
		return
	_world_environment.environment.background_mode = Environment.BG_COLOR
	_world_environment.environment.background_color = sky_color


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
	var badness: float = clampf((50.0 - oxygen_level) / 50.0, 0.0, 1.0)
	progress_2d.modulate = OXYGEN_BAR_NORMAL_MODULATE.lerp(OXYGEN_BAR_BAD_MODULATE, badness)
