extends Interactable

@export var menu: MenuBase

func _ready() -> void:
	prompt = "Craft"
	super._ready()

func _can_interact(_p: Player) -> bool:
	return WorldState.has_flag(&"workbench_unlocked")

func interact(_p: Player) -> void:
	if menu: 
		menu.open()
	else:
		push_warning("WorkBench: assign the menu in the inspector")

func refresh() -> void:
	super.refresh()
	modulate = Color.WHITE if WorldState.has_flag(&"workbench_unlocked") else Color(1, 1, 1, 0.35)
