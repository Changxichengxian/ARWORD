extends "res://scripts/sea_routes.gd"

# Share the boat's spherical route planner, with animal-sized clearance and
# seabed obstacles. No animal route writes construction or learning records.
var life
func _init(owner_life):
	life=owner_life
	super(owner_life.world)
func clear_arc(a:Vector3,b:Vector3)->bool:
	var segments=maxi(2,ceili(a.angle_to(b)*IslandTerrain.RADIUS/.24))
	for i in range(segments+1):
		var n=a.slerp(b,float(i)/segments).normalized()
		if not life.outside_land(n,.66) or not life.clear_of_cave(n,.72):return false
		if not life.clear_of_seabed_props(n,.70,IslandWater.MAX_DEPTH):return false
	return true
