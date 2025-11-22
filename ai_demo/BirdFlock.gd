extends Node3D

@onready var bird := $Birds.get_child(0)

func _ready() -> void:
	print("BirdFlock is ready! Bird = ", bird)
