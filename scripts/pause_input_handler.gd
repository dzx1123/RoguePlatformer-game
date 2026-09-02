extends Node

## Keeps pause and menu key capture responsive while the gameplay tree is paused.
signal key_pressed(event: InputEventKey)
signal input_device_changed(using_controller: bool)
signal controller_pause_pressed
signal controller_cancel_pressed

var _using_controller: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		_set_using_controller(false)
	elif event is InputEventJoypadButton and event.is_pressed():
		_set_using_controller(true)
		if event.is_action_pressed(&"pause"):
			controller_pause_pressed.emit()
		elif event.is_action_pressed(&"ui_cancel"):
			controller_cancel_pressed.emit()
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.55:
		_set_using_controller(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		key_pressed.emit(event)


func set_initial_device(using_controller: bool) -> void:
	_set_using_controller(using_controller)


func _set_using_controller(value: bool) -> void:
	if value == _using_controller:
		return
	_using_controller = value
	input_device_changed.emit(_using_controller)
