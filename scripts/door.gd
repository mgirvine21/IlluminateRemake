class_name Door
extends Interactable

@export_file("*.tscn") var target_scene: String

func interact(_p: Player) -> void:
	if not target_scene.is_empty():
		SceneManager.go_to(target_scene)
