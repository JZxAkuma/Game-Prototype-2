extends Resource
class_name Mission

enum Type { OBJECT, PHENOMENON, CREATURE }
enum State {
	AVAILABLE,   # shows up in the island's list, player hasn't accepted it yet
	ACCEPTED,    # player took it, objective should spawn in its sector
	COMPLETED,   # player has the matching photo, ready to turn in
	SUBMITTED    # turned in at the island, done
}

@export var mission_name: String = ""
@export var description: String = ""
@export var type: Type = Type.CREATURE
@export var sector_name: String = ""        # must match SectorButton.sector_name
@export var objective_scene: PackedScene    # what gets spawned (creature/object)
@export var objective_id: String = "0000"       # unique tag, checked against photo captures
@export var appear_time: float = -1.0       # only used for creatures, -1 = always present
@export var giver_island: String = ""   # must match the island's island_name
var state: State = State.AVAILABLE
