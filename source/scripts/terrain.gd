extends RefCounted
class_name IslandTerrain

const RADIUS=12.0
const H=1.34
var cells={}
var corners={}
const HEIGHTS={
	"grove":[.12,.24,.34],"quarry":[.52,.86,.65],"sawmill":[.25,.48,.62],
	"meadow":[.10,.24,.18],"kiln":[.68,.46,.24],"crystal":[.15,.38,.25],
	"hill":[.64,1.08,1.42],"wetland":[.06,.08,.12],"plateau":[1.25,1.85,1.85],"mountain":[1.15,2.05,2.80]}
const COLORS={"shore":"D6CA86","grove":"6EA761","quarry":"8CABA5","sawmill":"79A86B","meadow":"96BD69","kiln":"B3AE87","crystal":"929AB3","hill":"8EAF5D","wetland":"69ADA0","plateau":"B9B684","mountain":"9EABB4"}
func _init():
	for cell in IslandFrontier.START:cells[cell]={"kind":"shore","height":0.0}
	cells[Vector2i.ZERO].kind="grove";cells[Vector2i(1,0)].kind="meadow"
	for chapter in IslandFrontier.CHAPTERS:
		for i in range(chapter.cells.size()):cells[chapter.cells[i]]={"kind":chapter.id,"height":HEIGHTS[chapter.id][i]}
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
	var base=Vector3(p.x,sqrt(maxf(.1,RADIUS*RADIUS-p.length_squared())),p.y)
	return base.normalized()*(RADIUS+height_at(p))
func coordinates(p:Vector3)->Vector2:
	var base=p.normalized()*RADIUS;return Vector2(base.x,base.z)
