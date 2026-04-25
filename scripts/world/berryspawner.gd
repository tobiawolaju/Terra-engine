extends Node

@export var berry_scene: PackedScene
@export var spawn_interval_seconds: float = 10.0
@export var max_berries: int = 10
@export var min_berry_scale: float = 1.0
@export var max_berry_scale: float = 3.0
@export var spawn_point_1: Node3D
@export var spawn_point_2: Node3D
@export var spawn_point_3: Node3D
@export var spawn_point_4: Node3D
@export var spawn_point_5: Node3D

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_timer: Timer
var _spawned_berries: Array[WeakRef] = []


func _ready() -> void:
	Resolution.apply_quality_preset("performance")
	_rng.randomize()
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.autostart = false
	_spawn_timer.wait_time = maxf(spawn_interval_seconds, 0.1)
	_spawn_timer.timeout.connect(_spawn_berry)
	add_child(_spawn_timer)
	_spawn_timer.start()


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
