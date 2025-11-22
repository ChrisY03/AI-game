extends Node3D

# --- Idle orbit settings ---
@export var orbit_radius: float = 4.0
@export var orbit_speed: float = 0.8
@export var height: float = 2.0

# Internal state
var center: Vector3
var angle: float = 0.0
var bird: Node3D

func _ready() -> void:
	# Find the Birds node
	var birds_node: Node = get_node("Birds")
	if birds_node == null:
		push_error("BirdFlock ERROR: Could not find 'Birds' node!")
		return

	# Use first (and only) child mesh/model
	bird = birds_node.get_child(0)
	if bird == null:
		push_error("BirdFlock ERROR: Birds has no children!")
		return

	# Center of flock orbit
	center = global_position

	# Start bird at offset position
	bird.global_position = center + Vector3(0, height, orbit_radius)


func _physics_process(delta: float) -> void:
	if bird == null:
		return

	# Advance angle
	angle += orbit_speed * delta

	# Compute orbit path
	var x = center.x + orbit_radius * cos(angle)
	var z = center.z + orbit_radius * sin(angle)
	var y = center.y + height

	# Update bird position
	bird.global_position = Vector3(x, y, z)

	# Rotate bird to face movement direction
	var forward_pos = Vector3(
		center.x + orbit_radius * cos(angle + 0.1),
		y,
		center.z + orbit_radius * sin(angle + 0.1)
	)
	bird.look_at(forward_pos, Vector3.UP)


# ----------------------------------------------------
# STEP 2 — Player detection using TriggerArea
# ----------------------------------------------------
func _on_trigger_area_body_entered(body: Node3D) -> void:
	# Adjust name if your player node is named differently
	if body.name == "Player":
		print("✅ Player detected by birds!")
