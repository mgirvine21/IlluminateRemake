extends Node

signal item_changed(id: StringName, new_count: int)

var counts: Dictionary = {}

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

func lose_fraction(fraction: float) -> Dictionary:
	var lost := {}
	for id in counts.keys():
		var amount := floori(counts[id] * fraction)
		if amount > 0:
			counts[id] -= amount
			lost[id] = amount
			item_changed.emit(id, counts[id])
	return lost

func to_dict() -> Dictionary:
	var out := {}
	for id in counts: 
		out[str(id)] = counts[id]
	return {"counts": out}

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
