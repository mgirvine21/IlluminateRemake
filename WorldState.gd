extends Node

var world_seed: String = "Hello Godot!"
var night: int = 0
var broken_walls: Array[Vector2i] = []
var fog_bytes: PackedByteArray = PackedByteArray()
var unlocked_entrances: Array[StringName] = [&"main"]

func new_game(seed_text: String = "") -> void:
	world_seed = seed_text if seed_text != "" else str(randi())
	night = 0
	broken_walls.clear()
	fog_bytes = PackedByteArray()
	unlocked_entrances.clear()
	unlocked_entrances.append(&"main")

func to_dict() -> Dictionary:
	var walls := []
	for c in broken_walls:
		walls.append([c.x, c.y])
	return {
		"world_seed": world_seed,
		"night": night, 
		"broken_walls": walls, 
		"fog": Marshalls.raw_to_base64(fog_bytes),
		"entrances": unlocked_entrances.map(func(e): return str(e)),
	}

func from_dict(d: Dictionary) -> void:
	world_seed = d.get("world_seed", "Hello Godot!")
	night = int(d.get("night", 0))
	broken_walls.clear()
	for p in d.get("broken_walls", []):
		broken_walls.append(Vector2i(int(p[0]), int(p[1])))
	fog_bytes = Marshalls.base64_to_raw(d.get("fog", ""))
	unlocked_entrances.clear()
	for e in d.get("entrances", ["main"]):
		unlocked_entrances.append(StringName(e))

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
