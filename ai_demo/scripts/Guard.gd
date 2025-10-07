extends CharacterBody3D

enum State { PATROL }

@export var move_speed := 4.5
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var label: Label3D = $Label3D

var patrol_points: Array[Vector3] = []
var idx := 0

func _ready() -> void:
	# Gather waypoint positions from child Markers named WP*
	for c in get_children():
		if c is Marker3D and c.name.begins_with("WP"):
			patrol_points.append(c.global_transform.origin)
	if patrol_points.is_empty():
		push_warning("Guard has no WP markers; generating a small square near origin.")
		var o = global_transform.origin
		patrol_points = [o + Vector3(6,0,0), o + Vector3(6,0,6), o + Vector3(0,0,6), o]

	agent.max_speed = move_speed
	agent.path_max_distance = 2.0
	agent.target_position = patrol_points[0]
	label.text = "PATROL"

func _physics_process(delta: float) -> void:
	# If we’ve reached the current target, move to next
	if agent.is_navigation_finished():
		idx = (idx + 1) % patrol_points.size()
		agent.target_position = patrol_points[idx]

	# Move toward the next path position
	var next_pos = agent.get_next_path_position()
	var to_next = next_pos - global_transform.origin
	if to_next.length() > 0.05:
		var dir = to_next.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	else:
		velocity.x = lerpf(velocity.x, 0.0, 0.2)
		velocity.z = lerpf(velocity.z, 0.0, 0.2)

	velocity.y = 0.0
	move_and_slide()
	
