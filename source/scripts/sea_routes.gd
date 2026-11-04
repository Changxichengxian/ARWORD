extends RefCounted

var world
var graph=AStar3D.new()
var grid={}
var land_count=-1
var ports={}
const COLS=40
const ROWS=18

func _init(owner_world):world=owner_world
func clear_arc(a:Vector3,b:Vector3)->bool:
	# A fixed nine samples can jump over an entire island on a long direct route.
	# Keep sample separation below a quarter of a tile radius on every segment.
	var segments=maxi(2,ceili(a.angle_to(b)*IslandTerrain.RADIUS/.28))
	for i in range(segments+1):
		if world.water.depth_at(a.slerp(b,float(i)/segments).normalized())<.35:return false
	return true
func rebuild():
	if land_count==world.land.size():return
	land_count=world.land.size()
	if world.water.land_count!=land_count:world.water.rebuild()
	graph.clear();grid.clear()
	for row in range(1,ROWS):
		for col in range(COLS):
			var latitude=PI*row/ROWS;var longitude=TAU*col/COLS
			var n=Vector3(sin(latitude)*cos(longitude),cos(latitude),sin(latitude)*sin(longitude))
			if world.water.depth_at(n)>.5:
				var id=grid.size();grid[Vector2i(col,row)]=id;graph.add_point(id,n*IslandTerrain.RADIUS)
	for key in grid:
		for offset in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(-1,1)]:
			var next=Vector2i(posmod(key.x+offset.x,COLS),key.y+offset.y)
			if grid.has(next) and clear_arc(graph.get_point_position(grid[key]).normalized(),graph.get_point_position(grid[next]).normalized()):graph.connect_points(grid[key],grid[next])
func coast(chart:int,toward:Vector3)->Vector3:
	var best=Vector3.ZERO;var score=-INF
	for cell in world.land:
		var center=IslandFrontier.point(cell)
		if world.terrain.chart_at(center)!=chart:continue
		for i in range(24):
			# Small islands have a shallow shelf beyond 1.65 hex radii. Search outwards
			# to the first navigable water instead of rejecting their entire coastline.
			for radius in [1.65,2.05,2.5,3.0]:
				var p=center+Vector2.from_angle(i*TAU/24)*IslandFrontier.HEX*radius
				var n=world.surface(p).normalized()
				if world.water.depth_at(n)<.55:continue
				var value=n.dot(toward)
				if value>score:score=value;best=n
				break
	return best
func nearest_visible(normal:Vector3)->int:
	var best=-1;var distance=INF
	for id in graph.get_point_ids():
		var n=graph.get_point_position(id).normalized();var d=n.distance_squared_to(normal)
		if d<distance and clear_arc(normal,n):distance=d;best=id
	return best
func route(origin:Vector2,target:Vector2)->Array:
	rebuild()
	return sea_path(port(world.terrain.chart_at(origin)),port(world.terrain.chart_at(target)))

func port(chart:int)->Vector3:
	return ports.get(chart,Vector3.ZERO)

func sea_path(a:Vector3,b:Vector3)->Array:
	if a.length_squared()<.5 or b.length_squared()<.5:return []
	if clear_arc(a,b):return [a,b]
	var first=nearest_visible(a);var last=nearest_visible(b)
	if first<0 or last<0:return []
	var path=graph.get_point_path(first,last)
	if path.is_empty():return []
	var result=[a]
	for point in path:result.append(point.normalized())
	result.append(b)
	var visible=[a]
	var i=0
	while i<result.size()-1:
		var next=result.size()-1
		while next>i+1 and not clear_arc(result[i],result[next]):next-=1
		if result[next].distance_squared_to(visible[-1])>.0000001:visible.append(result[next])
		i=next
	return round_corners(visible)

func round_corners(points:Array)->Array:
	var curve=[points[0]]
	for i in range(1,points.size()-1):
		var before:Vector3=points[i-1];var pivot:Vector3=points[i];var after:Vector3=points[i+1]
		var left=pivot.angle_to(before);var right=pivot.angle_to(after)
		var cut=minf(.32,.46*minf(left,right))
		var arc=[]
		while cut>.0001:
			var start=pivot.slerp(before,cut/left);var end=pivot.slerp(after,cut/right)
			var count=maxi(6,ceili(cut*IslandTerrain.RADIUS/.10))
			arc=[start]
			for j in range(1,count+1):
				var t=float(j)/count
				var p=start.slerp(pivot,t).slerp(pivot.slerp(end,t),t).normalized()
				if not clear_arc(arc[-1],p):arc.clear();break
				arc.append(p)
			if not arc.is_empty():break
			cut*=.5
		if arc.is_empty():curve.append(pivot)
		else:curve.append_array(arc)
	curve.append(points[-1])
	return curve
