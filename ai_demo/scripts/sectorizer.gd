# res://Systems/Sectorizer.gd
extends Node
class_name Sectorizer

# Tunables
@export var cell_size: float = 20.0          # meters between sector centers
@export var accept_dist: float = 12.0        # max distance to nav to accept a sector

# Grid state
var _origin: Vector3 = Vector3.ZERO
var _nx: int = 0
var _nz: int = 0
var _sectors: Array = []        # each: {id, center, heat, cooldown_until, walkable, is_connector, i, j}
var _nav_map: RID

func _cell_index(ii: int, jj: int) -> int:
	if ii < 0 or jj < 0 or ii >= _nx or jj >= _nz:
		return -1
	return jj * _nx + ii


# Build from an axis-aligned Box 'SectorBounds' and a NavigationRegion3D in the scene
func build_from_bounds(bounds: Area3D, nav_region: NavigationRegion3D, new_cell_size: float = -1.0) -> void:
	if is_instance_valid(bounds) == false or is_instance_valid(nav_region) == false:
		push_error("Sectorizer.build_from_bounds: missing nodes")
		return
	if new_cell_size > 0.0:
		cell_size = new_cell_size

	_nav_map = nav_region.get_navigation_map()
	if not _nav_map.is_valid():
		push_error("Sectorizer: Navigation map invalid")
		return

	# Axis-aligned AABB from the BoxShape (keep bounds unrotated)
	var shape := bounds.get_node_or_null("CollisionShape3D")
	if shape == null or shape.shape == null or not (shape.shape is BoxShape3D):
		push_error("Sectorizer: SectorBounds must have a BoxShape3D")
		return
	var ext: Vector3 = (shape.shape as BoxShape3D).size * 0.5
	var c: Vector3 = bounds.global_transform.origin
	var minx = c.x - ext.x
	var maxx = c.x + ext.x
	var minz = c.z - ext.z
	var maxz = c.z + ext.z

	# Snap origin to grid
	_origin = Vector3(minx, c.y, minz)
	_nx = int(ceil((maxx - minx) / cell_size))
	_nz = int(ceil((maxz - minz) / cell_size))

	_sectors.clear()
	var id := 0
	for j in range(_nz):
		for i in range(_nx):
			var px = _origin.x + (i + 0.5) * cell_size
			var pz = _origin.z + (j + 0.5) * cell_size
			var probe := Vector3(px, c.y, pz)

			var nav_pt := NavigationServer3D.map_get_closest_point(_nav_map, probe)
			var walkable := nav_pt != Vector3.INF and nav_pt.distance_to(probe) <= accept_dist
			if walkable:
			
				probe.y = nav_pt.y

			var center_point := nav_pt if walkable else probe

			_sectors.append({
				"id": id,
				"center": center_point,
				"heat": 0.0,
				"cooldown_until": 0.0,
				"walkable": walkable,
				"is_connector": false,
				"i": i,
				"j": j,
			})
			id += 1

	# keep this print at the same indent level as the 'for' loops (still inside the function)
	print("Sectorizer: built %d cells (%d x %d)" % [_sectors.size(), _nx, _nz])


func sector_count() -> int:
	return _sectors.size()

func sector_id_at(pos: Vector3) -> int:
	var best := -1
	var best_d2 := INF
	for s in _sectors:
		if not s.walkable: continue
		var d2 = s.center.distance_squared_to(pos)
		if d2 < best_d2:
			best_d2 = d2; best = s.id
	return best

func center(id: int) -> Vector3:
	return _sectors[id].center

func neighbors(id: int) -> PackedInt32Array:
	var s = _sectors[id]
	var i: int = s.i
	var j: int = s.j

	var ids := PackedInt32Array()

	var n = _cell_index(i + 1, j)
	if n != -1 and _sectors[n].walkable:
		ids.append(n)

	n = _cell_index(i - 1, j)
	if n != -1 and _sectors[n].walkable:
		ids.append(n)

	n = _cell_index(i, j + 1)
	if n != -1 and _sectors[n].walkable:
		ids.append(n)

	n = _cell_index(i, j - 1)
	if n != -1 and _sectors[n].walkable:
		ids.append(n)

	return ids


func random_point_in(id: int) -> Vector3:
	var c = _sectors[id].center
	var jx = randf_range(-0.45, 0.45) * cell_size
	var jz = randf_range(-0.45, 0.45) * cell_size
	var candidate = c + Vector3(jx, 0.0, jz)
	if _nav_map.is_valid():
		var p = NavigationServer3D.map_get_closest_point(_nav_map, candidate)
		if p != Vector3.INF: return p
	return candidate

# Optional: debug helper to feed a MultiMeshInstance3D (one box per sector)
func debug_fill_multimesh(mmi: MultiMeshInstance3D, y_offset: float = 0.2, box_scale: float = 0.2) -> void:
	if mmi == null: return
	if mmi.multimesh == null:
		mmi.multimesh = MultiMesh.new()
	var mm = mmi.multimesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = _sectors.size()
	for k in _sectors.size():
		var s = _sectors[k]
		var t := Transform3D(Basis.IDENTITY, s.center + Vector3(0, y_offset, 0))
		t.basis = Basis().scaled(Vector3(box_scale, box_scale, box_scale))
		mm.set_instance_transform(k, t)
