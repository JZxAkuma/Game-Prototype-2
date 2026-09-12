extends Node

const PHOTOS_DIR = "user://photos"
const MANIFEST_PATH = "user://photos/manifest.json"

var manifest: Array = []


func _ready() -> void:
	_load_manifest()
	_prune_missing_files()


func save_photo(image: Image, objective_id: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(PHOTOS_DIR):
		DirAccess.make_dir_absolute(PHOTOS_DIR)

	var filename = "photo_%d.png" % Time.get_unix_time_from_system()
	var full_path = PHOTOS_DIR + "/" + filename
	image.save_png(full_path)

	var entry = {
		"filename": filename,
		"objective_id": objective_id,
		"timestamp": Time.get_unix_time_from_system()
	}
	manifest.append(entry)
	_save_manifest()

	return entry


func get_all_photos() -> Array:
	return manifest


func has_photo_for_objective(objective_id: String) -> bool:
	for entry in manifest:
		if entry["objective_id"] == objective_id:
			return true
	return false


func delete_photo(filename: String) -> void:
	var full_path = PHOTOS_DIR + "/" + filename
	if FileAccess.file_exists(full_path):
		DirAccess.remove_absolute(full_path)

	for i in range(manifest.size() - 1, -1, -1):
		if manifest[i]["filename"] == filename:
			manifest.remove_at(i)

	_save_manifest()


func _save_manifest() -> void:
	var file = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()


func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		manifest = []
		return
	var file = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	manifest = parsed if parsed is Array else []

func _prune_missing_files() -> void:
	var changed = false
	for i in range(manifest.size() - 1, -1, -1):
		var full_path = PHOTOS_DIR + "/" + manifest[i]["filename"]
		if not FileAccess.file_exists(full_path):
			manifest.remove_at(i)
			changed = true

	if changed:
		_save_manifest()
