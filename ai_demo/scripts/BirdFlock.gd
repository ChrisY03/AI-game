extends Node3D

@export var orbit_radius: float = 4.0
@export var orbit_speed: float = 0.8
@export var height: float = 2.0

var center: Vector3
var angle: float = 0.0
var bird: Node3D     # single bird model

func _ready() -> void:
	# Get the bird node
	var birds_node: Node = get_node("Birds")
	if birds_node == null:
		push_error("BirdFlock ERROR: Could not find 'Birds' node!")
		return
	
	# Use first (and only) child
	bird = birds_node.get_child(0)
	if bird == null:
		push_error("BirdFlock ERROR: Birds has no children!")
		return
	
	# Center of the idle orbit (the origin of the BirdFlock node)
	center = global_position
	
	# Offset bird upward so it doesn't clip terrain
	bird.global_position = center + Vector3(0, height, orbit_radius)


func _physics_process(delta: float) -> void:
	if bird == null:
		return

	angle += orbit_speed * delta

	# Calculate circular orbit
	var x = center.x + orbit_radius * cos(angle)
	var z = center.z + orbit_radius * sin(angle)
	var y = center.y + height

	bird.global_position = Vector3(x, y, z)

	# face forward direction of orbit
	bird.look_at(Vector3(center.x, y, center.z))
