extends Node3D

@export var move_speed: float = 6.0
@export var turn_speed: float = 2.0
@export var detection_range: float = 40.0
@export var light_rotation_speed: float = 1.0
@export var light_sweep_angle_deg: float = 15.0     # narrower sweep
@export var waypoint_threshold: float = 2.0
@export var patrol_altitude: float = 20.0

@onready var spotlight: SpotLight3D = $SearchLightPivot/SearchLight
@onready var light_pivot: Node3D = $SearchLightPivot
@onready var raycast: RayCast3D = $SearchLightPivot/SearchLight/RayCast3D

var patrol_points: Array[Vector3] = []
var current_point := 0
var player: Node3D
var sweep_angle := 0.0


func _ready():
	# --- Collect patrol waypoints ---
	for child in get_children():
		if child is Marker3D and child.name.begins_with("WP"):
			patrol_points.append(child.global_position)

	if patrol_points.is_empty():
		push_warning("⚠️ No patrol points found for helicopter!")
		return
	else:
		global_position = patrol_points[0]
		print("🚁 Loaded", patrol_points.size(), "waypoints.")

	# --- Spotlight setup ---
	spotlight.visible = true
	spotlight.light_energy = 5.0                    # slightly dimmer
	spotlight.light_volumetric_fog_energy = 2.5     # balanced fog glow
	spotlight.spot_range = detection_range
	spotlight.spot_angle = 10.0                     # narrow cone = small circle
	spotlight.shadow_enabled = true
	spotlight.shadow_bias = 0.05
	spotlight.shadow_normal_bias = 0.4
	spotlight.light_color = Color(1.0, 0.97, 0.9)

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

	if distance < waypoint_threshold:
		current_point = (current_point + 1) % patrol_points.size()
		print("➡️ Switching to waypoint:", current_point)
		return

	global_position.y = lerpf(global_position.y, patrol_altitude, delta * 2.0)

	if distance > 0.05:
		var move_dir = direction.normalized()
		global_position += move_dir * move_speed * delta

		var up = Vector3.UP
		var look_target = global_position + move_dir
		var target_basis = Basis().looking_at(look_target, up)

		var facing_offset = Basis(Vector3.UP, deg_to_rad(180))
		target_basis = target_basis * facing_offset

		var roll_offset = Basis(Vector3.FORWARD, deg_to_rad(-90))
		target_basis = target_basis * roll_offset

		global_transform.basis = global_transform.basis.slerp(target_basis, delta * turn_speed)


func _scan_for_player(delta):
	if not is_instance_valid(raycast) or not is_instance_valid(spotlight):
		return
	if not player or not is_instance_valid(player):
		return

	# --- Subtle side-to-side sweep centered forward ---
	sweep_angle += delta * light_rotation_speed
	var sweep_limit = deg_to_rad(light_sweep_angle_deg)
	var horizontal_angle = sin(sweep_angle) * sweep_limit

	var base_forward = -global_transform.basis.z
	var rotation = Basis(Vector3.UP, horizontal_angle)
	var look_dir = (rotation * base_forward).normalized()

	# Tilt down more to keep beam near the ground center
	look_dir.y -= 0.7
	look_dir = look_dir.normalized()

	var desired_basis = Basis().looking_at(look_dir, Vector3.UP)
	light_pivot.global_transform.basis = light_pivot.global_transform.basis.slerp(desired_basis, delta * 3.0)

	# --- Gentle flicker for realism ---
	spotlight.light_volumetric_fog_energy = 2.5 + sin(Time.get_ticks_msec() * 0.004) * 0.15

	# --- Raycast player detection ---
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var hit = raycast.get_collider()
		if hit and hit.is_in_group("player"):
			spotlight.light_energy = 7.0
			print("🚨 Player spotted!")
		else:
			spotlight.light_energy = 5.0
	else:
		spotlight.light_energy = 5.0


func _exit_tree():
	print("🛑 Helicopter exiting scene, cleaning up...")
	if is_instance_valid(raycast):
		raycast.enabled = false
	raycast = null
	spotlight = null
	light_pivot = null
	player = null
