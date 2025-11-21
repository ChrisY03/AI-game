extends Node3D

# --- Idle circle flight ---
@export var orbit_radius: float = 4.0      # size of the circle
@export var orbit_height: float = 3.0      # height above the BirdFlock root
@export var orbit_speed: float = 1.5       # how fast the flock circles

# --- Flee behaviour (when player steps into trigger) ---
@export var flee_height: float = 14.0
@export var flee_distance: float = 30.0
@export var flee_duration: float = 3.0

# --- Noise sent to guards via Blackboard ---
@export var noise_radius: float = 8.0      # how "big" the noise is
@export var noise_ttl: float = 4.0         # how long the alert lives (seconds)

var birds: Node3D = null
var trigger_area: Area3D = null
var player: Node3D = null

var _state: String = "idle"
var _flee_time: float = 0.0
var _flee_target: Vector3 = Vector3.ZERO

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()

	# Find child nodes
	birds = get_node_or_null("Birds") as Node3D
	if birds == null:
		push_warning("BirdFlock: no 'Birds' child found.")
	else:
		# Make sure the birds start at the desired height
		var p: Vector3 = birds.position
		p.y = orbit_height
		birds.position = p

	trigger_area = get_node_or_null("TriggerArea") as Area3D
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)
	else:
		push_warning("BirdFlock: no 'TriggerArea' child found.")

	# Optional: configure cylinder radius to roughly match orbit
	if trigger_area:
		var shape: CollisionShape3D = trigger_area.get_node_or_null("Collision") as CollisionShape3D
		if shape and shape.shape is CylinderShape3D:
			var cyl: CylinderShape3D = shape.shape as CylinderShape3D
			cyl.radius = orbit_radius + 1.0
			cyl.height = 2.0

	player = get_tree().get_first_node_in_group("player") as Node3D


func _physics_process(delta: float) -> void:
	if birds == null:
		return

	match _state:
		"idle":
			_update_idle_orbit()
		"flee":
			_update_flee(delta)


# -----------------------
# Idle circle flight
# -----------------------
func _update_idle_orbit() -> void:
	# Use time to move birds in a circle around the BirdFlock root
	var t: float = float(Time.get_ticks_msec()) / 1000.0 * orbit_speed
	birds.position.x = cos(t) * orbit_radius
	birds.position.z = sin(t) * orbit_radius
	# Keep height fixed
	birds.position.y = orbit_height


# -----------------------
# Flee behaviour
# -----------------------
func _start_flee() -> void:
	if birds == null:
		return

	_state = "flee"
	_flee_time = 0.0

	# Pick a random horizontal direction
	var dir: Vector3 = Vector3(
		rng.randf_range(-1.0, 1.0),
		0.0,
		rng.randf_range(-1.0, 1.0)
	)
	if dir.length() < 0.001:
		dir = Vector3(1.0, 0.0, 0.0)
	dir = dir.normalized()

	# Target is some distance away and higher in the sky
	_flee_target = Vector3(
		dir.x * flee_distance,
		flee_height,
		dir.z * flee_distance
	)


func _update_flee(delta: float) -> void:
	_flee_time += delta
	var t: float = clamp(_flee_time / flee_duration, 0.0, 1.0)

	# Move smoothly from current position to flee target
	birds.position = birds.position.lerp(_flee_target, t)

	if t >= 1.0:
		# Stay up there; you could switch back to idle if you want
		_state = "idle"


# -----------------------
# Trigger callback
# -----------------------
func _on_trigger_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	print("🕊️ Bird flock scared by player at:", body.global_position)

	_start_flee()

	# Write a noise alert to the Blackboard for guards to react to
	if Engine.has_singleton("Blackboard"):
		Blackboard.add_noise(body.global_position, noise_radius, noise_ttl)
