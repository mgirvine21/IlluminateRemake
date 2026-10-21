extends Node

var all: Array[RecipeData] = []
var _by_id: Dictionary = {}

const DIR := "res://data/recipes/"

func _ready() -> void:
	for file in DirAccess.get_files_at(DIR):
		var clean := file.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			var r := load(DIR + clean) as RecipeData
			if r: 
				all.append(r)
				_by_id[r.id] = r

func get_recipe(id: StringName) -> RecipeData:
	return _by_id.get(id)

func available() -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for r in all: 
		if r.requires_flag == &"" or WorldState.has_flag(r.requires_flag):
			out.append(r)
	return out
