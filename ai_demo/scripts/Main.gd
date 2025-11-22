extends Node


func _ready():
	var bounds := $SectorBounds               # your Area3D
	var navreg := $NavigationRegion3D         # your baked region
	Sector.build_from_bounds(bounds, navreg, 20.0) 
	Director.init_for_current_map()

	# Optional: visualize
	# var mmi := $SectorDebugMMI               # a MultiMeshInstance3D you add in the scene
	# Sectorizer.debug_fill_multimesh(mmi)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
