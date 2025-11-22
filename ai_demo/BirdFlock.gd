extends Node3D

@export var orbit_radius: float = 4.0
@export var orbit_speed: float = 1.0
@export var height: float = 2.0

var angle: float = 0.0
var center: Vector3
var bird: Node3D

func _ready() -> void:
	# Store where the flock is placed in the world
	center = global_position

	# Find the bird model (first child of Birds node)
	var birds_node = get_node_or_null("Birds")
	if birds_node == null:
		push_error("BirdFlock ERROR: 'Birds' node missing!")
		return

	bird = birds_node.get_child(0)

	# Place bird at starting position
	bird.global_position = center + Vector3(orbit_radius, height, 0)


func _physics_process(delta: float) -> void:
	if bird == null:
		return

	angle += orbit_speed * delta

	# Compute circular orbit
	var x = center.x + orbit_radius * cos(angle)
	var z = center.z + orbit_radius * sin(angle)
	var y = center.y + height

	bird.global_position = Vector3(x, y, z)

	# Make bird face forward along movement path
	var forward_x = center.x + orbit_radius * cos(angle + 0.1)
	var forward_z = center.z + orbit_radius * sin(angle + 0.1)

	bird.look_at(Vector3(forward_x, y, forward_z), Vector3.UP)
