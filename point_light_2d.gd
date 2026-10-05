extends PointLight2D

@export var max_light: float = 2.0
@export var min_light: float =  0.2
@export_range(0.0, 1.0) var full_threshold: float = 0.75

func _ready() -> void:
	Global.light_meter_changed.connect(_on_light_meter_changed)
	_on_light_meter_changed(Global.light_meter, Global.max_light_meter)
	
func _on_light_meter_changed(value: float, max_value: float) -> void:
	var ratio := clampf(value / max_value, 0.0, 1.0)
	
	var t := clampf(ratio / full_threshold, 0.0, 1.0)
	texture_scale = lerpf(min_light, max_light, t)
	
func update() -> void:
	pass
	#update_light_meter()


func _on_timer_timeout() -> void:
	pass # Replace with function body.
