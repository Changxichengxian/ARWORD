extends RefCounted
class_name IslandLearning

const NEEDS=[8,12,16]
var bank:Array=[]
var by_id={}
var recent:Array=[]
var rng=RandomNumberGenerator.new()
var data={"version":4,"build":[0,0,0],"active":0,"actions":0,"band":1,"words":{},"flags":{},"sound":true,"speech":false,"listen":false,"bookmarks":{},"help_pending":"","success_run":0,"miss_run":0}

func _init():
	rng.randomize()
	bank=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vocabulary.json"))
	for q in bank:by_id[q.id]=q

func accept_save(candidate)->bool:
	if not candidate is Dictionary or candidate.get("version",0)!=4:return false
	if not candidate.get("build") is Array or candidate.build.size()!=3:return false
	for i in range(3):
		if not (candidate.build[i] is int or candidate.build[i] is float):return false
	for k in data:
		if candidate.has(k) and typeof(candidate[k])==typeof(data[k]):data[k]=candidate[k]
	for k in ["active","actions","band","success_run","miss_run"]:
		if candidate.get(k) is int or candidate.get(k) is float:data[k]=maxi(0,int(candidate[k]))
	for i in range(3):data.build[i]=clampi(int(candidate.build[i]),0,NEEDS[i])
	data.active=clampi(data.active,0,2);data.band=clampi(data.band,0,3)
	for id in data.words.keys():
		var s=data.words[id]
		if not by_id.has(id) or not s is Dictionary:data.words.erase(id);continue
		for k in ["seen","correct","strength","last","due","helped"]:
			if not (s.get(k) is int or s.get(k) is float):s[k]=0
	return true

func next_word(now:float)->Dictionary:
	if by_id.has(data.help_pending):return by_id[data.help_pending]
	var due=[];var fresh=[];var other=[]
	for q in bank:
		var s=data.words.get(q.id,{})
		if not s.is_empty() and float(s.get("due",0))<=now and not recent.has(q.id):due.append(q)
		elif s.is_empty() and absi(int(q.band)-data.band)==0:fresh.append(q)
		elif s.is_empty():other.append(q)
	var result={}
	if not due.is_empty():
		due.sort_custom(func(a,b):return data.words[a.id].due<data.words[b.id].due);result=due[0]
	elif not fresh.is_empty():result=fresh[rng.randi_range(0,fresh.size()-1)]
	elif not other.is_empty():
		other.sort_custom(func(a,b):return absi(a.band-data.band)<absi(b.band-data.band));result=other[0]
	else:
		var pool=bank.filter(func(q):return not recent.has(q.id))
		pool.sort_custom(func(a,b):return data.words[a.id].due<data.words[b.id].due)
		result=pool[0] if not pool.is_empty() else bank[0]
	recent.append(result.id)
	if recent.size()>8:recent.pop_front()
	return result

func mark_help(id:String):data.help_pending=id

func record(id:String,helped:bool,now:float)->Dictionary:
	var s=data.words.get(id,{"seen":0,"correct":0,"strength":0,"last":0,"due":0,"helped":0})
	helped=helped or data.help_pending==id
	var spaced=now-float(s.last)>=120
	s.seen+=1
	if helped:
		s.helped+=1;s.strength=0;s.due=now+120;data.success_run=0;data.miss_run+=1
		if data.miss_run>=2:data.band=maxi(0,data.band-1);data.miss_run=0
	else:
		s.correct+=1
		if spaced:s.strength=mini(5,int(s.strength)+1)
		var gaps=[120,14400,86400,259200,604800,1209600]
		s.due=maxf(float(s.due),now+gaps[int(s.strength)]);data.miss_run=0;data.success_run+=1
		if data.success_run>=4:data.band=mini(3,data.band+1);data.success_run=0
	s.last=now;data.words[id]=s;data.help_pending=""
	var active=int(data.active);var complete=false
	if int(data.build[active])<NEEDS[active]:
		data.build[active]=int(data.build[active])+1;complete=int(data.build[active])==NEEDS[active]
	data.actions+=1
	return {"helped":helped,"complete":complete,"project":active,"fraction":float(data.build[active])/NEEDS[active]}

func completed()->bool:return int(data.build[2])>=NEEDS[2]
func independent_count()->int:
	var count=0
	for s in data.words.values():
		if int(s.get("correct",0))>0:count+=1
	return count
func next_project():
	if data.active<2 and int(data.build[data.active])>=NEEDS[data.active]:data.active+=1
