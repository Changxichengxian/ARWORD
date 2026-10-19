extends RefCounted
class_name IslandFrontier

# A finite map. Each chapter adds land or a new use for the same source assets.
const HEX=1.34
const START=[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)]
const CHAPTERS=[
	{"id":"grove","title":"沿岸树林","need":6,"requires":[],"cells":[Vector2i(-1,0),Vector2i(-1,1),Vector2i(-2,1)],"point":Vector2i(-1,1),"site":0,"note":0},
	{"id":"quarry","title":"露出石岸","need":6,"requires":[],"cells":[Vector2i(1,-1),Vector2i(2,-1),Vector2i(2,0)],"point":Vector2i(2,-1),"site":1,"note":0},
	{"id":"sawmill","title":"林间锯木坊","need":8,"requires":["grove","quarry"],"cells":[Vector2i(0,-1),Vector2i(0,-2),Vector2i(1,-2)],"point":Vector2i(0,-1),"site":0,"note":1},
	{"id":"meadow","title":"南边的草地","need":6,"requires":["grove"],"cells":[Vector2i(0,2),Vector2i(-1,2),Vector2i(-1,3)],"point":Vector2i(-1,2),"site":2,"note":3},
	{"id":"kiln","title":"石岸砖窑","need":8,"requires":["quarry","sawmill"],"cells":[Vector2i(3,-1),Vector2i(3,0),Vector2i(2,1)],"point":Vector2i(3,0),"site":1,"note":2},
	{"id":"crystal","title":"晶簇小湾","need":8,"requires":["kiln"],"cells":[Vector2i(-1,-1),Vector2i(-1,-2),Vector2i(-2,-1)],"point":Vector2i(-1,-1),"site":1,"note":4},
	{"id":"hill","title":"向风的小丘","need":6,"requires":["quarry"],"cells":[Vector2i(1,1),Vector2i(1,2),Vector2i(1,3)],"point":Vector2i(1,2),"site":1,"note":3}
]
const BUILD_IDS=["cottage","windmill","garden"]
const BUILD_CELLS=[Vector2i(1,0),Vector2i(1,3),Vector2i(-1,3)]
const BUILD_GATES=["","hill","meadow"]
var learning:IslandLearning
var data:Dictionary

func _init(owner_learning:IslandLearning):
	learning=owner_learning
	var stored=learning.data.frontier
	data={"active":"grove","progress":{},"turns":{}}
	if not stored.is_empty():
		if stored.get("active") is String:data.active=stored.active
		for key in ["progress","turns"]:
			if stored.get(key) is Dictionary:data[key]=stored[key].duplicate(true)
	else:
		# Old buildings remain where they were earned; expose their new supporting land.
		if learning.data.actions>0:
			data.active=BUILD_IDS[learning.data.active]
			for i in range(3):data.turns[BUILD_IDS[i]]=int(learning.data.work_turns[i])
			for c in CHAPTERS:
				if c.id in ["grove","quarry"] or (learning.data.build[1]>0 and c.id=="hill") or (learning.data.build[2]>0 and c.id=="meadow"):data.progress[c.id]=c.need
	for c in CHAPTERS:
		data.progress[c.id]=clampi(int(data.progress.get(c.id,0)),0,c.need) if data.progress.get(c.id,0) is int or data.progress.get(c.id,0) is float else 0
	for id in data.turns.keys():
		data.turns[id]=clampi(int(data.turns[id]),0,1000000) if data.turns[id] is int or data.turns[id] is float else 0
	learning.data.frontier=data
	if not available(data.active):data.active="grove"
	learning.data.active=site(data.active)

static func point(cell:Vector2i)->Vector2:return Vector2(sqrt(3.0)*HEX*(cell.x+cell.y*.5),1.5*HEX*cell.y)
func chapter(id:String)->Dictionary:
	for c in CHAPTERS:
		if c.id==id:return c
	return {}
func done(id:String)->bool:
	var c=chapter(id)
	return int(data.progress.get(id,0))>=int(c.need) if not c.is_empty() else learning.site_done(BUILD_IDS.find(id)) if id in BUILD_IDS else false
func available(id:String)->bool:
	if id in BUILD_IDS:
		var i=BUILD_IDS.find(id)
		return BUILD_GATES[i].is_empty() or done(BUILD_GATES[i]) or learning.data.build[i]>0
	var c=chapter(id)
	if c.is_empty():return false
	for dependency in c.requires:
		if not done(dependency):return false
	return true
func site(id:String)->int:return BUILD_IDS.find(id) if id in BUILD_IDS else int(chapter(id).get("site",0))
func target(id:String)->Vector2:return point(BUILD_CELLS[BUILD_IDS.find(id)]) if id in BUILD_IDS else point(chapter(id).point)
func progress(id:String)->Vector2:
	if id in BUILD_IDS:return learning.progress(site(id))
	var c=chapter(id);return Vector2(data.progress[id],c.need)
func title(id:String)->String:
	if id in BUILD_IDS:
		var i=site(id);return IslandLearning.STEPS[i][learning.stage(i)] if not done(id) else IslandLearning.PROJECTS[i]+" · 自由照料"
	return str(chapter(id).title)
func mode()->String:return IslandLearning.MODES[int(data.turns.get(data.active,0))%6]
func choose(id:String)->bool:
	if not available(id):return false
	data.active=id;learning.select_site(site(id));return true
func advance()->Dictionary:
	var id=str(data.active);data.turns[id]=int(data.turns.get(id,0))+1
	if id in BUILD_IDS:return learning.advance()
	var c=chapter(id);var old=int(data.progress[id]);data.progress[id]=mini(c.need,old+1)
	learning.data.actions+=1
	return {"complete":old<c.need and data.progress[id]==c.need,"project":site(id),"fraction":float(data.progress[id])/c.need}
func cells()->Array:
	var result=START.duplicate()
	for c in CHAPTERS:
		var count=int(floor(float(data.progress[c.id])*3/c.need))
		for i in range(count):
			if not result.has(c.cells[i]):result.append(c.cells[i])
	return result
func finished_count()->int:
	var count=0
	for c in CHAPTERS:
		if done(c.id):count+=1
	return count
