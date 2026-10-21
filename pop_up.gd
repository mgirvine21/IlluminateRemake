extends CanvasLayer

const TOAST_SIZE := 36
const NAME_SIZE := 34
const TEXT_SIZE := 28

signal advanced

var _toast := Label.new()
var _toast_tween: Tween
var _panel := PanelContainer.new()
var _name_label := Label.new()
var _text_label := Label.new()

func _style(label: Label, size: int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_style(_toast, TOAST_SIZE)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position.y = 40
	_toast.modulate.a = 0.0
	add_child(_toast)
	
	_style(_name_label, NAME_SIZE)
	_style(_text_label, TEXT_SIZE)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -220
	_panel.offset_left = 40
	_panel.offset_right = -40
	_panel.offset_bottom = -30
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	var box := VBoxContainer.new()
	box.add_child(_name_label)
	box.add_child(_text_label)
	margin.add_child(box)
	_panel.add_child(margin)
	_panel.hide()
	add_child(_panel)

func toast(text: String, seconds := 2.5) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)

func say(speaker: String, lines: Array) -> void:
	_name_label.text = speaker
	_panel.show()
	get_tree().paused = true
	for line in lines:
		_text_label.text = line
		await advanced
	_panel.hide()
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	var interact_action := Actions.lookup(Global.Player.ONE, "interact")
	if event.is_action_pressed("ui_accept") or event.is_action_pressed(interact_action) or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		advanced.emit()
