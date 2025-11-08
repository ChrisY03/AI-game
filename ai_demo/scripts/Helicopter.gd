extends Node3D

@export var move_speed: float = 6.0
@export var turn_speed: float = 2.0
@export var detection_range: float = 30.0
@export var light_rotation_speed: float = 1.5
@export var waypoint_threshold: float = 2.0  # distance to switch to next waypoint
@export var patrol_altitude: float = 20.0    # flight height

@onready var spotlight: SpotLight3D = $SearchLightPivot/SearchLight
@onready var light_pivot: Node3D = $SearchLightPivot
@onready var raycast: RayCast3D = $SearchLightPivot/SearchLight/RayCast3D

var patrol_points: Array[Vector3] = []
var current_point := 0
var player: Node3D
var sweep_angle := 0.0


func _ready():
	# Collect all waypoint markers (named WP1, WP2, WP3, etc.)
	for child in get_children():
		if child is Marker3D and child.name.begins_with("WP"):
			patrol_points.append(child.global_position)

	if patrol_points.is_empty():
		push_warning("No patrol points found in helicopter scene!")
		return
	else:
		global_position = patrol_points[0]
		print("🚁 Loaded", patrol_points.size(), "patrol points")

	# Setup spotlight and raycast
	spotlight.light_energy = 2.0
	spotlight.spot_range = detection_range
	raycast.target_position = Vector3(0, 0, -detection_range)

	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta):
	if patrol_points.is_empty():
		return

	_move_between_points(delta)
	_scan_for_player(delta)


func _move_between_points(delta):
	var target = patrol_points[current_point]
	var direction = target - global_position
	direction.y = 0
	var distance = direction.length()

	# --- Switch to next waypoint when close enough ---
	if distance < waypoint_threshold:
		current_point = (current_point + 1) % patrol_points.size()
		print("➡️ Switching to waypoint:", current_point)
		return

	# Maintain constant patrol height
	global_position.y = lerpf(global_position.y, patrol_altitude, delta * 2.0)

	# --- Move toward current target ---
	if distance > 0.05:
		var move_dir = direction.normalized()
		global_position += move_dir * move_speed * delta

		# --- Rotation logic (keeps tail horizontal + faces direction) ---
		var up = Vector3.UP
		var look_target = global_position + move_dir
		var target_basis = Basis().looking_at(look_target, up)

		# 1️⃣ Facing correction (adjust 90 / -90 / 180 if model direction differs)
		var facing_offset = Basis(Vector3.UP, deg_to_rad(90))
		target_basis = target_basis * facing_offset

		# 2️⃣ Roll correction (fix tail vertical issue)
		var roll_offset = Basis(Vector3.FORWARD, deg_to_rad(-90))
		target_basis = target_basis * roll_offset

		global_transform.basis = global_transform.basis.slerp(target_basis, delta * turn_speed)


# --- Light Sweep and Player Detection ---
func _scan_for_player(delta):
	if not player or not is_instance_valid(player):
		return

	# Sweep light back and forth to simulate searching
	sweep_angle += delta * light_rotation_speed
	var x = sin(sweep_angle)
	var z = cos(sweep_angle)
	var look_dir = Vector3(x, -0.3, z).normalized()

	# Rotate spotlight pivot smoothly
	var desired_basis = Basis().looking_at(look_dir, Vector3.UP)
	light_pivot.global_transform.basis = light_pivot.global_transform.basis.slerp(desired_basis, delta * 3.0)

	# Check for player detection
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var hit = raycast.get_collider()
		if hit and hit.is_in_group("player"):
			spotlight.light_energy = 5.0
			print("🚨 Player spotted!")
		else:
			spotlight.light_energy = 2.0
	else:
		spotlight.light_energy = 2.0
