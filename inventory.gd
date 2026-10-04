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
