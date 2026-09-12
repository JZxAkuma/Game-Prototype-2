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

var target_amount = 0

func _ready() -> void:
	time_of_day = start_hour

func _process(delta: float) -> void:
	#var rate = diving_hours_per_second if is_diving else overworld_hours_per_second
	#time_of_day += rate*delta
	#
	#if time_of_day >= 24.0:
		#time_of_day -= 24.0
		#day_count += 1
		#new_day.emit(day_count)
	#
	#time_changed.emit(time_of_day)
	
	if target_amount != 0:
		_time_passage(delta)
	
	
	
	pass

#func _unhandled_input(event: InputEvent) -> void:
	#if Input.is_action_just_pressed("Throttle up"):
		#_add_5_hours()
	#
func _time_passage(delta:float) -> void:
	var rate = overworld_hours_per_second
	#var start_time = time_of_day
	var target_time = fmod((time_of_day + target_amount), 24.0)
	
	if time_of_day != target_time:
		time_of_day += rate*delta
	
	else:
		target_amount = 0
	
	if time_of_day >= 24.0:
		time_of_day -= 24.0
		day_count += 1
		new_day.emit(day_count)
	
	time_changed.emit(time_of_day)
	
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

func _add_one_hour() -> void:
	target_amount = 1

func _add_5_hours() -> void:
	target_amount = 5

func _move_time() -> void:
	pass
