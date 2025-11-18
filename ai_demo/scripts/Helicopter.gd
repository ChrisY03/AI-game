extends Node3D

# --- Movement settings ---
@export var patrol_points: Array[NodePath] = []
@export var speed: float = 10.0
@export var rotation_speed: float = 3.0

# --- Random patrol settings ---
@export var use_random_patrol: bool = true      # ON by default so it won't just fly away
@export var random_center: NodePath             # optional center node
@export var random_radius: float = 40.0         # how far from center it can wander

var current_target_index: int = 0
var random_target: Vector3 = Vector3.ZERO
var center_pos: Vector3 = Vector3.ZERO
var debug_timer: float = 0.0


func _ready() -> void:
	set_physics_process(true)

	# Use current position as default center
	center_pos = global_position

	# If you assigned a center node in the Inspector, use that instead
	if random_center != NodePath():
		var c := get_node_or_null(random_center)
		if c is Node3D:
			center_pos = (c as Node3D).global_position

	print("🚁 Helicopter ready")
	print("  patrol_points.size =", patrol_points.size())
	print("  use_random_patrol =", use_random_patrol)

	# If random is OFF but there are no patrol points, turn random back on
	if not use_random_patrol and patrol_points.is_empty():
		push_warning("No patrol points set, enabling random patrol so heli stays nearby.")
		use_random_patrol = true

	if use_random_patrol:
		_pick_new_random_target()
	else:
		current_target_index = 0


func _physics_process(delta: float) -> void:
	# small heartbeat so we can see it's running
	debug_timer += delta
	if debug_timer >= 2.0:
		debug_timer = 0.0
		var mode_name := "random" if use_random_patrol else "patrol"
		print("⏱ heli tick – mode:", mode_name, " index:", current_target_index)

	if use_random_patrol:
		_move_to_position(random_target, delta, true)
	else:
		if patrol_points.is_empty():
			return

		var node := get_node_or_null(patrol_points[current_target_index])
		if node is Node3D:
			_move_to_position((node as Node3D).global_position, delta, false)
		else:
			print("⚠️ Patrol point", current_target_index, "is invalid.")


func _move_to_position(target_pos: Vector3, delta: float, random_mode: bool) -> void:
	var to_target := target_pos - global_position
	var distance := to_target.length()

	if distance > 0.1:
		var dir := to_target / distance

		# move
		global_position += dir * speed * delta

		# rotate around Y only (keeps light scale safe)
		var flat_dir := Vector3(dir.x, 0.0, dir.z)
		if flat_dir.length() > 0.001:
			var target_yaw := atan2(flat_dir.x, flat_dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)
	else:
		# reached target
		if random_mode:
			_pick_new_random_target()
		else:
			current_target_index = (current_target_index + 1) % patrol_points.size()
			print("🔄 Next patrol point:", current_target_index)


func _pick_new_random_target() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var angle := rng.randf_range(0.0, TAU)
	var radius := rng.randf_range(0.0, random_radius)

	var offset := Vector3(
		cos(angle) * radius,
		0.0,
		sin(angle) * radius
	)

	random_target = center_pos + offset
	# keep height the same as the heli
	random_target.y = global_position.y

	print("🎯 New random target:", random_target)
