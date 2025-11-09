extends Node3D

@export var patrol_points: Array[NodePath] = []
@export var speed: float = 10.0
@export var rotation_speed: float = 3.0
@export var detection_range: float = 25.0
@export var detection_angle: float = 45.0
@export var search_duration: float = 3.0

var player: Node3D = null
var raycast: RayCast3D = null
var current_target_index: int = 0
var player_caught: bool = false
var searching: bool = false
var search_timer: float = 0.0

func _ready() -> void:
	print("🚁 Helicopter ready.")
	raycast = $SearchLightPivot/SearchLight/RayCast3D
	player = get_tree().get_first_node_in_group("player")

	# Godot 4.5+ replaces pause_mode with process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS

	if patrol_points.is_empty():
		push_warning("No patrol points assigned for Helicopter.")
	elif patrol_points.size() > 0:
		global_position = get_node(patrol_points[current_target_index]).global_position

func _physics_process(delta: float) -> void:
	if player_caught:
		return

	if patrol_points.is_empty():
		return
	
	if searching:
		search_timer -= delta
		if search_timer <= 0.0:
			searching = false
		return

	_move_between_points(delta)
	_detect_player()

func _move_between_points(delta: float) -> void:
	var target_node: Node3D = get_node(patrol_points[current_target_index])
	var target_position: Vector3 = target_node.global_position
	var direction: Vector3 = (target_position - global_position).normalized()
	
	# Move toward the next patrol point
	global_position += direction * speed * delta

	# Smooth rotation toward movement direction (use static Basis.looking_at)
	var target_basis := Basis.looking_at(direction, Vector3.UP)
	var facing_offset := Basis(Vector3.UP, deg_to_rad(180))
	target_basis *= facing_offset

	var roll_offset := Basis(Vector3.FORWARD, deg_to_rad(-90))
	target_basis *= roll_offset

	global_transform.basis = global_transform.basis.slerp(target_basis, rotation_speed * delta)

	# If close to point, switch to next one
	if global_position.distance_to(target_position) < 1.0:
		current_target_index = (current_target_index + 1) % patrol_points.size()
		searching = true
		search_timer = search_duration
		print("🔄 Next patrol point:", current_target_index)

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
		# RayCast3D.target_position is in LOCAL space
		if is_instance_valid(raycast):
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
