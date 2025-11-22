extends Node3D

@export var orbit_radius: float = 4.0
@export var orbit_speed: float = 0.8
@export var height: float = 2.0

var center: Vector3
var angle: float = 0.0
var bird: Node3D

@onready var birds_node: Node = $Birds


func _ready() -> void:
	if birds_node == null:
		push_error("BirdFlock ERROR: Missing 'Birds' node!")
		return

	# get the first child (your model)
	bird = birds_node.get_child(0)
	if bird == null:
		push_error("BirdFlock ERROR: 'Birds' has no children!")
		return

	# set the orbit center
	center = global_position

	# place the bird initially
	bird.global_position = center + Vector3(0, height, orbit_radius)


func _physics_process(delta: float) -> void:
	if bird == null:
		return

	angle += orbit_speed * delta

	# orbit position
	var x := center.x + orbit_radius * cos(angle)
	var z := center.z + orbit_radius * sin(angle)
	var y := center.y + height

	bird.global_position = Vector3(x, y, z)

	# forward-facing direction
	var forward_offset := angle + 0.1
	var fx := center.x + orbit_radius * cos(forward_offset)
	var fz := center.z + orbit_radius * sin(forward_offset)

	bird.look_at(Vector3(fx, y, fz), Vector3.UP)
