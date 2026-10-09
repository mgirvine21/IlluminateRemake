@tool
class_name Door
extends Area2D

@export_file("*.tscn") var target_scene: String

var _player: Player = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player = body

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null

func _unhandled_input(event: InputEvent) -> void:
	if _player == null or target_scene.is_empty():
		return
	if event.is_action_pressed(Actions.lookup(_player.player, "interact")):
		get_viewport().set_input_as_handled()
		SceneManager.go_to(target_scene)
	
