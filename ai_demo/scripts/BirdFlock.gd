extends Node3D

@export var orbit_radius: float = 4.0
@export var orbit_speed: float = 0.8
@export var height: float = 2.0

var center: Vector3
var angle: float = 0.0
var bird: Node3D

func _ready() -> void:
	var birds_node: Node = get_node("Birds")
	if birds_node == null:
		push_error("BirdFlock ERROR: Could not find 'Birds' node!")
		return

	bird = birds_node.get_child(0)
	if bird == null:
		push_error("BirdFlock ERROR: Birds has no children!")
		return

	center = global_position
	bird.global_position = center + Vector3(0, height, orbit_radius)

func _physics_process(delta: float) -> void:
	if bird == null:
		return

	angle += orbit_speed * delta

	var x := center.x + orbit_radius * cos(angle)
	var z := center.z + orbit_radius * sin(angle)
	var y := center.y + height

	bird.global_position = Vector3(x, y, z)

	# Face forward along orbit path
	var forward_offset := angle + 0.1
	var fx := center.x + orbit_radius * cos(forward_offset)
	var fz := center.z + orbit_radius * sin(forward_offset)

	bird.look_at(Vector3(fx, y, fz), Vector3.UP)
