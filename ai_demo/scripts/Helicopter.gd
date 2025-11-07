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
	for child in get_children():
		if child is Marker3D and child.name.begins_with("WP"):
			patrol_points.append(child.global_position)
	if patrol_points.is_empty():
		print("No patrol points found.")
	else:
		global_position = patrol_points[0]
		
		print("Loaded patrol points:", patrol_points.size())

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
	if direction.length() < 1.0:
		current_point = (current_point + 1) % patrol_points.size()
	else:
		var move = direction.normalized() * move_speed * delta
		global_position += move
		var target_basis = Basis().looking_at(direction.normalized(), Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(target_basis, delta * turn_speed)

func _scan_for_player(delta):
	if not player or not is_instance_valid(player):
		return

	sweep_angle += delta * light_rotation_speed
	var x = sin(sweep_angle)
	var z = cos(sweep_angle)
	var look_dir = Vector3(x, -0.3, z).normalized()
	var desired_basis = Basis().looking_at(look_dir, Vector3.UP)
	light_pivot.global_transform.basis = light_pivot.global_transform.basis.slerp(desired_basis, delta * 3.0)

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
