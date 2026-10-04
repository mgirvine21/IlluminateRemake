extends Area2D

@export var data: ItemData

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if data:
		$Sprite2D.modulate = data.color


func _on_body_entered(body: Node2D) -> void:
	if body is Player and data:
		Global.collect_star(data)
		queue_free()
