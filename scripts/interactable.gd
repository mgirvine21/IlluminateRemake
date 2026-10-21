class_name Interactable
extends Area2D

var _player: Player = null
@export var prompt: String = "Interact"
@export var enabled: bool = true:
	set(v):
		enabled = v
		if is_node_ready():
			refresh()
@onready var label: Label = get_node_or_null("InteractLabel")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("interactables")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	refresh()

func _can_interact(_p: Player) -> bool:
	return enabled

func interact(_p: Player) -> void:
	pass

func refresh() -> void:
	if label == null:
		return
	label.text = "[E] " + prompt
	label.visible = _player != null and _can_interact(_player)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player = body
		refresh()

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		refresh()

func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not _can_interact(_player):
		return
	if event.is_action_pressed(Actions.lookup(_player.player, "interact")):
		get_viewport().set_input_as_handled()
		interact(_player)
