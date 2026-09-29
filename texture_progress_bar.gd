extends TextureProgressBar


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	max_value = Global.MAX_LIGHT_METER
	value = Global.light_meter
	Global.light_meter_changed.connect(_on_light_meter_changed)

func _on_light_meter_changed(new_value: float, new_max: float) -> void:
	max_value = new_max
	value = new_value
