extends Node3D

# --------- EXPORTS ---------
@export var orbit_radius: float = 4.0
@export var orbit_speed: float = 1.2
@export var orbit_height: float = 1.5

@export var auto_snap_to_ground: bool = true
@export var terrain_offset: float = 0.3

@export var flee_height: float = 6.0
@export var flee_distance: float = 12.0
@export var flee_speed: float = 6.0
@export var flee_duration: float = 3.0

# --------- INTERNAL STATE ---------
var birds: Array[Node3D] = []
var bird_angles: Array[float] = []

var fleeing: bool = false
var flee_timer: float = 0.0
var flee_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Collect birds
	var birds_node := get_node("Birds") as Node3D
	birds = []
	for child in birds_node.get_children():
		if child is Node3D:
			birds.append(child as Node3D)

	# Assign random orbit start angles
	bird_angles.resize(birds.size())
	for i in birds.size():
		bird_angles[i] = randf() * TAU

	# Connect trigger area
	var area := get_node("TriggerArea") as Area3D
	area.body_entered.connect(_on_player_enter)

	# Snap flock to terrain height
	if auto_snap_to_ground:
		_snap_to_ground()


func _physics_process(delta: float) -> void:
	if fleeing:
		_update_flee(delta)
	else:
		_update_idle_orbit(delta)


# ----------------------------------------------------------
# IDLE ORBIT — Birds fly in a circle
# ----------------------------------------------------------

func _update_idle_orbit(delta: float) -> void:
	var center: Vector3 = global_position

	for i in birds.size():
		bird_angles[i] += orbit_speed * delta

		var angle: float = bird_angles[i]
		var x: float = sin(angle) * orbit_radius
		var z: float = cos(angle) * orbit_radius

		var target_pos: Vector3 = center + Vector3(x, orbit_height, z)
		birds[i].global_position = target_pos

		# Face direction of travel
		var forward: Vector3 = Vector3(sin(angle), 0.0, cos(angle))
		birds[i].look_at(target_pos + forward * 2.0, Vector3.UP)


# ----------------------------------------------------------
# FLEE BEHAVIOR
# ----------------------------------------------------------

func _on_player_enter(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	print("🕊 Birds startled! Fleeing!")
	fleeing = true
	flee_timer = flee_duration

	# Pick a direction away from the flock
	var rand_dir: Vector3 = Vector3(randf() * 2.0 - 1.0, 0.0, randf() * 2.0 - 1.0).normalized()
	flee_target = global_position + rand_dir * flee_distance
	flee_target.y += flee_height


func _update_flee(delta: float) -> void:
	flee_timer -= delta
	if flee_timer <= 0.0:
		fleeing = false
		return

	for bird in birds:
		var to_target: Vector3 = flee_target - bird.global_position
		var dir: Vector3 = to_target.normalized()
		bird.global_position += dir * flee_speed * delta
		bird.look_at(bird.global_position + dir, Vector3.UP)


# ----------------------------------------------------------
# GROUND SNAP — places flock on terrain
# ----------------------------------------------------------

func _snap_to_ground() -> void:
	var space_state := get_world_3d().direct_space_state

	var from: Vector3 = global_position + Vector3(0, 50, 0)
	var to: Vector3 = global_position + Vector3(0, -200, 0)

	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = false
	params.collide_with_bodies = true

	var result: Dictionary = space_state.intersect_ray(params)

	if result.has("position"):
		var ground_pos: Vector3 = result["position"] as Vector3
		global_position.y = ground_pos.y + terrain_offset
	else:
		print("⚠ BirdFlock: Could not snap flock to ground.")
