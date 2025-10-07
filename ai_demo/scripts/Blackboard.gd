extends Node

var alerts : Array = []

func add_noise(pos: Vector3, radius: float, ttl: float) -> void:
	alerts.append({"pos": pos, "radius":radius, "ttl": ttl})

func tick(delta: float) -> void:
	for n in alerts:
		n["ttl"] -= delta
	alerts = alerts.filter(func(item): return item["ttl"] > 0.0)

 
