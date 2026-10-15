class_name ItemData
extends Resource

@export var id: StringName
@export var display_name: String
@export var color: Color = Color.WHITE
@export var icon: Texture2D
@export var light_refill: float = 20.0
@export_range(1, 100) var spawn_weight: int = 10
@export var min_distance: int = 0
