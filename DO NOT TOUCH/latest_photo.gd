extends SubViewport


@onready var latest_photo_display: TextureRect = $TextureRect

func _ready() -> void:
	_load_latest_photo()


func _load_latest_photo() -> void:
	var manifest = PhotoManager.get_all_photos()

	if manifest.is_empty():
		return   

	var latest_entry = manifest[manifest.size() - 1]
	var full_path = PhotoManager.PHOTOS_DIR + "/" + latest_entry["filename"]

	if not FileAccess.file_exists(full_path):
		return   

	var img = Image.load_from_file(full_path)
	var tex = ImageTexture.create_from_image(img)
	latest_photo_display.texture = tex
