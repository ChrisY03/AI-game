extends Node3D

@export var patrol_points: Array[NodePath] = []
@export var speed: float = 10.0
@export var rotation_speed: float = 3.0
@export var detection_range: float = 25.0
@export var detection_angle: float = 45.0
@export var search_duration: float = 3.0

# Optional random wandering instead of fixed waypoints
@export var use_random_patrol: bool = false
@export var random_center: NodePath
@export var random_radius: float = 30.0

var player: Node3D = null
var raycast: RayCast3D = null

var current_target_index: int = 0
var player_caught: bool = false
var searching: bool = false
var search_timer: float = 0.0

var random_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	print("🚁 Helicopter ready.")
	
	raycast = $SearchLightPivot/SearchLight/RayCast3D
	player = get_tree().get_first_node_in_group("player")
	
	# Godot 4.5+ replaces pause_mode with process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if use_random_patrol:
		# Start wandering randomly
		_pick_new_random_target()
	else:
		# Waypoint mode
		if patrol_points.is_empty():
			push_warning("No patrol points assigned for Helicopter.")
		else:
			# Start at the first patrol point
			var first_point := get_node_or_null(patrol_points[0])
			if first_point and first_point is Node3D:
				global_position = first_point.global_position
			
			# Make the *next* point our first target so we move immediately
			if patrol_points.size() > 1:
				current_target_index = 1
			else:
				current_target_index = 0


func _physics_process(delta: float) -> void:
	if player_caught:
		return
	
	# No waypoints and not using random patrol -> nothing to do
	if not use_random_patrol and patrol_points.is_empty():
		return
	
	if searching:
		search_timer -= delta
		if search_timer <= 0.0:
			searching = false
		return
	
	_move_between_points(delta)
	_detect_player()


func _move_between_points(delta: float) -> void:
	var target_position: Vector3
	
	# Decide target based on mode
	if use_random_patrol:
		target_position = random_target
	else:
		var target_node: Node3D = get_node(patrol_points[current_target_index])
		target_position = target_node.global_position
	
	var to_target: Vector3 = target_position - global_position
	var distance: float = to_target.length()
	
	if distance > 0.001:
		var direction: Vector3 = to_target / distance
		
		# Move toward the target
		global_position += direction * speed * delta
		
		# Smooth rotation toward movement direction
		var target_basis := Basis.looking_at(direction, Vector3.UP)
		
		# Apply your facing/roll offsets
		var facing_offset := Basis(Vector3.UP, deg_to_rad(180.0))
		target_basis *= facing_offset
		
		var roll_offset := Basis(Vector3.FORWARD, deg_to_rad(-90.0))
		target_basis *= roll_offset
		
		global_transform.basis = global_transform.basis.slerp(target_basis, rotation_speed * delta)
	
	# If close to target, pick the next one and optionally "search"
	if distance < 1.0:
		if use_random_patrol:
			_pick_new_random_target()
		else:
			if patrol_points.size() > 0:
				current_target_index = (current_target_index + 1) % patrol_points.size()
				print("🔄 Next patrol point:", current_target_index)
		
		searching = true
		search_timer = search_duration
		print("🔍 Searching for", search_duration, "seconds")


func _pick_new_random_target() -> void:
	var center_pos: Vector3 = global_position
	
	if random_center != NodePath():
		var center_node := get_node_or_null(random_center)
		if center_node and center_node is Node3D:
			center_pos = center_node.global_position
	
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	var angle := rng.randf_range(0.0, TAU)
	var radius := rng.randf_range(0.0, random_radius)
	
	var offset := Vector3(
		cos(angle) * radius,
		0.0,
		sin(angle) * radius
	)
	
	random_target = center_pos + offset
	print("🎯 New random target:", random_target)


func _detect_player() -> void:
	if not is_instance_valid(player):
		return
	
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance > detection_range:
		return
	
	var forward := -global_transform.basis.z
	var angle := rad_to_deg(acos(clamp(forward.dot(to_player.normalized()), -1.0, 1.0)))
	if angle < detection_angle:
		if is_instance_valid(raycast):
			# RayCast3D.target_position is in LOCAL space
			raycast.target_position = raycast.to_local(player.global_position)
			raycast.force_raycast_update()
			if not raycast.is_colliding() or raycast.get_collider() == player:
				_on_player_detected()


func _on_player_detected() -> void:
	if player_caught:
		return
	
	player_caught = true
	print("🚨 Player detected by helicopter!")


func _exit_tree() -> void:
	print("❌ Helicopter exiting scene, cleaning up...")
	if is_instance_valid(raycast):
		raycast.enabled = false
	raycast = null
	player = null
