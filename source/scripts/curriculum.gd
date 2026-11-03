extends RefCounted
class_name IslandCurriculum

const MODES=["read","listen","sentence"]
const BOOK_BAND={"primary":0,"junior":1,"senior":2,"cet4":2,"cet6":3,"tem8":3}
const RECENT_LIMIT=7
var pool:Array=[]
var by_id:Dictionary={}
var word_cache:Dictionary={}
var level:Dictionary={}
var theme:Dictionary={}

func _init():
	var tokens=RegEx.new()
	tokens.compile("[a-z]+(?:'[a-z]+)?")
	for collection in ["missions","frontier_missions","reader_missions"]:
		var entries=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+collection+".json"))
		for entry in entries:
			pool.append(entry)
			by_id[entry.id]=entry
			var words=[]
			for token in tokens.search_all(str(entry.short).to_lower()):
				var word=token.get_string()
				if not words.has(word):words.append(word)
			word_cache[entry.id]=words
			level[entry.id]=entry.get("band",int(str(entry.id).right(2))%4 if collection=="missions" else 1)
			theme[entry.id]=entry.get("topic",["木工","石艺","花园"][clampi(int(entry.get("site",0)),0,2)])

func target_band(learning:IslandLearning)->int:
	return mini(learning.data.band,int(BOOK_BAND.get(learning.data.book_id,1)))

func short_first(learning:IslandLearning,entry:Dictionary)->bool:
	var target=target_band(learning)
	return target<2 or level[entry.id]>target

func _state(learning:IslandLearning)->Dictionary:
	var state:Dictionary=learning.data.lesson_schedule
	if not state.get("pending") is Dictionary:
		state.pending={}
		# Saves from before global scheduling can still contain unfinished hints.
		for note in pool:
			for mode in MODES:
				if learning.data.context_help.get(note.id+"_"+mode,false) and not state.pending.has(mode):
					state.pending[mode]=note.id
	if not state.get("recent") is Array:state.recent=[]
	if not state.get("shown") is Dictionary:state.shown={}
	while state.recent.size()>RECENT_LIMIT:state.recent.pop_front()
	if not (state.get("cursor") is int or state.get("cursor") is float):state.cursor=0
	state.cursor=posmod(int(state.cursor),pool.size())
	return state

func _pick(learning:IslandLearning,mode:String,state:Dictionary)->Dictionary:
	var best:Dictionary={}
	var best_score=-INF
	var target=target_band(learning)
	var last_theme=theme.get(state.recent.back(),"") if not state.recent.is_empty() else ""
	for offset in range(pool.size()):
		var entry:Dictionary=pool[(int(state.cursor)+offset)%pool.size()]
		if state.recent.has(entry.id) or state.pending.values().has(entry.id):continue
		var key=str(entry.id)+"_"+mode
		var completions=int(learning.data.contexts.get(key,{}).get("completed",0))
		var shown=state.shown.get(key,completions)
		if not (shown is int or shown is float):shown=completions
		var familiar=0
		for word in word_cache[entry.id]:
			if int(learning.data.words.get(word,{}).get("correct",0))>0:familiar+=1
		# A complete cycle of fresh material wins over a second attempt. Within
		# that cycle, begin near the chosen level, with different subject matter.
		var score=-10.0*maxi(0,int(shown))-1.4*absi(int(level[entry.id])-target)
		score+=1.4 if theme[entry.id]!=last_theme else 0.0
		if entry.has("topic"):score+=.35
		score+=float(familiar)/maxi(1,word_cache[entry.id].size())
		if score>best_score:
			best_score=score
			best=entry
	return best

func _pending(state:Dictionary,mode:String)->Dictionary:
	return by_id.get(state.pending.get(mode,""),{})

func preview(learning:IslandLearning)->Dictionary:
	var state=_state(learning)
	var pending=_pending(state,"read")
	return pending if not pending.is_empty() else _pick(learning,"read",state)

func next(learning:IslandLearning,mode:String)->Dictionary:
	var state=_state(learning)
	var entry=_pending(state,mode)
	if not entry.is_empty():return entry
	entry=_pick(learning,mode,state)
	state.pending[mode]=entry.id
	var key=str(entry.id)+"_"+mode
	var count=state.shown.get(key,learning.data.contexts.get(key,{}).get("completed",0))
	state.shown[key]=maxi(0,int(count))+1 if count is int or count is float else 1
	state.recent.append(entry.id)
	if state.recent.size()>RECENT_LIMIT:state.recent.pop_front()
	state.cursor=(pool.find(entry)+1)%pool.size()
	return entry

func release(learning:IslandLearning,mode:String,id:String):
	var state=_state(learning)
	if state.pending.get(mode,"")==id:state.pending.erase(mode)
