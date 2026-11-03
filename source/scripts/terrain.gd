extends RefCounted
class_name IslandTerrain

const RADIUS=12.0
const H=1.34
const CHART_CELLS=[Vector2i(0,0),Vector2i(20,0),Vector2i(-20,0),Vector2i(0,20),Vector2i(0,-20)]
const CHART_NORMALS=[Vector3.UP,Vector3(-.88,.08,.47),Vector3(.95,-.06,.30),Vector3(-.65,-.42,-.63),Vector3(0,-1,0)]
var cells={}
var corners={}
const HEIGHTS={
	"grove":[.12,.24,.34],"quarry":[.52,.86,.65],"sawmill":[.25,.48,.62],
	"meadow":[.10,.24,.18],"kiln":[.68,.46,.24],"crystal":[.15,.38,.25],
	"hill":[.64,1.08,1.42],"wetland":[.06,.08,.12],"plateau":[1.05,1.85,.95],"mountain":[1.15,2.05,2.80],
	"shipyard":[.14,.22,.08],"sunreach":[.10,.45,.22],"coral":[.12,.05,.25],"basalt":[.68,1.35,.36],"tideworks":[.15,.36,.08],"goldmine":[.65,1.35,.18],"smelter":[.30,.45,.18],"rocket":[.25,.35,.18]}
const COLORS={"shore":"D6CA86","grove":"6EA761","quarry":"8CABA5","sawmill":"79A86B","meadow":"96BD69","kiln":"B3AE87","crystal":"929AB3","hill":"8EAF5D","wetland":"69ADA0","plateau":"B9B684","mountain":"9EABB4","shipyard":"C2BF8A","sunreach":"96C777","coral":"E6D9B3","basalt":"6B7A83","tideworks":"A6BFAB","goldmine":"92A0A0","smelter":"BAAA82","rocket":"8CAFA6"}
func _init():
	for cell in IslandFrontier.START:cells[cell]={"kind":"shore","height":0.0}
	for i in range(IslandFrontier.ROCKET_CELLS.size()):
		cells[IslandFrontier.ROCKET_CELLS[i]]={"kind":"rocket","height":HEIGHTS.rocket[i],"variant":i}
	cells[Vector2i.ZERO].kind="grove";cells[Vector2i(1,0)].kind="meadow"
	for chapter in IslandFrontier.CHAPTERS:
		for i in range(chapter.cells.size()):cells[chapter.cells[i]]={"kind":chapter.id,"height":HEIGHTS[chapter.id][i],"variant":i}
	for cell in cells:
		var p=IslandFrontier.point(cell)
		for i in range(6):
			var key=corner_key(p+corner_offset(i))
			if not corners.has(key):corners[key]=[]
			corners[key].append(float(cells[cell].height))
func corner_offset(i:int)->Vector2:return Vector2(cos((i*60+30)*PI/180),sin((i*60+30)*PI/180))*H
func corner_key(p:Vector2)->Vector2i:return Vector2i(roundi(p.x*1000),roundi(p.y*1000))
func corner_height(p:Vector2)->float:
	var values=corners.get(corner_key(p),[0.0]);var total=0.0
	for v in values:total+=v
	return total/values.size()
func cell_at(p:Vector2)->Vector2i:
	var nearest=Vector2i.ZERO;var distance=INF
	for cell in cells:
		var d=p.distance_squared_to(IslandFrontier.point(cell))
		if d<distance:distance=d;nearest=cell
	return nearest
func kind(cell:Vector2i)->String:return str(cells.get(cell,{"kind":"shore"}).kind)
func variant(cell:Vector2i)->int:return int(cells.get(cell,{}).get("variant",0))
func chart_at(p:Vector2)->int:
	var result=0;var distance=INF
	for i in range(CHART_CELLS.size()):
		var d=IslandFrontier.point(CHART_CELLS[i]).distance_squared_to(p)
		if d<distance:distance=d;result=i
	return result
func chart_basis(index:int)->Basis:return Basis(Quaternion(Vector3.UP,CHART_NORMALS[index].normalized()))
func surface_basis(p:Vector2)->Basis:
	var chart=chart_at(p);var basis=chart_basis(chart)
	return basis*Basis(Quaternion(Vector3.UP,(basis.inverse()*point(p)).normalized()))
func height_at(p:Vector2)->float:
	var cell=cell_at(p);var center=IslandFrontier.point(cell);var local=p-center
	var sector=int(floor(fposmod(atan2(local.y,local.x)-PI/6,TAU)/(PI/3)))%6
	var a=corner_offset(sector);var b=corner_offset((sector+1)%6)
	var determinant=a.cross(b);var u=local.cross(b)/determinant;var v=a.cross(local)/determinant;var radial=u+v
	if radial>1.08:return 0.0
	var edge=(corner_height(center+a)*u+corner_height(center+b)*v)/maxf(.0001,radial)
	var h=float(cells[cell].height)
	# Flat usable summit, sloped shoulders; shared corner heights keep neighboring hexes joined.
	return lerpf(h,edge,clampf((radial-.60)/.40,0,1))
func point(p:Vector2)->Vector3:
	var chart=chart_at(p)
	var local=p-IslandFrontier.point(CHART_CELLS[chart])
	# Local distances out from the chart centre are arc lengths on the sphere.
	# This keeps even the outer mint coast regular, without a projection horizon.
	var distance=local.length()
	var angle=distance/RADIUS
	var lateral=local*(sin(angle)/distance) if distance>.000001 else Vector2.ZERO
	var normal=Vector3(lateral.x,cos(angle),lateral.y)
	return chart_basis(chart)*normal*(RADIUS+height_at(p))

func chart_coordinates(chart:int,normal:Vector3)->Vector2:
	var local=chart_basis(chart).inverse()*normal
	var lateral=Vector2(local.x,local.z)
	var arc=RADIUS*atan2(lateral.length(),local.y)
	return IslandFrontier.point(CHART_CELLS[chart])+lateral.normalized()*arc
func coordinates(p:Vector3)->Vector2:
	var normal=p.normalized();var chart=0;var facing=-INF
	for i in range(CHART_NORMALS.size()):
		var dot=normal.dot(CHART_NORMALS[i].normalized())
		if dot>.15:
			var candidate=chart_coordinates(i,normal)
			var r=candidate.y/(1.5*H);var q=candidate.x/(sqrt(3.0)*H)-r*.5;var s=-q-r
			var iq=roundi(q);var ir=roundi(r);var iz=roundi(s)
			if absf(iq-q)>absf(ir-r) and absf(iq-q)>absf(iz-s):iq=-ir-iz
			elif absf(ir-r)>absf(iz-s):ir=-iq-iz
			if cells.has(Vector2i(iq,ir)):return candidate
		if dot>facing:facing=dot;chart=i
	return chart_coordinates(chart,normal)
