extends Node

@export var songs: Array[AudioStream] = []
@export var shuffle: bool = true
@export var fade_time: float = 1.0
@export var volume_db: float = 0.0

@onready var player: AudioStreamPlayer = $Player

var queue: Array[int] = []
var current_index: int = -1
var running: bool = false
var paused: bool = false
var fade_tween: Tween


func _ready() -> void:
	player.finished.connect(_on_song_finished)


func start() -> void:
	if paused:
		resume()
		return
	if songs.is_empty() or running:
		return
	running = true
	_play_next()


func stop() -> void:
	if not running:
		return
	running = false
	if fade_tween:
		fade_tween.kill()

	if paused:
		paused = false
		player.stream_paused = false
		player.stop()
		return

	fade_tween = create_tween()
	fade_tween.tween_property(player, "volume_db", -80.0, fade_time)
	fade_tween.tween_callback(player.stop)


func pause() -> void:
	if not running or paused:
		return
	paused = true
	if fade_tween:
		fade_tween.kill()
	player.stream_paused = true


func resume() -> void:
	if not paused:
		return
	paused = false
	player.stream_paused = false
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(player, "volume_db", volume_db, fade_time)


func next_song() -> void:
	if running and not paused:
		_play_next()


func _play_next() -> void:
	current_index = _pick_next_index()
	player.stream = songs[current_index]
	player.volume_db = -80.0
	player.play()

	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(player, "volume_db", volume_db, fade_time)


func _pick_next_index() -> int:
	if not shuffle:
		return (current_index + 1) % songs.size()

	if queue.is_empty():
		_refill_queue()
	return queue.pop_front()


func _refill_queue() -> void:
	queue.clear()
	for i in songs.size():
		queue.append(i)
	queue.shuffle()
	if queue.size() > 1 and queue[0] == current_index:
		queue.push_back(queue.pop_front())


func _on_song_finished() -> void:
	if running and not paused:
		_play_next()
