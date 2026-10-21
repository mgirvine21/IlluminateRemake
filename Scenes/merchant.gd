extends Interactable

const FIRST_NIGHT := 2
const RETURN_EVERY := 3
const LAMP_ID := &"common_star_lamp"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	prompt = "Talk"
	super._ready()
	var here := _is_here()
	visible = here
	monitoring = here
	if here:
		_announce_arrival()

func _is_here() -> bool:
	var n := WorldState.night
	return n >= FIRST_NIGHT and (n - FIRST_NIGHT) % RETURN_EVERY == 0

func _announce_arrival() -> void:
	if int(WorldState.flags.get(&"merchant_last_arrival", -1)) == WorldState.night:
		return
	WorldState.flags[&"merchant_last_arrival"] = WorldState.night
	await get_tree().create_timer(0.0).timeout
	Pop_Up.toast("The merchant has arrived!")

func can_interact(_p: Player) -> bool:
	return visible

func interact(_p: Player) -> void:
	if not WorldState.has_flag(&"merchant_met"):
		await _first_meeting()
	elif not WorldState.has_flag(&"merchant_got_lamp"):
		await _ask_for_lamp()
	else:
		await Pop_Up.say("Merchant", ["Keep the lamps coming. I'll collect them each night."])

func _first_meeting() -> void:
	await Pop_Up.say("Merchant", [
		"Oh! A dragon... I think. I can barely see you.", 
		"It's tpp dark out here to make my deliveries.", 
		"If you could craft me a light, I could sell them for you.",
		"There's a workbench in your nest. Try it out.",
	])
	WorldState.set_flag(&"merchant_met")
	WorldState.set_flag(&"workbench_unlocked")
	get_tree().call_group("interactables", "refresh")
	Pop_Up.toast("Workbench unlocked! Crafting is now available.")

func _ask_for_lamp() -> void:
	if Inventory.spend(LAMP_ID, 1):
		WorldState.set_flag(&"merchant_got_lamp")
		get_tree().call_group("interactables", "refresh")
		await Pop_Up.say("Merchant", [
			"Wonderful craftsmanship. I can see again in this dark.", 
			"I can sell these. Make more and I'll pick them up.",
		])
		Pop_Up.toast("You can now ship lamps from the workbench.")
	else:
		await Pop_Up.say("Merchant", ["Still too dark to see... did you make that lamp?"])

func _on_crafted(recipe: RecipeData) -> void:
	if recipe.id == LAMP_ID and WorldState.has_flag(&"merchant_met") \
	and not WorldState.has_flag(&"merchant_got_lamp"):
		Pop_Up.toast("Bring the lamp to the merchant.")

func _open_shop() -> void:
	print("shop menu")
