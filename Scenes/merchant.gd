extends Interactable

const ARRIVES_ON_NIGHT := 2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	visible = WorldState.night >= ARRIVES_ON_NIGHT
	monitoring = visible

func can_interact(_p: Player) -> bool:
	return visible

func interact(_p: Player) -> void:
	if not WorldState.has_flag(&"merchant_met"):
		_first_meeting()
	else:
		_open_shop()

func _first_meeting() -> void:
	if Inventory.spend(&"star_lamp", 1):
		WorldState.set_flag(&"merchant_met")
		WorldState.set_flag(&"workbench_unlocked")
		print("Merchant: Now this I can sell! Make more and I'll collect them.")
	else:
		print("I can't see a thing out here...")

func _open_shop() -> void:
	print("shop menu")
