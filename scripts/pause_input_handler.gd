extends Node

## Keeps pause and menu key capture responsive while the gameplay tree is paused.
signal key_pressed(event: InputEventKey)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		key_pressed.emit(event)
