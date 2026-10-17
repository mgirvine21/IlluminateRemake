class_name RecipeData
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var inputs: Dictionary = {}
@export var sale_value: int = 5
@export var requires_flag: StringName = &""
