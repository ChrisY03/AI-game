extends Node3D

@export var move_speed: float = 6.0
@export var turn_speed: float = 2.0
@export var detection_range: float = 30.0
@export var light_rotation_speed: float = 1.5

@onready var spotlight: SpotLight3D = $SearchLightPivot/SearchLight
@onready var light_pivot: Node3D = $SearchLightPivot
@onready var raycast: RayCast3D = $SearchLightPivot/SearchLight/RayCast3D

var patrol_points: Array[Vector3] = []
var current_point := 0
var player: Node3D
var sweep_angle := 0.0

func _ready():
	# Collect all waypoint markers (named WP1, WP2, etc.)
	for child in get_children():
		if child is Marker3D and child.name.begins_with("WP"):
			patrol_points.append(child.global_position)

	if patrol_points.is_empty():
		print("No patrol points found.")
	else:
		global_position = patrol_points[0]
		print("Loaded patrol points:", patrol_points.size())

	# Spotlight setup
	spotlight.light_energy = 2.0
	spotlight.spot_range = detection_range
	raycast.target_position = Vector3(0, 0, -detection_range)
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if patrol_points.is_empty():
		return

	_move_between_points(delta)
	_scan_for_player(delta) # <- this must be inside _physics_process, at this indentation level

func _move_between_points(delta):
	if patrol_points.is_empty():
		return

	# Ensure index is valid
	current_point = clamp(current_point, 0, patrol_points.size() - 1)
	var target = patrol_points[current_point]

	# Calculate direction horizontally
	var direction = target - global_position
	direction.y = 0
	var distance = direction.length()

	# Check if close enough to advance
	if distance < 1.5:
		current_point = (current_point + 1) % patrol_points.size()
		print("➡️ Switching to waypoint:", current_point)
		return  # Exit early this frame so we re-evaluate cleanly next time

	# Maintain constant altitude
	var desired_height := 20.0
	global_position.y = lerpf(global_position.y, desired_height, delta * 2.0)

	# Move toward target if there's distance left
	if distance > 0.05:
		var move_dir = direction.normalized()
		global_position += move_dir * move_speed * delta

		# Rotate smoothly toward movement direction (keep upright)
		var up = Vector3.UP
		var look_target = global_position + move_dir
		var target_basis = Basis().looking_at(look_target, up)
		global_transform.basis = global_transform.basis.slerp(target_basis, delta * turn_speed)


# --- Light Sweep and Player Detection ---
func _scan_for_player(delta):
	if not player or not is_instance_valid(player):
		return

	# Sweep light back and forth
	sweep_angle += delta * light_rotation_speed
	var x = sin(sweep_angle)
	var z = cos(sweep_angle)
	var look_dir = Vector3(x, -0.3, z).normalized()

	# Rotate spotlight pivot smoothly
	var desired_basis = Basis().looking_at(look_dir, Vector3.UP)
	light_pivot.global_transform.basis = light_pivot.global_transform.basis.slerp(desired_basis, delta * 3.0)

	# Check if raycast detects player
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var hit = raycast.get_collider()
		if hit and hit.is_in_group("player"):
			spotlight.light_energy = 5.0
			print("Player spotted!")
		else:
			spotlight.light_energy = 2.0
	else:
		spotlight.light_energy = 2.0
