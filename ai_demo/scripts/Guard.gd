extends CharacterBody3D


@export var move_speed: float = 3.0
@export var fov: float = 180.0
@export var losRange: float = 20.0
@export var susDecay: float = 0.35
@export var susRise: float = 0.8
@export var losLoseGrace: float = 1.0
@export var turn_speed: float = 8.0

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var facing: Node3D = $Facing
@onready var label: Label3D = $Facing/Label3D
@onready var los: RayCast3D = $Facing/RayCast3D


var patrol_points: Array[Vector3] = []
var idx := 0
var suspicion := 0.1
var lastKnown: Vector3 = Vector3.ZERO
var lostLosTimer : float
var searchTtl : float
var investigateTarget: Vector3 = Vector3.ZERO
var player: Node3D

enum State {PATROL, SUSPICIOUS, CHASE, SEARCH}
var state := State.PATROL
var last_face_dir: Vector3 = Vector3(0, 0, -1)  # remember last valid facing


func _ready() -> void:
	# Gather waypoint positions from child Markers named WP*
	for c in get_children():
		if c is Marker3D and c.name.begins_with("WP"):
			patrol_points.append(c.global_transform.origin)
	if patrol_points.is_empty():
		push_warning("Guard has no WP markers; generating a small square near origin.")
		var o = global_transform.origin
		patrol_points = [o + Vector3(6,0,0), o + Vector3(6,0,6), o + Vector3(0,0,6), o]

	agent.max_speed = move_speed
	agent.path_max_distance = 2.0
	agent.target_position = patrol_points[0]
	label.text = "PATROL"
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_perceive(delta)
	_state_logic(delta)
	if player == null: player = get_tree().get_first_node_in_group("player")

	# Decide target per state (no facing here; we do it after movement)
	match state:
		State.PATROL:
			if agent.is_navigation_finished():
				idx = (idx + 1) % patrol_points.size()
				agent.target_position = patrol_points[idx]

		State.SUSPICIOUS:
			var tgt := Vector3.ZERO
			if investigateTarget != Vector3.ZERO:
				tgt = investigateTarget
			elif player:
				tgt = player.global_transform.origin
			if tgt != Vector3.ZERO:
				agent.target_position = tgt

		State.CHASE:
			if player:
				agent.target_position = player.global_transform.origin

		State.SEARCH:
			# (we'll add search pathing later)
			pass

	# Move toward the next path position
	var next_pos = agent.get_next_path_position()
	var to_next = next_pos - global_transform.origin
	if to_next.length() > 0.05:
		var dir = to_next.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	else:
		velocity.x = lerpf(velocity.x, 0.0, 0.2)
		velocity.z = lerpf(velocity.z, 0.0, 0.2)

	# --- Smooth facing with robust fallbacks (never zero) ---
	var cand := Vector3.ZERO

	# 1) Highest priority in CHASE: look at player
	if state == State.CHASE and player:
		cand = player.global_transform.origin - global_transform.origin

	# 2) Else, if we're actually moving, face movement velocity
	if cand.length() < 0.01:
		var vel2d = Vector3(velocity.x, 0.0, velocity.z)
		if vel2d.length() > 0.05:
			cand = vel2d

	# 3) Else, face the next path position
	if cand.length() < 0.01:
		cand = agent.get_next_path_position() - global_transform.origin

	# 4) Else, face the target position itself
	if cand.length() < 0.01:
		cand = agent.target_position - global_transform.origin

	# 5) Else, keep current forward (prevents snaps)
	if cand.length() < 0.01:
		cand = -facing.global_transform.basis.z  # current forward

	# Apply yaw lerp (forward = -Z)
	cand.y = 0.0
	if cand.length() > 0.001:
		cand = cand.normalized()
		var target_yaw := atan2(-cand.x, -cand.z)
		facing.rotation.y = lerp_angle(facing.rotation.y, target_yaw, turn_speed * delta)

	velocity.y = 0.0
	move_and_slide()

	label.text = ["PATROL","SUSPICIOUS","CHASE","SEARCH"][state] + "  S:" + str(snappedf(suspicion, 0.01))

	

func _perceive(delta):
	var seen:=false
	if player:
		var to_p = player.global_transform.origin - global_transform.origin
		if to_p.length() <= float(losRange):
			var forward = -facing.global_transform.basis.z
			var to_dir = to_p.normalized()
			var ang_deg = rad_to_deg(acos(clampf(forward.dot(to_dir), -1.0, 1.0)))
			if ang_deg <= float(fov) * 0.5:
				los.target_position = Vector3(0, 0, -losRange)   # local forward
				los.force_raycast_update()
				seen = los.is_colliding() and los.get_collider() == player

	if seen:
		suspicion = clampf(suspicion + susRise * delta, 0.0, 1.0)
		lastKnown= player.global_transform.origin
		lostLosTimer = 0.0
	else :
		suspicion = clampf(suspicion - susDecay * delta, 0.0, 1.0) 
		lostLosTimer += delta
		
	for n in Blackboard.alerts:
		var d = global_transform.origin.distance_to(n["pos"])
		if d <= float(n["radius"]):
			var proximity = 1.0 - clampf(d/float(n["radius"]), 0.0, 1.0)
			suspicion = clampf(suspicion + 0.35 * proximity * delta, 0.0, 1.0)
			investigateTarget = n["pos"]
	print("sus=", snappedf(suspicion, 0.01), " losT=", snappedf(lostLosTimer, 0.01))

func _state_logic(delta:float) -> void:
	match state:
		State.PATROL:
			if suspicion>0.35:
				state=State.SUSPICIOUS
		
		State.SUSPICIOUS:
			if suspicion > .7 and lostLosTimer < 0.5:
				state = State.CHASE
			elif suspicion <= 0.0:
				state = State.PATROL
			
		State.CHASE:
			if lostLosTimer > losLoseGrace:
				state = State.SEARCH
				searchTtl = 8.0
				
		State.SEARCH:
			searchTtl -= delta
			if lostLosTimer < 0.2 and suspicion > 0.35:
				state = State.CHASE
			elif searchTtl <= 0.0:
				state = State.PATROL
				
