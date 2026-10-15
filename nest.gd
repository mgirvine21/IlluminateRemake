extends Interactable

@export_file("*.tscn") var target_scene: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	prompt = "Sleep"
	super._ready()


func interact(_p: Player) -> void:
	WorldState.night += 1
	Global.light_meter = Global.MAX_LIGHT_METER
	SaveGame.save()
	SceneManager.go_to(target_scene)
