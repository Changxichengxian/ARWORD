extends SceneTree

const Curriculum=preload("res://scripts/curriculum.gd")
var failures=0

func check(ok:bool,label:String):
	if ok:print("PASS ",label)
	else:
		push_error(label)
		failures+=1

func _initialize():call_deferred("run")
func run():
	if not "--qa" in OS.get_cmdline_user_args():
		quit(2)
		return
	var course=Curriculum.new()
	var learner=IslandLearning.new()
	var independent=learner.data.words.duplicate(true)
	var first=course.next(learner,"read")
	check(first.has("topic"),"first reading can be unrelated to work")
	var pending_key=first.id+"_read"
	learner.data.context_help[pending_key]=true
	for site in [2,1,0]:
		learner.select_site(site)
		check(course.next(learner,"read").id==first.id,"switching work preserves the open reading")
	var restart=IslandLearning.new()
	restart.accept_save(JSON.parse_string(JSON.stringify(learner.data)))
	check(course.next(restart,"read").id==first.id and restart.data.context_help[pending_key],"reopen preserves the precise reading and its assistance")
	check(course.next(restart,"listen").id!=first.id,"another practice mode has its own assignment")
	var old=learner.data.duplicate(true)
	old.erase("lesson_schedule")
	var migrated=IslandLearning.new()
	migrated.accept_save(old)
	check(course.next(migrated,"read").id==first.id,"unfinished prompt from an older save restored")
	var state_before=JSON.stringify(learner.data.lesson_schedule)
	course.preview(learner)
	check(state_before==JSON.stringify(learner.data.lesson_schedule),"reading for pleasure does not consume another task")
	for mode in ["read","listen","sentence"]:
		var seen={}
		for i in range(course.pool.size()):
			var entry=course.next(learner,mode)
			seen[entry.id]=true
			course.release(learner,mode,entry.id)
		check(seen.size()==course.pool.size(),mode+" can visit every passage at the same site")
	check(learner.data.contexts.is_empty() and learner.data.words==independent and learner.data.practice=={"read":0,"listen":0,"sentence":0},"browsing or skipping does not award English credit")
	var easy=IslandLearning.new()
	easy.select_book("primary");easy.data.band=3
	check(course.target_band(easy)==0 and course.short_first(easy,course.next(easy,"read")),"early wordbook starts with short passages")
	var advanced=IslandLearning.new()
	advanced.select_book("tem8");advanced.data.band=3
	check(course.next(advanced,"read").band==3,"advanced setting reaches a challenging non-work topic")
	print("CURRICULUM_RESULT ",failures," failed; ",course.pool.size()," articles")
	quit(1 if failures else 0)
