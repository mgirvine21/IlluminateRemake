@tool
class_name Door
extends Area2D

@onready var interact_label: Label = $InteractLabel
@export_file("*.tscn") var target_scene: String
@export var is_interactable: bool = true
var current_interactions := []
var can_interact := true
var _player: Player = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	interact_label.hide()
	
func _process(delta: float) -> void:
	#if current_interactions and can_interact:
		#current_interactions.sort_custom(_sort_by_nearest)
		#if current_interactions[0].is_interactable:
			#interact_label.text = current_interactions[0].interact_name
			#interact_label.show()
		#
		#else:
			#interact_label.hide()
	pass

#func _sort_by_nearest(area1, area2):
	#var area1_dist = global_position.distance_to(area1.global_position)
	#var area2_dist = global_position.distance_to(area2.global_position)
	#return area1_dist < area2_dist
#
#func _on_interact_range_area_entered(area: Area2D) -> void:
	#current_interactions.push_back(area)
#
#func _on_interact_range_area_exited(area: Area2D) -> void:
	#current_interactions.erase(area)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player = body
		interact_label.show()

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		interact_label.hide()

func _unhandled_input(event: InputEvent) -> void:
	if _player == null or target_scene.is_empty():
		return
	if event.is_action_pressed(Actions.lookup(_player.player, "interact")) and is_interactable:
		#if current_interactions:
			#can_interact = false
			#interact_label.hide()
		get_viewport().set_input_as_handled()
		SceneManager.go_to(target_scene)
		#can_interact = true
	
