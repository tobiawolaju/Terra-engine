extends CanvasLayer

signal joystick_moved(direction: Vector2)
signal joystick_released

@export var min_opacity: float = 0.2
@export var max_opacity: float = 1.0
@export var deadzone: float = 0.05
@export var return_to_center: bool = true
@export var joy_base_path: NodePath = NodePath("JoyBase")
@export var joy_knob_path: NodePath = NodePath("JoyBase/JoyKnob")
@export var pick_button_path: NodePath = NodePath("Button")
@export var day_spent_label_path: NodePath = NodePath("Dayspent")
@export var combo_label_path: NodePath = NodePath("Combo")
@export var combo_fx_path: NodePath = NodePath("ComboFX")

@onready var joy_base: Control = get_node(joy_base_path)
@onready var joy_knob: Control = get_node(joy_knob_path)
@onready var pick_button: BaseButton = get_node_or_null(pick_button_path) as BaseButton
@onready var username_label: Label = $Username
@onready var day_spent_label: Label = get_node_or_null(day_spent_label_path) as Label
@onready var combo_label: Label = get_node_or_null(combo_label_path) as Label
@onready var combo_fx: Node = get_node_or_null(combo_fx_path)

var _active_touch_index: int = -1
var _mouse_drag_active: bool = false
var _knob_direction: Vector2 = Vector2.ZERO
var _base_center: Vector2 = Vector2.ZERO
var _max_offset: float = 0.0
var _elapsed_seconds: int = 0
var _elapsed_timer: Timer
var _combo_label_tween: Tween
const SECONDS_PER_DAY: int = 120


func _ready() -> void:
	add_to_group("touch_joystick")
	joy_base.mouse_filter = Control.MOUSE_FILTER_STOP
	joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_base.gui_input.connect(_on_joy_base_gui_input)
	if pick_button != null:
		pick_button.pressed.connect(_on_pick_button_pressed)
	_refresh_geometry()
	_reset_joystick()
	set_username("...")
	set_elapsed_time(0)
	_start_elapsed_timer()


func _exit_tree() -> void:
	if _elapsed_timer != null and is_instance_valid(_elapsed_timer):
		_elapsed_timer.stop()
	Input.action_release("pick")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _active_touch_index == -1 and _touch_in_base_area(event.position):
				_active_touch_index = event.index
				_update_joystick(_screen_to_base_local(event.position))
				get_viewport().set_input_as_handled()
		elif event.index == _active_touch_index:
			_release_joystick()
			get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag and event.index == _active_touch_index:
		_update_joystick(_screen_to_base_local(event.position))
		get_viewport().set_input_as_handled()


func _on_joy_base_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_drag_active = true
			_update_joystick(event.position)
		else:
			if _mouse_drag_active:
				_mouse_drag_active = false
				_release_joystick()
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _mouse_drag_active:
		_update_joystick(event.position)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _max_offset <= 0.0:
		_refresh_geometry()


func _refresh_geometry() -> void:
	if joy_base == null or joy_knob == null:
		return

	_base_center = joy_base.size * 0.5
	_max_offset = max(1.0, (joy_base.size.x * 0.5) - (joy_knob.size.x * 0.5))


func _update_joystick(local_pos: Vector2) -> void:
	_refresh_geometry()

	var offset: Vector2 = local_pos - _base_center
	if offset.length() > _max_offset:
		offset = offset.normalized() * _max_offset

	_knob_direction = offset / _max_offset
	_move_knob(offset)
	_update_actions()
	_update_visuals()
	joystick_moved.emit(_knob_direction)


func _move_knob(offset: Vector2) -> void:
	if joy_knob == null or joy_base == null:
		return

	joy_knob.position = _base_center + offset - (joy_knob.size * 0.5)


func _release_joystick() -> void:
	_active_touch_index = -1
	_mouse_drag_active = false
	_knob_direction = Vector2.ZERO
	_release_actions()
	if return_to_center:
		_reset_joystick()
	else:
		_update_visuals()
	joystick_released.emit()


func _reset_joystick() -> void:
	_refresh_geometry()
	if joy_knob != null:
		joy_knob.position = _base_center - (joy_knob.size * 0.5)
	_update_visuals()


func _update_actions() -> void:
	_release_actions()

	if _knob_direction.x > deadzone:
		Input.action_press("right", _knob_direction.x)
	elif _knob_direction.x < -deadzone:
		Input.action_press("left", -_knob_direction.x)

	if _knob_direction.y < -deadzone:
		Input.action_press("forward", -_knob_direction.y)
	elif _knob_direction.y > deadzone:
		Input.action_press("backward", _knob_direction.y)


func _release_actions() -> void:
	Input.action_release("forward")
	Input.action_release("backward")
	Input.action_release("left")
	Input.action_release("right")


func _update_visuals() -> void:
	if joy_base == null or joy_knob == null:
		return

	var strength: float = clampf(_knob_direction.length(), 0.0, 1.0)
	var alpha: float = lerpf(min_opacity, max_opacity, strength)
	joy_base.modulate.a = alpha
	joy_knob.modulate.a = alpha


func _touch_in_base_area(screen_pos: Vector2) -> bool:
	if joy_base == null:
		return false
	return joy_base.get_global_rect().has_point(screen_pos)


func is_joystick_area_screen(screen_pos: Vector2, _viewport_size: Vector2 = Vector2.ZERO) -> bool:
	return _touch_in_base_area(screen_pos)


func is_dragging_joystick() -> bool:
	return _active_touch_index != -1 or _mouse_drag_active


func _screen_to_base_local(screen_pos: Vector2) -> Vector2:
	if joy_base == null:
		return screen_pos
	var canvas_transform: Transform2D = joy_base.get_global_transform_with_canvas()
	return canvas_transform.affine_inverse() * screen_pos


func set_username(username: String) -> void:
	if username_label == null:
		return
	username_label.text = "Player: " + username


func set_elapsed_time(seconds: int, _target_seconds: int = -1) -> void:
	if day_spent_label == null:
		return
	_elapsed_seconds = max(seconds, 0)
	var day: int = _elapsed_seconds / SECONDS_PER_DAY
	day_spent_label.text = "Day %d" % day


func set_score_text(text: String) -> void:
	if day_spent_label == null:
		return
	day_spent_label.text = text


func show_combo_feedback(text: String, positive: bool = true) -> void:
	if combo_label == null:
		return

	if _combo_label_tween != null and is_instance_valid(_combo_label_tween):
		_combo_label_tween.kill()

	combo_label.text = text
	combo_label.visible = true
	combo_label.modulate = Color(1, 1, 1, 0) if positive else Color(1, 0.45, 0.45, 0)
	combo_label.scale = Vector2.ONE * 0.5

	_combo_label_tween = create_tween()
	_combo_label_tween.tween_property(combo_label, "modulate", Color(1, 1, 1, 1) if positive else Color(1, 0.45, 0.45, 1), 0.12)
	_combo_label_tween.parallel().tween_property(combo_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_combo_label_tween.tween_interval(0.35)
	_combo_label_tween.tween_property(combo_label, "modulate", Color(1, 1, 1, 0) if positive else Color(1, 0.45, 0.45, 0), 1.0)


func play_combo_fx(combo_count: int = 1, reward: float = 0.0) -> void:
	if combo_fx == null:
		return

	if combo_fx.has_method("restart"):
		combo_fx.call("restart")
		return

	if combo_fx is CPUParticles2D:
		var cpu_fx := combo_fx as CPUParticles2D
		cpu_fx.emitting = false
		cpu_fx.restart()
		cpu_fx.emitting = true
		return

	if combo_fx is GPUParticles2D:
		var gpu_fx := combo_fx as GPUParticles2D
		gpu_fx.emitting = false
		gpu_fx.restart()
		gpu_fx.emitting = true


func get_elapsed_seconds() -> int:
	return _elapsed_seconds


func _start_elapsed_timer() -> void:
	if _elapsed_timer != null and is_instance_valid(_elapsed_timer):
		return

	_elapsed_timer = Timer.new()
	_elapsed_timer.wait_time = 1.0
	_elapsed_timer.one_shot = false
	_elapsed_timer.autostart = false
	_elapsed_timer.timeout.connect(_on_elapsed_timer_timeout)
	add_child(_elapsed_timer)
	_elapsed_timer.start()


func _on_elapsed_timer_timeout() -> void:
	set_elapsed_time(_elapsed_seconds + 1)


func _on_pick_button_pressed() -> void:
	if not InputMap.has_action("pick"):
		return
	Input.action_press("pick")
	await get_tree().physics_frame
	Input.action_release("pick")
