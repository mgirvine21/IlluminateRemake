@tool
extends CanvasLayer

@onready var ending_labels  = {
	Global.Endings.WIN:
	%WinEnding,
	Global.Endings.LOSE:
	%LoseEnding,
}

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	%TimeLeft.text = "%1.f" % Global.timer.time_left

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	
	Global.lives_changed.connect(_on_lives_changed)
	Inventory.item_changed.connect(_on_item_changed)
	
	if Engine.is_editor_hint():
		return
	
	Global.timer_added.connect(_on_timer_added)

func _unhandled_input(event):
	if event is InputEventKey and %Start.is_visible_in_tree():
		%Start.hide()
		%ColorRect.hide()
		Global.game_started.emit()

func _on_item_changed(_id: StringName, _count: int) -> void:
	var total := 0
	for id in Inventory.counts:
		total += Inventory.counts[id]
	%CollectedStars.text = "Stars: " + str(total)

func _on_lives_changed():
	#set_lives(Global.lives)
	pass

func set_lives(lives: int):
	#%Lives.offset_right = %Lives.offset_left + lives * %Lives.texture.get_width()
	pass

func _on_timer_added():
	%TimeLeft.visible = true
	set_process(true)

func _on_game_ended(ending: Global.Endings):
	ending_labels[ending].visible = true
