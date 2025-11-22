extends Node
class_name AIDirector

@export var heat_decay: float = 0.85
@export var hot_threshold: float = 0.25
@export var sector_cooldown_sec: float = 5.0
@export var max_squads: int = 2
@export var min_reassign_sec: float = 4.0

<<<<<<< Updated upstream
var sector_heat: PackedFloat32Array = PackedFloat32Array()
var sector_cooldown: PackedFloat32Array = PackedFloat32Array()
var _assignments: Dictionary = {}        # sector_id -> Array[Node]

# Call once after the Sectorizer has built its grid.
func init_for_current_map() -> void:
	var n: int = Sector.sector_count()   # swap to Sectors.* if that's your autoload name
	sector_heat.resize(n)
	sector_cooldown.resize(n)
	for i in range(n):
=======
var sector_heat := PackedFloat32Array()
var sector_cooldown := PackedFloat32Array()   # unix time until
var _last_dispatch_time := 0.0
var _assignments := {}  # sector_id -> Array[Node] (guards)

# call once after Sectorizer is built
func init_for_current_map() -> void:
	var n = Sectorizer.sector_count()
	sector_heat.resize(n)
	sector_cooldown.resize(n)
	for i in n:
>>>>>>> Stashed changes
		sector_heat[i] = 0.0
		sector_cooldown[i] = 0.0
	_assignments.clear()

func push_event(kind: String, pos: Vector3, weight: float = 1.0) -> void:
<<<<<<< Updated upstream
	if Sector.sector_count() == 0:
		return
	var sid: int = Sector.sector_id_at(pos)
	if sid < 0:
		return

	var w: float = 0.5
	match kind:
		"heli":
			w = 1.0
		"lkp":
			w = 0.7
		"noise":
			w = 0.4
		_:
			w = 0.5

	sector_heat[sid] += w * weight

func tick_dispatch(_elapsed: float) -> void:
	var now: float = Time.get_unix_time_from_system()

	# Decay heat
	for i in range(sector_heat.size()):
		sector_heat[i] *= heat_decay
		if sector_heat[i] < 0.001:
			sector_heat[i] = 0.0

	# Hot sectors (not cooling)
	var hot: Array = []
	for i in range(sector_heat.size()):
		if sector_heat[i] >= hot_threshold and now >= sector_cooldown[i]:
			hot.append(i)

	# Clean assignments (remove deleted guards)
	var to_delete: Array = []
	for sid in _assignments.keys():
		var arr: Array = _assignments[sid]
		var kept: Array = []
		for g in arr:
			if is_instance_valid(g) and not g.is_queued_for_deletion():
				kept.append(g)
		if kept.is_empty():
			to_delete.append(sid)
		else:
			_assignments[sid] = kept
	for k in to_delete:
		_assignments.erase(k)

	var budget: int = max_squads - _assignments.size()
	if budget <= 0:
		return

	# Assign nearest idle guard to each hot sector until budget runs out
	var guards: Array = get_tree().get_nodes_in_group("guards")
	for sid in hot:
		if budget <= 0:
			break
		if _assignments.has(sid):
			continue

		var c: Vector3 = Sectorizer.center(sid)

		var best_g: Node = null
		var best_d2: float = INF

		for g in guards:
			if not is_instance_valid(g):
				continue
			if g.is_busy():
				continue
			if now - g.get_last_task_time() < min_reassign_sec:
				continue
			var d2: float = g.global_transform.origin.distance_squared_to(c)
			if d2 < best_d2:
				best_d2 = d2
				best_g = g

		if best_g != null:
=======
	if Sectorizer.sector_count() == 0: return
	var sid := Sectorizer.sector_id_at(pos)
	if sid < 0: return
	var w := match kind:
		"heli": 1.0
		"lkp": 0.7
		"noise": 0.4
		_: 0.5
	sector_heat[sid] += w * weight

func tick_dispatch(elapsed: float) -> void:
	var now := Time.get_unix_time_from_system()
	# decay & free cooled sectors
	for i in sector_heat.size():
		sector_heat[i] *= heat_decay
		if sector_heat[i] < 0.001:
			sector_heat[i] = 0.0
	# pick hot sectors (not cooled)
	var hot := []
	for i in sector_heat.size():
		if sector_heat[i] >= hot_threshold and now >= sector_cooldown[i]:
			hot.append(i)
	# keep at most max_squads tasks total
	var budget := max_squads
	# remove finished assignments
	var to_delete := []
	for sid in _assignments.keys():
		var arr: Array = _assignments[sid]
		arr = arr.filter(func(g): return is_instance_valid(g) and not g.is_queued_for_deletion())
		if arr.is_empty():
			to_delete.append(sid)
		else:
			_assignments[sid] = arr
	for k in to_delete:
		_assignments.erase(k)
	budget -= _assignments.size()
	if budget <= 0: return

	# choose nearest idle guard per hot sector until budget runs out
	var guards := get_tree().get_nodes_in_group("guards")
	for sid in hot:
		if budget <= 0: break
		if _assignments.has(sid): continue
		var c := Sectorizer.center(sid)
		var best_g := null
		var best_d2 := INF
		for g in guards:
			if not is_instance_valid(g): continue
			if g.is_busy(): continue
			# reassign hysteresis: give them a minimum dwell time
			if now - g.get_last_task_time() < min_reassign_sec: continue
			var d2 := g.global_transform.origin.distance_squared_to(c)
			if d2 < best_d2:
				best_d2 = d2; best_g = g
		if best_g:
>>>>>>> Stashed changes
			best_g.set_task_investigate_sector(sid)
			_assignments[sid] = [best_g]
			budget -= 1

func mark_sector_cooldown(sid: int) -> void:
	sector_cooldown[sid] = Time.get_unix_time_from_system() + sector_cooldown_sec
