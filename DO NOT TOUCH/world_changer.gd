extends Node

var world_container: Node = null
var current_scene: Node = null

func register_container(container: Node) -> void:
	world_container = container
	if container.get_child_count() > 0:
		current_scene = container.get_child(0)

func goto_scene(path: String) -> void:
	call_deferred("_deferred_goto_scene", path)

func _deferred_goto_scene(path: String) -> void:
	if current_scene:
		current_scene.queue_free()
		await get_tree().process_frame
	var next_scene = load(path).instantiate()
	world_container.add_child(next_scene)
	current_scene = next_scene
