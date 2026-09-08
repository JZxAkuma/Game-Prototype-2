extends Node3D

#
signal time_changed(hour:float)
signal new_day(day_count:int)

var start_hour = 8.0

var overworld_hours_per_second = 1.0/1.0

var diving_hours_per_second = 1.0/3600.0

var time_of_day = 0.0
var day_count = 0

var is_diving = false

func _ready() -> void:
	time_of_day = start_hour

#func _process(delta: float) -> void:
	#var rate = diving_hours_per_second if is_diving else overworld_hours_per_second
	#time_of_day += rate*delta
	#
	#if time_of_day >= 24.0:
		#time_of_day -= 24.0
		#day_count += 1
		#new_day.emit(day_count)
	#
	#time_changed.emit(time_of_day)

func _set_diving(diving:bool) -> void:
	is_diving = diving

func _get_hour() -> int:
	return int(time_of_day)

func _get_minute() -> int:
	return int((time_of_day-_get_hour()) * 60.0)

func _get_time_string() -> String:
	return "%02d:%02d" % [_get_hour(),_get_minute()]

func _is_night() -> bool:
	return time_of_day < 6.0 or time_of_day >= 20.0
