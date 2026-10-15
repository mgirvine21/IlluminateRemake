extends Interactable

func _can_interact(_p: Player) -> bool:
	return WorldState.has_flag(&"workbech_unlocked")

func interact(_p: Player) -> void:
	print("open crafting menu")
