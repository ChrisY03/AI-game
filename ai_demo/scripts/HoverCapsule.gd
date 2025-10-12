extends RigidBody3D

@export var yaw: Node3D
@export var pitch: Node3D
@export var cam: Camera3D
@export var hover_ray: RayCast3D

# --- Hover (spring-damper) ---
@export var hover_height := 1.1           # target distance from ground
@export var spring_k := 4000.0            # spring stiffness (N/m)
@export var damper_c := 500.0             # damping (N·s/m)
@export var max_hover_force := 8000.0     # clamp safety

# --- Movement/thrust ---
@export var accel_ground := 45.0          # m/s^2 when grounded
@export var accel_air := 14.0             # m/s^2 when not grounded
@export var max_speed := 8.0              # horizontal cap (m/s)
@export var drag_coefficient := 0.8       # extra planar drag
@export var jump_impulse := 330.0         # upward impulse (N·s)
@export var jump_cooldown := 0.2

# --- Look ---
@export var mouse_sens := 0.12
@export_range(-89.0, 89.0) var pitch_min := -85.0
@export_range(-89.0, 89.0) var pitch_max :=  85.0

# --- Upright stabilization ---
@export var upright_strength := 900.0     # torque toward +Y
@export var upright_damping := 60.0

var _jump_cd := 0.0
var _grounded := false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not yaw:   yaw   = $Yaw
	if not pitch: pitch = $Yaw/Pitch
	if not cam:   cam   = $Yaw/Pitch/Camera3D
	if not hover_ray: hover_ray = $HoverRay
	# Built-in damping to help (we also add planar drag)
	linear_damp = 0.1
	angular_damp = 3.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		pitch.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		var e := pitch.rotation_degrees
		e.x = clamp(e.x, pitch_min, pitch_max)
		pitch.rotation_degrees = e

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	_jump_cd = max(0.0, _jump_cd - delta)

	_apply_hover_force(delta)
	_apply_upright_torque(delta)
	_apply_movement_forces(delta)
	_apply_planar_drag(delta)

	# Jump
	if _grounded and _jump_cd == 0.0 and Input.is_action_just_pressed("jump"):
		apply_central_impulse(Vector3.UP * jump_impulse)
		_jump_cd = jump_cooldown

# ---- Hover spring-damper using one downward ray ----
func _apply_hover_force(_delta: float) -> void:
	_grounded = false
	if not hover_ray.is_colliding():
		return

	var hit_pos := hover_ray.get_collision_point()
	var hit_normal := hover_ray.get_collision_normal()
	var to_hit := global_transform.origin - hit_pos
	var dist := to_hit.dot(-hit_normal)   # distance along ground normal

	# Treat surface normal as "up" locally to ride slopes
	var ray_dir := -hit_normal.normalized()

	# Compression: positive when below target height
	var x := hover_height - dist
	if x <= 0.0:
		return

	# Relative vertical speed along the ray direction (assume static ground)
	var v_rel := linear_velocity.dot(ray_dir)

	# Spring-damper force
	var force_mag := spring_k * x - damper_c * v_rel
	force_mag = clamp(force_mag, 0.0, max_hover_force)

	var force := ray_dir * force_mag
	apply_central_force(force)
	_grounded = true

# ---- Keep capsule upright (resists tipping) ----
func _apply_upright_torque(delta: float) -> void:
	var up := global_transform.basis.y.normalized()
	var err := up.cross(Vector3.UP)     # axis to rotate around to align up→+Y
	var corrective := err * upright_strength - angular_velocity * upright_damping
	apply_torque(corrective)

# ---- Thrust for move input (relative to camera yaw) ----
func _apply_movement_forces(delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	if input_vec.length() < 0.01:
		return

	# Camera-relative planar axes
	var f := -yaw.global_transform.basis.z; f.y = 0.0; f = f.normalized()
	var r :=  yaw.global_transform.basis.x; r.y = 0.0; r = r.normalized()
	var wish := (r * input_vec.x + f * input_vec.y).normalized()

	var accel := accel_ground if _grounded else accel_air
	var force := wish * accel * mass   # F = m a
	apply_central_force(force)

	# Soft speed cap (planar)
	var v := linear_velocity
	var v_planar := Vector3(v.x, 0.0, v.z)
	var speed := v_planar.length()
	if speed > max_speed:
		var excess := speed - max_speed
		# Apply a braking force opposite planar velocity
		var brake : Vector3 = -v_planar.normalized() * excess * mass / max(0.0001, delta)
		apply_central_force(brake)

# ---- Extra planar drag so it doesn't slide forever ----
func _apply_planar_drag(delta: float) -> void:
	var v := linear_velocity
	var v_planar := Vector3(v.x, 0.0, v.z)
	var drag := -v_planar * drag_coefficient * mass
	apply_central_force(drag)
