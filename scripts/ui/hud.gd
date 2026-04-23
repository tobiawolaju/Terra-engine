extends CanvasLayer

@onready var forward_button: Button = $Root/ForwardButton
@onready var backward_button: Button = $Root/BackButton
@onready var left_button: Button = $Root/LeftButton
@onready var right_button: Button = $Root/RightButton
@onready var jump_button: Button = $Root/JumpButton


func _ready() -> void:
	_bind_hold_button(forward_button, "forward")
	_bind_hold_button(backward_button, "backward")
	_bind_hold_button(left_button, "left")
	_bind_hold_button(right_button, "right")
	_bind_hold_button(jump_button, "jump")


func _bind_hold_button(button: Button, action_name: String) -> void:
	button.button_down.connect(func() -> void:
		Input.action_press(action_name)
	)
	button.button_up.connect(func() -> void:
		Input.action_release(action_name)
	)
