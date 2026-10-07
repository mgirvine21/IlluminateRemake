extends Node

signal about_to_save

const PATH := "user://save.json"
const SAVEABLES: Array[String] = ["WorldState", "Inventory"]

func save() -> void:
	about_to_save.emit()
	var data := {}
	for autoload_name in SAVEABLES:
		data[autoload_name] = get_node("/root" + autoload_name).to_dict()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("BRUH: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))

func has_save() -> bool:
	return FileAccess.file_exists(PATH)

func load_game() -> bool:
	if not has_save():
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	for autoload_name in SAVEABLES:
		if parsed.has(autoload_name):
			get_node("/root/" + autoload_name).from_dict(parsed[autoload_name])
	return true
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
