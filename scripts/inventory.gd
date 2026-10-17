extends Node

signal item_changed(id: StringName, new_count: int)
signal currency_changed(new_amount: int)
signal crafted(recipie: RecipeData)
signal sold(id: StringName, amount: int, earned: int)

var counts: Dictionary = {}
var currency: int = 0
var made: Dictionary = {}
var sold_counts: Dictionary = {}

#region items
func get_count(id: StringName) -> int: 
	return counts.get(id, 0)

func add(id: StringName, amount: int = 1) -> void:
	counts[id] = get_count(id) + amount
	item_changed.emit(id, counts[id])

func can_afford(id: StringName, amount: int) -> bool:
	return get_count(id) >= amount

func spend(id: StringName, amount: int) -> bool:
	if not can_afford(id, amount):
		return false
	counts[id] -= amount
	item_changed.emit(id, counts[id])
	return true
#endregion

#region currency
func add_currency(amount: int) -> void:
	currency += amount
	currency_changed.emit(currency)

func spend_currency(amount: int) -> bool:
	if currency < amount:
		return false
	currency -= amount
	currency_changed.emit(currency)
	return true
#endregion

#region crafting
func can_craft(recipe: RecipeData) -> bool:
	for id in recipe.inputs:
		if not can_afford(id, recipe.inputs[id]):
			return false
	return true

func craft(recipe: RecipeData) -> bool:
	if not can_craft(recipe):
		return false
	for id in recipe.inputs:
		spend(id, recipe.inputs[id])
	add(recipe.id, 1)
	made[recipe.id] = made.get(recipe.id, 0) + 1
	crafted.emit(recipe)
	return true
#endregion

#region selling
func sell(recipe: RecipeData, amount: int = 1) -> bool:
	amount = mini(amount, get_count(recipe.id))
	if amount <= 0:
		return false
	spend(recipe.id, amount)
	var earned := recipe.sale_value * amount
	add_currency(earned)
	sold_counts[recipe.id] = sold_counts.get(recipe.id, 0) + amount
	sold.emit(recipe.id, amount, earned)
	return true
#endregion

#region dictionary
func to_dict() -> Dictionary:
	#var out := {}
	#for id in counts: 
		#out[str(id)] = counts[id]
	#return {"counts": out}
	return {
		"counts": _stringify(counts),
		"currency": currency,
		"made": _stringify(made),
		"sold": _stringify(sold_counts),
	}

func _stringify(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[str(k)] = src[k]
	return out

func _destringify(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[StringName(k)] = int(src[k])
	return out

func from_dict(d: Dictionary) -> void:
	var old_ids := counts.keys()
	counts.clear()
	var saved: Dictionary = d.get("counts", {})
	for k in saved:
		var id := StringName(k)
		counts[id] = int(saved[k])
		item_changed.emit(id, counts[id])
	for id in old_ids:
		if not counts.has(id):
			item_changed.emit(id, 0)
	for id in counts:
		item_changed.emit(id, counts[id])
#endregion

func lose_fraction(fraction: float) -> Dictionary:
	var lost := {}
	for id in counts.keys():
		if Recipes.get_recipe(id) != null:
			continue
		var amount := floori(counts[id] * fraction)
		if amount > 0:
			counts[id] -= amount
			lost[id] = amount
			item_changed.emit(id, counts[id])
	return lost
