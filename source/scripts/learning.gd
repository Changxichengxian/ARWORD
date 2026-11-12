extends RefCounted
class_name IslandLearning

const NEEDS=[8,12,16]
const EXTRA=36
const MODES=["word","word","read","word","listen","sentence"]
const CONTEXT_MODES=["read","listen","sentence"]
const PROJECTS=["木屋","风车","花园"]
const DEFAULT_BLACK_HOLE=true
const SPACE_DEFAULTS={"nebula":1.45,"color":1.3,"band":1.15,"stars":1.1,"drift":1.0}
const SPACE_LIMITS={"nebula":Vector2(0,2.5),"color":Vector2(0,2),"band":Vector2(.4,2),"stars":Vector2(.3,2),"drift":Vector2(0,2)}
const STEPS=[["搭好木屋","沿岸栈道","门前长椅","伙伴的营地"],["让风车转起来","蓄水装置","引水小渠","检修工作台"],["种下第一床","果树小园","木栅栏","蜜蜂的小屋"]]
var bank:Array=[]
var by_id={}
var recent:Array=[]
var rng=RandomNumberGenerator.new()
var wordbooks=preload("res://scripts/wordbooks.gd").new()
var active_bank:Array=[]
var data={"version":4,"build":[0,0,0],"active":0,"actions":0,"band":1,"words":{},"flags":{},"sound":true,"music":true,"dev_skip":true,"dev_steps":0,"dev_context":{"read":0,"listen":0},"speech":false,"listen":false,"bookmarks":{},"help_pending":"","success_run":0,"miss_run":0,"development":[0,0,0],"work_turns":[0,0,0],"harvested":[0,0],"practice":{"read":0,"listen":0,"sentence":0},"contexts":{},"context_help":{},"frontier":{}}

func _init():
	data["feiyu_voice"]=false
	data["voice_choice_version"]=1
	data["space_settings"]=SPACE_DEFAULTS.duplicate()
	data["lesson_schedule"]={}
	data["word_turn"]=0
	data["practice_modes"]={}
	data["black_hole"]=DEFAULT_BLACK_HOLE
	data["sky_default_version"]=1
	data["book_id"]=wordbooks.default_id();data["study_plan"]={};data["pending_help"]={}
	rng.randomize()
	bank=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vocabulary.json"))
	for q in bank:
		# Share the reviewed answer with lookup and wordbooks, keeping authored audio/examples.
		if wordbooks.entries.has(q.id):
			var full=wordbooks.entries[q.id]
			for key in ["zh","pos","definition","options","correct","meaning_source"]:q[key]=full[key]
		by_id[q.id]=q
	for id in wordbooks.entries:
		if not by_id.has(id):by_id[id]=wordbooks.entries[id]
	refresh_book()

func refresh_book():
	if not str(data.help_pending).is_empty():data.pending_help[data.help_pending]=true
	active_bank=[]
	var book=wordbooks.find(str(data.book_id))
	if book.is_empty():
		data.book_id=wordbooks.default_id();book=wordbooks.find(str(data.book_id))
	if book.is_empty():active_bank=bank.duplicate()
	else:
		for id in book.words:active_bank.append(by_id[id])
	data.help_pending=""
	for q in active_bank:
		if data.pending_help.has(q.id):data.help_pending=q.id;break
	recent.clear()
func select_book(id:String)->bool:
	if wordbooks.find(id).is_empty():return false
	data.book_id=id;data.study_plan={};refresh_book();return true
func current_book()->Dictionary:return wordbooks.find(str(data.book_id))
func book_independent(id:String="")->int:
	var book=wordbooks.find(id if not id.is_empty() else str(data.book_id));var count=0
	for word in book.get("words",[]):
		if int(data.words.get(word,{}).get("correct",0))>0:count+=1
	return count
func book_remaining()->int:
	var book=current_book();return maxi(0,book.get("words",[]).size()-book_independent())

func accept_save(candidate)->bool:
	if not candidate is Dictionary or candidate.get("version",0)!=4:return false
	if not candidate.get("build") is Array or candidate.build.size()!=3:return false
	for i in range(3):
		if not (candidate.build[i] is int or candidate.build[i] is float):return false
	for k in data:
		if candidate.has(k) and typeof(candidate[k])==typeof(data[k]):data[k]=candidate[k]
	# Earlier saves wrote the old default even when the sky setting had never been opened.
	if not candidate.has("voice_choice_version"):data.feiyu_voice=false
	if not candidate.has("sky_default_version"):data.black_hole=DEFAULT_BLACK_HOLE
	for k in ["active","actions","band","success_run","miss_run","dev_steps","word_turn"]:
		if candidate.get(k) is int or candidate.get(k) is float:data[k]=maxi(0,int(candidate[k]))
	var preferences=candidate.get("practice_modes",{})
	data.practice_modes={}
	if preferences is Dictionary:
		for mode in CONTEXT_MODES:
			if preferences.get(mode) is bool and preferences[mode]:data.practice_modes[mode]=true
	for i in range(3):data.build[i]=clampi(int(candidate.build[i]),0,NEEDS[i])
	data.active=clampi(data.active,0,2);data.band=clampi(data.band,0,3)
	for key in ["development","work_turns"]:
		if data[key].size()!=3:data[key]=[0,0,0]
		for i in range(3):
			data[key][i]=clampi(int(data[key][i]),0,EXTRA if key=="development" else 1000000) if data[key][i] is int or data[key][i] is float else 0
	for mode in ["read","listen","sentence"]:data.practice[mode]=maxi(0,int(data.practice.get(mode,0))) if data.practice.get(mode,0) is int or data.practice.get(mode,0) is float else 0
	for mode in ["read","listen"]:data.dev_context[mode]=maxi(0,int(data.dev_context.get(mode,0))) if data.dev_context.get(mode,0) is int or data.dev_context.get(mode,0) is float else 0
	var space={}
	for key in SPACE_DEFAULTS:
		var value=data.space_settings.get(key,SPACE_DEFAULTS[key]);var limits=SPACE_LIMITS[key]
		space[key]=clampf(float(value),limits.x,limits.y) if (value is int or value is float) and is_finite(float(value)) else SPACE_DEFAULTS[key]
	data.space_settings=space
	if data.harvested.size()!=2:data.harvested=[0,0]
	for i in range(2):data.harvested[i]=maxi(0,int(data.harvested[i])) if data.harvested[i] is int or data.harvested[i] is float else 0
	for key in data.contexts.keys():
		var entry=data.contexts[key]
		if not entry is Dictionary:data.contexts.erase(key);continue
		for field in ["completed","assisted"]:entry[field]=maxi(0,int(entry.get(field,0))) if entry.get(field,0) is int or entry.get(field,0) is float else 0
	for id in data.words.keys():
		var s=data.words[id]
		if not by_id.has(id) or not s is Dictionary:data.words.erase(id);continue
		for k in ["seen","correct","strength","last","due","helped"]:
			if not (s.get(k) is int or s.get(k) is float):s[k]=0
	refresh_book()
	return true

func next_word(now:float,focus:Array=[],allow_early_spot_check=false)->Dictionary:
	if by_id.has(data.help_pending) and (data.book_id.is_empty() or wordbooks.contains(data.book_id,data.help_pending)):return by_id[data.help_pending]
	var due:Dictionary={};var due_time=INF
	var fresh=[];var other:Dictionary={};var other_gap=INF
	var queued={};var first_turn=INF
	var waiting={};var waiting_turn=INF
	for q in active_bank:
		var s=data.words.get(q.id,{})
		if s.get("mastered",false):continue
		if s.has("review_at"):
			var at=int(s.review_at)
			if s.has("spot_hits") and at>data.word_turn:
				if allow_early_spot_check and at<waiting_turn:waiting=q;waiting_turn=at
				continue
			if at<first_turn:queued=q;first_turn=at
		elif not s.is_empty() and float(s.get("due",0))<=now and not recent.has(q.id):
			var at=float(s.get("due",0))
			if due.is_empty() or at<due_time:due=q;due_time=at
		elif s.is_empty() and absi(int(q.band)-data.band)==0:fresh.append(q)
		elif s.is_empty():
			var gap=absi(int(q.band)-data.band)
			if other.is_empty() or gap<other_gap:other=q;other_gap=gap
	var result={}
	if not due.is_empty() and int(data.word_turn)%4==0:
		result=due
	elif not queued.is_empty() and (first_turn<=data.word_turn or (fresh.is_empty() and other.is_empty())):
		result=queued
	elif not due.is_empty() and fresh.is_empty() and other.is_empty():
		result=due
	elif not focus.is_empty():
		var targets=[]
		for id in focus:
			if by_id.has(id) and (data.book_id.is_empty() or wordbooks.contains(data.book_id,id)) and not recent.has(id) and not data.words.has(id) and int(by_id[id].band)<=data.band+1:targets.append(by_id[id])
		if not targets.is_empty():result=targets[rng.randi_range(0,targets.size()-1)]
	if result.is_empty() and not fresh.is_empty():result=fresh[rng.randi_range(0,fresh.size()-1)]
	elif result.is_empty() and not other.is_empty():
		result=other
	elif result.is_empty():
		# Only one result is needed. Keep the earliest eligible review without
		# allocating two filtered copies and sorting the whole book.
		var earliest:Dictionary={};var earliest_time=INF
		var varied:Dictionary={};var varied_time=INF
		for q in active_bank:
			var s=data.words.get(q.id,{})
			if s.get("mastered",false) or s.has("spot_hits"):continue
			var at=float(s.get("due",0))
			if earliest.is_empty() or at<earliest_time:earliest=q;earliest_time=at
			if not recent.has(q.id) and (varied.is_empty() or at<varied_time):varied=q;varied_time=at
		result=varied if not varied.is_empty() else earliest
		if result.is_empty():result=waiting
		if result.is_empty():return {}
	recent.append(result.id)
	if recent.size()>8:recent.pop_front()
	return result

func needs_intro(id:String)->bool:
	return not data.words.has(id) and not data.pending_help.has(id)

func introduce(id:String,already_known=false):
	if not by_id.has(id) or not needs_intro(id):return
	data.word_turn+=1
	data.words[id]={"seen":0,"correct":0,"strength":0,"last":0,"due":0,"helped":0,
		"review_round":0,"review_at":data.word_turn+1}
	if already_known:
		var s=data.words[id]
		s.erase("review_round")
		s.spot_hits=0
		s.review_at=data.word_turn+rng.randi_range(4,8)

func mark_help(id:String):data.help_pending=id;data.pending_help[id]=true

func record(id:String,helped:bool,now:float,advance_build=true,harvest_kind=-1)->Dictionary:
	var s=data.words.get(id,{"seen":0,"correct":0,"strength":0,"last":0,"due":0,"helped":0})
	helped=helped or data.help_pending==id or data.pending_help.has(id)
	var spaced=now-float(s.last)>=120
	s.seen+=1
	if helped:
		s.helped+=1;s.strength=0;s.due=now+120;data.success_run=0;data.miss_run+=1
		if data.miss_run>=2:data.band=maxi(0,data.band-1);data.miss_run=0
	else:
		s.correct+=1
		if spaced:s.strength=mini(5,int(s.strength)+1)
		var gaps=[120,120,600,14400,86400,259200]
		s.due=maxf(float(s.due),now+gaps[int(s.strength)]);data.miss_run=0;data.success_run+=1
		if data.success_run>=4:data.band=mini(3,data.band+1);data.success_run=0
	data.word_turn+=1
	if s.has("spot_hits"):
		s.spot_hits=0 if helped else int(s.spot_hits)+1
		if s.spot_hits==2:
			s.mastered=true
			s.erase("spot_hits")
			s.erase("review_at")
		else:s.review_at=data.word_turn+(rng.randi_range(2,4) if helped else rng.randi_range(10,18))
	elif s.has("review_round") or helped:
		s.erase("mastered")
		var round_done=0 if helped else mini(3,int(s.get("review_round",0))+1)
		s.review_round=round_done
		if round_done<3:s.review_at=data.word_turn+[1,2,5][round_done]
		else:
			s.erase("review_at")
			s.due=maxf(float(s.due),now+86400.)
	s.last=now;data.words[id]=s;data.pending_help.erase(id)
	if data.help_pending==id:data.help_pending=""
	data.harvested[harvest_kind if harvest_kind>=0 else (1 if data.active==1 else 0)]+=1
	return advance() if advance_build else {}

func advance()->Dictionary:
	var active=int(data.active);var complete=false;var upgrade=false
	if int(data.build[active])<NEEDS[active]:
		data.build[active]=int(data.build[active])+1;complete=int(data.build[active])==NEEDS[active]
	elif int(data.development[active])<EXTRA:
		data.development[active]+=1;upgrade=int(data.development[active])%12==0
	data.actions+=1
	data.work_turns[active]+=1
	return {"complete":complete or upgrade,"project":active,"fraction":float(data.build[active])/NEEDS[active]}

func finish_context(mode:String,id:String,assisted:bool,advance_build=true)->Dictionary:
	data.practice[mode]=int(data.practice.get(mode,0))+1
	var key=id+"_"+mode;var old=data.contexts.get(key,{"completed":0,"assisted":0})
	old.completed+=1
	if assisted:old.assisted+=1
	data.contexts[key]=old
	return advance() if advance_build else {}

func context_modes()->Array:
	return CONTEXT_MODES.filter(func(mode):return data.practice_modes.get(mode,false))
func practice_at(turn:int)->String:
	var cycle=MODES.filter(func(mode):return mode=="word" or data.practice_modes.get(mode,false))
	return cycle[turn%cycle.size()]
func mode()->String:return practice_at(int(data.work_turns[data.active]))
func note_index()->int:return int(data.active)*4+(int(data.work_turns[data.active])/6)%4
func stage(site:int)->int:
	if int(data.build[site])<NEEDS[site]:return 0
	return mini(3,1+int(data.development[site])/12)
func progress(site:int)->Vector2:
	if int(data.build[site])<NEEDS[site]:return Vector2(data.build[site],NEEDS[site])
	if int(data.development[site])>=EXTRA:return Vector2(12,12)
	return Vector2(int(data.development[site])%12,12)
func site_done(site:int)->bool:return int(data.build[site])>=NEEDS[site] and int(data.development[site])>=EXTRA
func all_done()->bool:return site_done(0) and site_done(1) and site_done(2)
func select_site(site:int):data.active=clampi(site,0,2)

func completed()->bool:return int(data.build[2])>=NEEDS[2]
func independent_count()->int:
	var count=0
	for s in data.words.values():
		if int(s.get("correct",0))>0:count+=1
	return count
func next_project():
	pass # Work sites are selected by the player; never advance to another site automatically.
