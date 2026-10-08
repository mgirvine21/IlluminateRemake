extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("seed: ", WorldState.world_seed, "  night: ", WorldState.night)
	print("inventory: ", Inventory.counts)
	print("fog bytes: ", WorldState.fog_bytes.size())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		SceneManager.go_to("res://Scenes/main.tscn")  # your real path
