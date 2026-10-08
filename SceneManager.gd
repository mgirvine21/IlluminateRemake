extends CanvasLayer

var _rect := ColorRect.new()
var _busy := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect.color = Color.BLACK
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)

func go_to(path: String, duration: float = 0.4) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_error("SceneManager: no scene at %s" % path)
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var out := create_tween()
	out.tween_property(_rect, "modulate:a", 1.0, duration)
	await out.finished
	
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	
	var back := create_tween()
	back.tween_property(_rect, "modulate:a", 0.0, duration)
	await back.finished
	
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
