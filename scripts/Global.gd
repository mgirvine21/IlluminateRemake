extends Node
signal star_collected
signal lives_changed
signal game_ended(ending: Endings)
signal game_started
signal gravity_changed(gravity: float)
#signal timer_added
signal light_meter_changed(value: float, max_value: float)
signal fainted(lost: Dictionary)

enum Endings { WIN, LOSE}
enum Player { ONE }
enum PhysicsLayers {
	PLAYER = 1,
	STARS = 2, 
	PLATFORMS = 3, 
	ENEMY = 4,
}

const MAX_LIGHT_METER := 100.0
const DRAIN_PER_SECOND := 5.0

#var timer: Timer
var light_meter: float = MAX_LIGHT_METER
var lives: int = 3:
	set = _set_lives
var run_started := false
var in_cave := false
var fainting := false
var faint_loss_fration := 0.25

func _ready():
	game_ended.connect(_on_game_ended)
	game_started.connect(_on_game_start)

func _process(delta: float) -> void:
	if not run_started or not in_cave:
		return
	if light_meter > 0.0:
		_set_light_meter(light_meter - DRAIN_PER_SECOND * delta)

func _set_light_meter(value: float) -> void:
	light_meter = clamp(value, 0.0, MAX_LIGHT_METER)
	light_meter_changed.emit(light_meter, MAX_LIGHT_METER)
	if light_meter <= 0.0 and in_cave and not fainting:
		faint()

func faint() -> void:
	if fainting:
		return
	fainting = true
	in_cave = false
	
	await get_tree().create_timer(1.2).timeout
	
	var lost := Inventory.lose_fraction(faint_loss_fration)
	WorldState.night += 1
	light_meter = MAX_LIGHT_METER
	light_meter_changed.emit(light_meter, MAX_LIGHT_METER)
	fainted.emit(lost)
	
	SaveGame.save()
	await SceneManager.go_to("res://Scenes/nest.tscn")
	fainting = false

func collect_star(data: ItemData) -> void:
	Inventory.add(data.id, 1)
	_set_light_meter(light_meter + data.light_refill)
	star_collected.emit()

#func setup_timer(time_limit: int):
	#if timer != null:
		#return
	#timer = Timer.new()
	#timer.one_shot = true
	#timer.timeout.connect(_on_timer_timeout)
	#add_child(timer)
	#timer.start(time_limit)
	#timer.paused = true
	#timer_added.emit()
#
#func _on_timer_timeout():
	#game_ended.emit(Endings.LOSE)

func _set_lives(value):
	if value  < 0:
		return
	lives = value
	lives_changed.emit()
	if lives <= 0:
		game_ended.emit(Endings.LOSE)

func _on_game_ended(_endings: Endings):
	#if timer and not timer.is_stopped():
		#timer.paused = true
	pass

func _on_game_start():
	run_started = true
	#if timer != null:
		#timer.paused = false
