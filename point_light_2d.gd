extends PointLight2D

@export var max_light: float = 2.0
@export var min_light: float =  0.1
@export var light: PointLight2D

@onready var light_timer: Timer = $Timer

func update_light_meter(meter_value: float, max_meter_value: float) -> void:
	var ratio = clamp(meter_value / max_meter_value, 0.0, 1.0)
	
	light.texture_scale = lerp(min_light , max_light, ratio)
	
func update() -> void:
	
	#update_light_meter()


func _on_timer_timeout() -> void:
	pass # Replace with function body.
