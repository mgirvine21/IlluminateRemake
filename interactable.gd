extends Area2D

var _player: Player = null
@onready var interact_label: Label = $InteractLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player = body
		interact_label.show()

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		interact_label.hide()
