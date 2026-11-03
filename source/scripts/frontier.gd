extends RefCounted
class_name IslandFrontier

# A finite map. Each chapter adds land or a new use for the same source assets.
const HEX=1.34
const START=[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)]
const ROCKET_CELLS=[Vector2i(0,-20),Vector2i(1,-20),Vector2i(0,-19)]
const TRADE_PRICE=36
const TRADE_BAG=6
const CHAPTERS=[
	{"id":"grove","title":"沿岸树林","need":6,"requires":[],"cells":[Vector2i(-1,0),Vector2i(-1,1),Vector2i(-2,1)],"point":Vector2i(-1,1),"site":0,"note":0},
	{"id":"quarry","title":"露出石岸","need":6,"requires":[],"cells":[Vector2i(1,-1),Vector2i(2,-1),Vector2i(2,0)],"point":Vector2i(2,-1),"site":1,"note":0},
	{"id":"sawmill","title":"林间锯木坊","need":8,"requires":["grove","quarry"],"cells":[Vector2i(0,-1),Vector2i(0,-2),Vector2i(1,-2)],"point":Vector2i(0,-1),"site":0,"note":1},
	{"id":"meadow","title":"南边的草地","need":6,"requires":["grove"],"cells":[Vector2i(0,2),Vector2i(-1,2),Vector2i(-1,3)],"point":Vector2i(-1,2),"site":2,"note":3},
	{"id":"kiln","title":"石岸砖窑","need":8,"requires":["quarry","sawmill"],"cells":[Vector2i(3,-1),Vector2i(3,0),Vector2i(2,1)],"point":Vector2i(3,0),"site":1,"note":2},
	{"id":"crystal","title":"晶簇小湾","need":8,"requires":["kiln"],"cells":[Vector2i(-1,-1),Vector2i(-1,-2),Vector2i(-2,-1)],"point":Vector2i(-1,-1),"site":1,"note":4},
	{"id":"hill","title":"向风的小丘","need":6,"requires":["quarry"],"cells":[Vector2i(1,1),Vector2i(1,2),Vector2i(1,3)],"point":Vector2i(1,2),"site":1,"note":3},
	{"id":"wetland","title":"芦苇浅湾","need":8,"requires":["meadow"],"cells":[Vector2i(-2,2),Vector2i(-3,2),Vector2i(-3,3)],"point":Vector2i(-3,2),"site":0,"note":3,"gate":"wood","threshold":8},
	{"id":"plateau","title":"石脊高原","need":10,"requires":["quarry"],"cells":[Vector2i(3,-2),Vector2i(4,-2),Vector2i(4,-1)],"point":Vector2i(4,-2),"site":1,"note":0,"gate":"stone","threshold":10},
	{"id":"mountain","title":"云杉观星台","need":12,"requires":["plateau","hill","crystal"],"cells":[Vector2i(0,-3),Vector2i(1,-3),Vector2i(2,-3)],"point":Vector2i(1,-3),"site":1,"note":0,"gate":"explore","threshold":12},
	{"id":"shipyard","title":"弯月船坞","need":12,"requires":["sawmill","kiln","wetland","plateau"],"cells":[Vector2i(-3,0),Vector2i(-3,1),Vector2i(-4,1)],"point":Vector2i(-3,1),"site":0,"note":5},
	{"id":"sunreach","title":"椰风群岛","need":10,"requires":["shipyard"],"cells":[Vector2i(20,0),Vector2i(21,0),Vector2i(20,1)],"point":Vector2i(20,0),"site":0,"note":6},
	{"id":"coral","title":"潮光玻璃坊","need":12,"requires":["sunreach","crystal"],"cells":[Vector2i(19,1),Vector2i(19,2),Vector2i(20,2)],"point":Vector2i(19,1),"site":1,"note":7},
	{"id":"basalt","title":"黑沙熔岩台","need":10,"requires":["shipyard","plateau"],"cells":[Vector2i(-20,0),Vector2i(-21,1),Vector2i(-20,1)],"point":Vector2i(-20,0),"site":1,"note":8},
	{"id":"tideworks","title":"潮汐引水站","need":12,"requires":["basalt","sunreach","wetland"],"cells":[Vector2i(-19,0),Vector2i(-19,-1),Vector2i(-20,-1)],"point":Vector2i(-19,0),"site":2,"note":9},
	{"id":"goldmine","title":"远岛金矿洞","need":8,"requires":["shipyard"],"cells":[Vector2i(0,20),Vector2i(1,20),Vector2i(0,21)],"point":Vector2i(0,20),"site":1},
	{"id":"smelter","title":"主岛铸币坊","need":8,"requires":["goldmine","kiln"],"cells":[Vector2i(-3,-1),Vector2i(-4,0),Vector2i(-4,-1)],"point":Vector2i(-3,-1),"site":1}
]
const PRODUCTION={
	"grove":{"name":"木料","raw":"timber","product":"timber","tool":0},
	"quarry":{"name":"切石","raw":"ore","product":"brick","tool":1},
	"sawmill":{"name":"木板","raw":"timber","product":"plank","tool":0},
	"meadow":{"name":"果粮","raw":"fruit_crate","product":"fruit_crate","tool":0},
	"kiln":{"name":"砖块","raw":"ore","product":"brick","tool":1},
	"crystal":{"name":"镜片","raw":"crystal","product":"lens","tool":1},
	"hill":{"name":"清水","raw":"water_jar","product":"water_jar","tool":0},
	"wetland":{"name":"帆布","raw":"reed_bundle","product":"sailcloth","tool":0},
	"plateau":{"name":"铁件","raw":"iron_ore","product":"metal_brace","tool":1},
	"mountain":{"name":"观星","raw":"lens","product":"lens","tool":1},
	"shipyard":{"name":"航线","raw":"plank","product":"plank","tool":0},
	"sunreach":{"name":"硬木","raw":"hardwood","product":"hardwood","tool":0},
	"coral":{"name":"海玻璃","raw":"sea_glass","product":"lens","tool":1},
	"basalt":{"name":"耐水石管","raw":"basalt_ore","product":"stone_pipe","tool":1},
	"tideworks":{"name":"引水","raw":"water_jar","product":"water_jar","tool":0},
	"goldmine":{"name":"采金","raw":"gold_ore","product":"gold_ore","tool":1},
	"smelter":{"name":"铸币","raw":"gold_ore","product":"gold_coin","tool":1}
}
const RECIPES={
	"sawmill":["grove","quarry"],"kiln":["quarry","sawmill"],"crystal":["kiln","plateau"],
	"wetland":["grove","meadow"],"plateau":["quarry","sawmill"],"mountain":["crystal","plateau","sawmill"],
	"shipyard":["sawmill","wetland","plateau","kiln"],"sunreach":["shipyard","wetland","sawmill"],
	"goldmine":["shipyard","plateau"],"smelter":["kiln","sawmill","plateau"],
	"coral":["sunreach","crystal","kiln"],"basalt":["plateau","sawmill"],"tideworks":["basalt","sunreach","wetland"],
	"cottage":["sawmill","kiln","grove"],"windmill":["plateau","sawmill","quarry"],"garden":["hill","meadow","tideworks"]
}
const BUILD_IDS=["cottage","windmill","garden"]
const BUILD_CELLS=[Vector2i(1,0),Vector2i(1,3),Vector2i(-1,3)]
const BUILD_GATES=["","hill","meadow"]
var learning:IslandLearning
var data:Dictionary

func _init(owner_learning:IslandLearning):
	learning=owner_learning
	var stored=learning.data.frontier
	data={"active":"grove","progress":{},"turns":{},"effort":{},"production":{},"deliveries":{}}
	if not stored.is_empty():
		if stored.get("active") is String:data.active=stored.active
		for key in ["progress","turns","effort","production","deliveries"]:
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
	for id in data.effort.keys():
		var value=data.effort[id];data.effort[id]=clampf(float(value),0,.999999) if (value is int or value is float) and is_finite(float(value)) else 0.0
	for key in ["production","deliveries"]:
		for id in data[key].keys():
			var value=data[key][id];data[key][id]=clampi(int(value),0,1000000) if (value is int or value is float) and is_finite(float(value)) else 0
	var voyage=stored.get("voyage",{})
	if not voyage is Dictionary:voyage={}
	data.voyage={"ore":0,"coins":0,"paid":0,"earned_book":"","dev_open":voyage.get("dev_open")==true}
	for key in ["ore","coins","paid"]:
		var value=voyage.get(key,0)
		if (value is int or value is float) and is_finite(float(value)):
			data.voyage[key]=clampi(int(value),0,TRADE_PRICE if key=="paid" else 1000000)
	var earned=voyage.get("earned_book","")
	if earned is String and not learning.wordbooks.find(earned).is_empty():
		data.voyage.earned_book=earned
	learning.data.frontier=data
	if not available(data.active) or data.active=="rocket":data.active="grove"
	learning.data.active=site(data.active)

static func point(cell:Vector2i)->Vector2:return Vector2(sqrt(3.0)*HEX*(cell.x+cell.y*.5),1.5*HEX*cell.y)
func chapter(id:String)->Dictionary:
	for c in CHAPTERS:
		if c.id==id:return c
	return {}
func done(id:String)->bool:
	if id=="rocket":return rocket_open()
	var c=chapter(id)
	return int(data.progress.get(id,0))>=int(c.need) if not c.is_empty() else learning.site_done(BUILD_IDS.find(id)) if id in BUILD_IDS else false
func available(id:String)->bool:
	if id=="rocket":return true
	if id in BUILD_IDS:
		var i=BUILD_IDS.find(id)
		return BUILD_GATES[i].is_empty() or done(BUILD_GATES[i]) or learning.data.build[i]>0
	var c=chapter(id)
	if c.is_empty():return false
	if done(id):return true
	for dependency in c.requires:
		if not done(dependency):return false
	return not c.has("gate") or gate_count(c.gate)>=int(c.threshold)
func gate_count(gate:String)->int:
	if gate=="wood":return int(learning.data.harvested[0])
	if gate=="stone":return int(learning.data.harvested[1])
	return int(learning.data.practice.read)+int(learning.data.practice.listen)+int(learning.data.dev_context.read)+int(learning.data.dev_context.listen)
func previewable(id:String)->bool:
	if available(id):return true
	var c=chapter(id)
	if not c.has("gate"):return false
	for dependency in c.requires:
		if not done(dependency):return false
	return true
func unlock_hint(id:String)->String:
	var c=chapter(id)
	if not c.has("gate"):return ""
	var label={"wood":"木料采集","stone":"石料采集","explore":"阅读与听力"}[c.gate]
	return str(label)+" "+str(gate_count(c.gate))+" / "+str(c.threshold)+" · "+str(c.title)
func site(id:String)->int:return BUILD_IDS.find(id) if id in BUILD_IDS else int(chapter(id).get("site",0))
func target(id:String)->Vector2:
	if id=="rocket":return point(ROCKET_CELLS[0])
	return point(BUILD_CELLS[BUILD_IDS.find(id)]) if id in BUILD_IDS else point(chapter(id).point)
func progress(id:String)->Vector2:
	if id=="rocket":return Vector2(TRADE_PRICE if rocket_open() else data.voyage.paid,TRADE_PRICE)
	var result:Vector2
	if id in BUILD_IDS:result=learning.progress(site(id))
	else:
		var c=chapter(id);result=Vector2(data.progress[id],c.need)
	if not done(id):result.x+=float(data.effort.get(id,0))
	return result
func title(id:String)->String:
	if id=="rocket":return "远航火箭" if rocket_open() else "海怪的泊位"
	if id in BUILD_IDS:
		var i=site(id);return IslandLearning.STEPS[i][learning.stage(i)] if not done(id) else IslandLearning.PROJECTS[i]+" · 自由照料"
	return str(chapter(id).title)
func mode()->String:return IslandLearning.MODES[int(data.turns.get(data.active,0))%6]
func choose(id:String)->bool:
	if id=="rocket" or not available(id):return false
	data.active=id;learning.select_site(site(id));return true
func advance()->Dictionary:
	var id=str(data.active);data.effort[id]=0.0;data.turns[id]=int(data.turns.get(id,0))+1
	if id in BUILD_IDS:return learning.advance()
	var c=chapter(id);var old=int(data.progress[id]);data.progress[id]=mini(c.need,old+1)
	learning.data.actions+=1
	return {"complete":old<c.need and data.progress[id]==c.need,"project":site(id),"fraction":float(data.progress[id])/c.need}
func content_units()->int:
	var total=IslandLearning.EXTRA*3
	for need in IslandLearning.NEEDS:total+=need
	for c in CHAPTERS:total+=c.need
	return total
func finished_units()->int:
	var total=0
	for i in range(3):total+=int(learning.data.build[i])+int(learning.data.development[i])
	for c in CHAPTERS:total+=int(data.progress[c.id])
	return total
func refresh_plan():
	var plan=learning.data.study_plan;var capacity=content_units();var book=str(learning.data.book_id)
	var saved_capacity=plan.get("capacity",0);var saved_quota=plan.get("quota",0)
	var valid=(saved_capacity is int or saved_capacity is float) and (saved_quota is int or saved_quota is float)
	valid=valid and is_finite(float(saved_capacity)) and is_finite(float(saved_quota)) and float(saved_quota)>=1 and float(saved_quota)<=48
	if not valid or plan.get("book","")!=book or int(saved_capacity)!=capacity:
		var remaining=maxi(1,capacity-finished_units());var words=learning.book_remaining()
		# Three of six recurring tasks are words; approximate book coverage without
		# demanding hundreds of repetitions for the last unfinished structure.
		var quota=clampi(int(ceil(float(words)*2.0/remaining)),1,48) if not book.is_empty() else 1
		learning.data.study_plan={"book":book,"capacity":capacity,"quota":quota,"planned_words":words,"planned_steps":remaining}
	else:learning.data.study_plan.quota=int(saved_quota)
func study_quota(id:String="")->int:
	refresh_plan()
	if done(str(data.active) if id.is_empty() else id):return 1
	# A new landing shows the first visible changes promptly. Completed work is
	# never reset when books change or later content adds more destinations.
	if finished_units()<3:return mini(2,int(learning.data.study_plan.quota))
	# Ease into the selected book instead of jumping from two exercises to dozens.
	var target=int(learning.data.study_plan.quota)
	var introduction=clampf(float(finished_units()-3)/15.0,0.0,1.0)
	return maxi(1,roundi(lerpf(float(mini(2,target)),float(target),smoothstep(0.0,1.0,introduction))))
func study_advance()->Dictionary:
	var id=str(data.active);var quota=study_quota(id)
	var part=float(data.effort.get(id,0))+1.0/quota
	if done(id):return advance()
	if part>=1.0-.000001:
		var result=advance()
		if not done(id):data.effort[id]=maxf(0,part-1.0)
		return result
	data.effort[id]=part;data.turns[id]=int(data.turns.get(id,0))+1;learning.data.actions+=1
	if id in BUILD_IDS:learning.data.work_turns[site(id)]+=1
	var fraction=float(learning.data.build[site(id)])/IslandLearning.NEEDS[site(id)] if id in BUILD_IDS else float(data.progress[id])/chapter(id).need
	return {"complete":false,"project":site(id),"fraction":fraction,"unit_progress":part,"word_quota":quota}
func finish_for_development(everything=false)->int:
	var before=finished_units();var targets=BUILD_IDS.duplicate() if everything else [str(data.active)]
	if everything:
		data.voyage.dev_open=true
		for c in CHAPTERS:targets.append(c.id)
	for id in targets:
		if id in BUILD_IDS:
			var index=site(id);learning.data.build[index]=IslandLearning.NEEDS[index];learning.data.development[index]=IslandLearning.EXTRA
		else:data.progress[id]=chapter(id).need
		data.effort[id]=0.0
	var advanced=finished_units()-before
	learning.data.dev_steps+=advanced;learning.data.actions+=advanced
	return advanced
func cells()->Array:
	var result=START.duplicate()
	result.append_array(ROCKET_CELLS)
	for c in CHAPTERS:
		var count=int(floor(float(data.progress[c.id])*3/c.need))
		for i in range(count):
			if not result.has(c.cells[i]):result.append(c.cells[i])
	# A retained windmill or garden still needs its foundation if its
	# supporting terrain project is selected for a developer rebuild.
	for i in BUILD_CELLS.size():
		if learning.data.build[i]>0 and not result.has(BUILD_CELLS[i]):result.append(BUILD_CELLS[i])
	return result
func finished_count()->int:
	var count=0
	for c in CHAPTERS:
		if done(c.id):count+=1
	return count

func rewind_building(all_sites:bool):
	var active=str(data.active)
	if all_sites:
		learning.data.build=[0,0,0];learning.data.development=[0,0,0]
		learning.data.work_turns=[0,0,0];learning.data.harvested=[0,0]
		learning.data.dev_context={"read":0,"listen":0}
		learning.data.dev_steps=0;learning.data.actions=0
		for c in CHAPTERS:data.progress[c.id]=0
		for key in ["effort","turns","production","deliveries"]:data[key].clear()
		data.voyage={"ore":0,"coins":0,"paid":0,"dev_open":false,"earned_book":""}
		choose("grove")
	else:
		if active in BUILD_IDS:
			var i=site(active)
			learning.data.build[i]=0;learning.data.development[i]=0;learning.data.work_turns[i]=0
		else:data.progress[active]=0
		data.effort[active]=0.0;data.turns[active]=0
		if not available(active):choose("grove")
	learning.data.study_plan.clear();refresh_plan()

func work_route(id:String="")->Dictionary:
	if id.is_empty():id=str(data.active)
	if id=="goldmine" and done(id):
		return gold_batch("mine",id,"goldmine")
	if id=="smelter" and done(id):
		if data.voyage.ore==0:return gold_batch("mine",id,"goldmine")
		return gold_batch("mint",id,"smelter")
	var sources=[]
	if done(id) and PRODUCTION.has(id):sources=[id]
	else:
		for source in RECIPES.get(id,[]):
			if done(source):sources.append(source)
	if sources.is_empty():sources=["quarry" if site(id)==1 and done("quarry") else "grove"]
	var source=str(sources[int(data.turns.get(id,0))%sources.size()])
	var spec=PRODUCTION[source]
	var raw_source={"sawmill":"grove","kiln":"quarry","mountain":"crystal","shipyard":"grove"}.get(source,source)
	var processors=["crystal","mountain"] if source=="mountain" else ["sawmill","shipyard"] if source=="shipyard" else [source]
	var raw="crystal" if source=="mountain" else "timber" if source=="shipyard" else str(spec.raw)
	return {"source":raw_source,"processor":source,"processors":processors,"destination":id,"raw":raw,"product":spec.product,"name":spec.name,"tool":spec.tool}

func record_delivery(route:Dictionary):
	# Only a completed learning/developer action creates an actual production batch.
	# Idle workers and visual machinery never call this method.
	for processor in route.processors:
		var key=str(processor)+":"+str(PRODUCTION[processor].product)
		data.production[key]=int(data.production.get(key,0))+1
	var destination=str(route.destination)+":"+str(route.product)
	data.deliveries[destination]=int(data.deliveries.get(destination,0))+1
	if route.get("batch")=="mine":
		data.voyage.ore+=1
	elif route.get("batch")=="mint" and data.voyage.ore>0:
		data.voyage.ore-=1
		data.voyage.coins+=2

func gold_batch(kind:String,id:String,source:String)->Dictionary:
	var mine=kind=="mine"
	# With an empty hopper the first task supplies ore. Only the next cast spends it.
	return {"batch":kind,"source":source,"processor":source,"processors":[source],
		"destination":id,"raw":"gold_ore","product":"gold_ore" if mine else "gold_coin",
		"name":"运矿入炉" if mine and id=="smelter" else "采金" if mine else "熔金铸币","tool":1}

func rocket_open()->bool:
	return data.voyage.dev_open or not str(data.voyage.earned_book).is_empty()

func offer_amount()->int:
	return mini(TRADE_BAG,mini(int(data.voyage.coins),TRADE_PRICE-int(data.voyage.paid)))

func offer_gold()->int:
	var amount=offer_amount()
	if not done("smelter") or rocket_open() or amount<=0:return 0
	data.voyage.coins-=amount
	data.voyage.paid+=amount
	return amount

func try_unlock_rocket()->bool:
	if not str(data.voyage.earned_book).is_empty() or data.voyage.paid<TRADE_PRICE:return false
	var book=learning.current_book()
	if book.is_empty() or book.words.is_empty() or learning.book_remaining()!=0:return false
	data.voyage.earned_book=book.id
	return true

func facility_title(id:String)->String:
	return {"quarry":"石岸切石场","wetland":"浅湾织帆屋","plateau":"高原锻造台","crystal":"晶湾磨镜台","mountain":"云杉观星台","hill":"山风取水泵","meadow":"果粮采收园"}.get(id,title(id))
