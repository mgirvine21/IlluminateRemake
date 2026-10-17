class_name MenuBase
extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()

func open() -> void:
	_on_open()
	show()
	get_tree().paused = true

func close() -> void:
	hide()
	get_tree().paused = false

func _on_open() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
