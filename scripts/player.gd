@tool
class_name Player
extends CharacterBody2D

const GLIDE_TERMINAL_VELOCITY = 100

@export var player: Global.Player = Global.Player.ONE
@export var _map_marker: Sprite2D
@export var sprite_frames: SpriteFrames = _initial_sprite_frames:
	set = _set_sprite_frames
@export_range(0, 1000, 10, "suffix:px/s") var speed: float = 500.0:
	set = _set_speed
@export_range(0, 5000, 1000, "suffix:px/s²") var acceleration: float = 5000.0
@export_range(0, 2000, 1000, "suffix:px/s") var jump_velocity = 880.0
@export_range(0, 100, 5, "suffix:%") var jump_cut_factor: float = 20
@export_range(0, 0.5, 1 / 60.0, "suffix:s") var coyote_time: float = 5.0 / 60.0
@export_range(0, 0.5, 1 / 60.0, "suffix:s") var jump_buffer: float = 5.0 / 60.0
@export var double_jump: bool = false

var coyote_timer: float = 0
var jump_buffer_timer: float = 0
var double_jump_armed: bool = false
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var original_position: Vector2

var is_sleeping: bool = false
var quota_reached: bool = true

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _initial_sprite_frames: SpriteFrames = $AnimatedSprite2D.sprite_frames



func _set_sprite_frames(new_sprite_frames):
	sprite_frames = new_sprite_frames
	if sprite_frames and is_node_ready():
		_sprite.sprite_frames = sprite_frames

func _set_speed(new_speed):
	speed = new_speed
	if is_node_ready():
		_sprite.speed_scale = speed / 500



func _ready():
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
	else:
		Global.gravity_changed.connect(_on_gravity_changed)
		Global.lives_changed.connect(_on_lives_changed)
	
	original_position = position
	_set_speed(speed)
	_set_sprite_frames(sprite_frames)
	_add_player_to_map()

func _on_gravity_changed(new_gravity):
	gravity = new_gravity

func _on_lives_changed():
	if Global.lives > 0:
		reset()
		
func _jump():
	velocity.y = -jump_velocity
	coyote_timer = 0
	jump_buffer_timer = 0
	if double_jump_armed:
		double_jump_armed = false
	elif double_jump:
		double_jump_armed = true

func stomp():
	double_jump_armed = false
	_jump()

func _glide() -> void: 
	if not is_on_floor() and Input.is_action_pressed(Actions.lookup(player, "jump")):
		if velocity.y > GLIDE_TERMINAL_VELOCITY:
			velocity.y = GLIDE_TERMINAL_VELOCITY

func _interact() -> void:
	if !is_sleeping and quota_reached and Input.is_action_just_pressed(Actions.lookup(player,"interact" )):
		is_sleeping = true
		print("sleep")
		_sprite.play("sleep")
		place_stars()

func place_stars() -> void:
	pass
	#PLACE NIGHTLIGHTS FOR DRAGON

func _add_player_to_map() -> void:
	if Engine.is_editor_hint():
		return
	_map_marker = Sprite2D.new()
	_map_marker.texture = preload("res://Assets/dragon.png")
	_map_marker.scale = Vector2(0.05, 0.05)
	%MiniMap.add_child(_map_marker)


func _update_map_marker() -> void:
	if _map_marker == null:
		return
	var cave: TileMapLayer = %Cave
	var cell: Vector2i = cave.local_to_map(cave.to_local(global_position))
	# Cells are centered on the origin (-45..44, -30..29), the image starts at 0,0.
	_map_marker.position = Vector2(cell.x + 45, cell.y + 30)

func _physics_process(delta):
	if Global.lives <= 0:
		return
	if is_on_floor():
		coyote_timer = coyote_time
		double_jump_armed = false
	else:
		coyote_timer -= delta

	if Input.is_action_just_pressed(Actions.lookup(player, "jump")):
		jump_buffer_timer = jump_buffer

	if jump_buffer_timer > 0 and (double_jump_armed or coyote_timer > 0):
		_jump()

	if Input.is_action_just_released(Actions.lookup(player, "jump")) and velocity.y < 0:
		velocity.y *= (1 - (jump_cut_factor / 100.00))

	if not is_on_floor():
		velocity.y += gravity * delta

	var direction = Input.get_axis(Actions.lookup(player, "left"), Actions.lookup(player, "right"))
	if direction:
		velocity.x = move_toward(velocity.x, sign(direction) * speed, abs(direction) * acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)

		_interact()

	if is_sleeping:
		_sprite.play("sleep")
	elif velocity == Vector2.ZERO:
		_sprite.play("default")
	else:
		if not is_on_floor():
			_sprite.play("fall" if velocity.y > 0 else "jump")
		else:
			_sprite.play("walk")
		_sprite.flip_h = velocity.x < 0
	var old_position := global_position

	move_and_slide()

	var actual_motion := global_position - old_position

	if abs(velocity.x) > 1.0 and abs(actual_motion.x) > 0.001:
		if sign(actual_motion.x) != sign(velocity.x):
			print(
			"ACTUALLY BACKWARD!",
			" velocity=", velocity.x,
			" motion=", actual_motion.x,
			" position=", global_position.x)

	jump_buffer_timer -= delta 
	_update_map_marker()

func reset():
	position = original_position
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	coyote_timer = 0
	jump_buffer_timer = 0
	double_jump_armed = false
