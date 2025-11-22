extends Node3D

# --- SETTINGS ---
@export var orbit_radius: float = 4.0
@export var orbit_speed: float = 0.8
@export var height: float = 2.0

var angle: float = 0.0
var has_fled: bool = false
var player: Node3D = null

# --- SCENE REFERENCES ---
@onready var trigger_area: Area3D = $TriggerArea
@onready var birds_root: Node3D = $Birds


# ---------------------------------------------------------
# READY
# ---------------------------------------------------------
func _ready() -> void:
	# Find player by group
	player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		push_warning("⚠ No node in group 'player' found — detection won't work")
	else:
		print("✅ Bird flock ready — player linked:", player.name)

	# Verify TriggerArea exists
	if trigger_area == null:
		push_error("❌ TriggerArea node NOT FOUND — check your scene!")
		return

	# Connect trigger signal
	if trigger_area.has_signal("body_entered"):
		trigger_area.body_entered.connect(_on_trigger_body_entered)
		print("✅ Trigger connected successfully")


# ---------------------------------------------------------
# ORBIT BEHAVIOR
# ---------------------------------------------------------
func _physics_process(delta: float) -> void:
	if has_fled:
		_fly_up(delta)
		return

	angle += orbit_speed * delta

	var cx := global_position.x
	var cz := global_position.z

	for bird in birds_root.get_children():
		var x = cx + orbit_radius * cos(angle)
		var z = cz + orbit_radius * sin(angle)
		var y = global_position.y + height

		bird.global_position = Vector3(x, y, z)
		bird.look_at(global_position, Vector3.UP)


# ---------------------------------------------------------
# PLAYER ENTER DETECTED
# ---------------------------------------------------------
func _on_trigger_body_entered(body: Node3D) -> void:
	if has_fled:
		return

	if body == player:
		print("🕊️ BIRDS DETECTED PLAYER at:", player.global_position)
		has_fled = true


# ---------------------------------------------------------
# FLY AWAY BEHAVIOR
# ---------------------------------------------------------
func _fly_up(delta: float) -> void:
	for bird in birds_root.get_children():
		bird.global_position.y += 6.0 * delta
