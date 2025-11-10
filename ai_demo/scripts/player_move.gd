extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
@export var noise_radius_walk := 5.0 ### Lochlan
@export var noise_radius_run := 10.0
@export var noise_ttl := 2.0

var is_running := false


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_make_noise(noise_radius_run) #  jump noise

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		var speed := SPEED * (1.5 if is_running else 1.0)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		# make noise depending on how fast youre moving
		if is_on_floor():
			if is_running:
				_make_noise(noise_radius_run)
			else:
				_make_noise(noise_radius_walk)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
func _process(delta: float) -> void:
	Blackboard.tick(delta)
	
func _make_noise(radius: float) -> void:
	Blackboard.add_noise(global_transform.origin, radius, noise_ttl)

func _ready():
	if not is_in_group("player"):
		add_to_group("player")
	print("Player added to group:", get_groups())
