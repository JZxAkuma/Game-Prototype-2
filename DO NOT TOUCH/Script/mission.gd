extends Resource
class_name Mission

enum Type { STATIC, CREATURE }
enum State { AVAILABLE, ACCEPTED, COMPLETED, SUBMITTED }

@export var mission_name: String = ""
@export var description: String = ""
@export var type: Type = Type.CREATURE
@export var sector_name: String = ""
@export var giver_island: String = ""
@export var objective_scene: PackedScene    
@export var objective_id: String = ""
@export var appear_time: float = -1.0      
var state: State = State.AVAILABLE
