extends Node2D

func _ready() -> void:
	print("seed: ", WorldState.world_seed, "  night: ", WorldState.night)
	print("inventory: ", Inventory.counts)
	print("fog bytes: ", WorldState.fog_bytes.size())
	Global.in_cave = false

func _process(delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B:
				SceneManager.go_to("res://Scenes/main.tscn")
			KEY_C:
				var r := Recipes.get_recipe(&"common_star_lamp")
				if r == null:
					print("no recipe found, check the folder and the id")
					return
				print("craft: ", Inventory.craft(r), " lamps: ", Inventory.get_count(&"common_star_lamp"))
			KEY_V:
				var r := Recipes.get_recipe(&"common_star_lamp")
				if r == null:
					print("no recipe found")
					return
				print("sell: ", Inventory.sell(r), " currency: ", Inventory.currency)
