extends Node3D

signal player_spotted(player_position: Vector3)

# --- Movement settings ---
@export var speed: float = 10.0
@export var rotation_speed: float = 3.0

@export var use_random_patrol: bool = true
@export var patrol_points: Array[NodePath] = []

# Random roam bounds (XZ) + height
@export var min_x: float = -50.0
@export var max_x: float =  50.0
@export var min_z: float = -50.0
@export var max_z: float =  50.0
@export var flight_height: float = 40.0

# Vision / detection
@export var detection_range: float = 40.0
@export var detection_angle: float = 45.0

var current_target_index: int = 0
var random_target: Vector3 = Vector3.ZERO
var rng := RandomNumberGenerator.new()

var debug_timer: float = 0.0
var raycast: RayCast3D = null
var player: Node3D = null


func _ready() -> void:
	set_physics_process(true)
	rng.randomize()

	player = get_tree().get_first_node_in_group("player") as Node3D

	# find your existing RayCast3D
	var rc := get_node_or_null("SearchLightPi/SearchLight/RayCast3D")
	if rc is RayCast3D:
		raycast = rc as RayCast3D
		raycast.enabled = true
	else:
		push_warning("RayCast3D not found at 'SearchLightPi/SearchLight/RayCast3D' – detection will be disabled.")

	# initial target
	if use_random_patrol:
		_pick_new_random_target()
	elif patrol_points.size() > 0:
		current_target_index = 0

	print("🚁 Helicopter ready. use_random_patrol =", use_random_patrol, " patrol_points =", patrol_points.size())


func _physics_process(delta: float) -> void:
	debug_timer += delta
	if debug_timer >= 2.0:
		debug_timer = 0.0
		var mode_name := "random" if use_random_patrol else "waypoints"
		print("⏱ heli tick – mode:", mode_name, " index:", current_target_index)

	if use_random_patrol:
		_move_random(delta)
	else:
		_move_waypoints(delta)

	_detect_player()


# ------------------------
# RANDOM ROAM MOVEMENT
# ------------------------
func _pick_new_random_target() -> void:
	var x := rng.randf_range(min_x, max_x)
	var z := rng.randf_range(min_z, max_z)
	random_target = Vector3(x, flight_height, z)
	print("🎯 New random target:", random_target)


func _move_random(delta: float) -> void:
	var to_target := random_target - global_position
	var distance := to_target.length()

	if distance > 0.2:
		var dir := to_target / distance
		global_position += dir * speed * delta

		var flat_dir := Vector3(dir.x, 0.0, dir.z)
		if flat_dir.length() > 0.001:
			var target_yaw := atan2(flat_dir.x, flat_dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)
	else:
		_pick_new_random_target()


# ------------------------
# WAYPOINT MOVEMENT
# ------------------------
func _move_waypoints(delta: float) -> void:
	if patrol_points.is_empty():
		return

	var target_node := get_node_or_null(patrol_points[current_target_index])
	if target_node == null or not (target_node is Node3D):
		print("⚠️ Patrol point", current_target_index, "is invalid.")
		return

	var target_pos: Vector3 = (target_node as Node3D).global_position
	var to_target := target_pos - global_position
	var distance := to_target.length()

	if distance > 0.2:
		var dir := to_target / distance
		global_position += dir * speed * delta

		var flat_dir := Vector3(dir.x, 0.0, dir.z)
		if flat_dir.length() > 0.001:
			var target_yaw := atan2(flat_dir.x, flat_dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)
	else:
		current_target_index = (current_target_index + 1) % patrol_points.size()
		print("🔄 Next patrol point:", current_target_index)


# ------------------------
# RAYCAST-BASED DETECTION
# ------------------------
func _detect_player() -> void:
	if raycast == null:
		return
	if not is_instance_valid(player):
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance > detection_range:
		return

	# angle between helicopter forward and player
	var heli_forward := -global_transform.basis.z
	var angle := rad_to_deg(acos(clamp(heli_forward.normalized().dot(to_player.normalized()), -1.0, 1.0)))
	if angle > detection_angle:
		return

	# aim the raycast at the player (local space)
	raycast.target_position = raycast.to_local(player.global_position)
	raycast.force_raycast_update()

	if raycast.is_colliding() and raycast.get_collider() == player:
		var pos := player.global_position
		print("🚨 Helicopter searchlight hit player at:", pos)
		emit_signal("player_spotted", pos)
		_notify_guards(pos)


func _notify_guards(player_pos: Vector3) -> void:
	for guard in get_tree().get_nodes_in_group("guards"):
		if guard.has_method("on_player_spotted"):
			guard.on_player_spotted(player_pos)
