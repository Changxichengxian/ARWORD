extends SceneTree
var passed=0
var failed=0
func check(ok:bool,label:String):
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func _initialize():call_deferred("run")
func run():
	var learning=IslandLearning.new()
	check(learning.wordbooks.books.size()==6 and learning.wordbooks.entries.size()==10696,"six reference books share normalized word records")
	var membership_ok=true
	for book in learning.wordbooks.books:
		learning.select_book(book.id)
		for n in range(60):
			var q=learning.next_word(10000+n,["repair","retain","a","photosynthesis"])
			if not learning.wordbooks.contains(book.id,q.id):membership_ok=false
			learning.record(q.id,false,10000+n,false);learning.data.actions+=1
	check(membership_ok,"each book keeps fresh words reviews and contextual focus inside its membership")
	learning=IslandLearning.new();learning.select_book("primary")
	var common=""
	for id in learning.current_book().words:
		if learning.wordbooks.contains("junior",id):common=id;break
	learning.record(common,false,1000,false)
	var old=learning.data.words[common].duplicate(true)
	learning.select_book("junior")
	check(learning.data.words[common]==old and learning.book_independent()==1,"changing books keeps the same word history and counts it once")
	var specific=""
	for id in learning.wordbooks.find("senior").words:
		if not learning.wordbooks.contains("primary",id):specific=id;break
	learning.select_book("senior");learning.mark_help(specific);learning.select_book("primary")
	check(learning.next_word(1000).id!=specific and learning.data.pending_help.has(specific),"an unfinished hint is retained without leaking into another book")
	var restored=IslandLearning.new();restored.accept_save(JSON.parse_string(JSON.stringify(learning.data)));restored.select_book("senior")
	check(restored.next_word(1000).id==specific,"returning to a book after reloading resumes its unfinished hint")
	restored.record(specific,false,2000,false)
	check(restored.data.words[specific].correct==0 and restored.data.words[specific].helped==1,"book switching cannot turn a hinted answer into independent recall")
	var frontier=IslandFrontier.new(learning)
	var cadence=[]
	for n in range(6):cadence.append(frontier.mode());frontier.study_advance()
	check(cadence==IslandLearning.MODES and frontier.data.progress.grove==3,"partial construction keeps reading listening and sentence cadence")
	frontier.data.effort.grove=.37
	var old_total=frontier.finished_units();learning.select_book("tem8");frontier.refresh_plan()
	check(frontier.data.effort.grove==.37 and frontier.finished_units()==old_total,"changing book quota preserves completed and fractional construction")
	var quota=frontier.study_quota();frontier.study_advance()
	check(is_equal_approx(float(frontier.data.effort.grove),.37+1.0/quota),"every successful exercise makes visible fractional progress")
	var saved_fraction=frontier.data.effort.grove
	restored=IslandLearning.new();restored.accept_save(JSON.parse_string(JSON.stringify(learning.data)))
	var reloaded=IslandFrontier.new(restored)
	check(is_equal_approx(reloaded.data.effort.grove,saved_fraction) and reloaded.study_quota()==quota,"JSON save retains fractions and stable quota")
	var earlier=IslandFrontier.new(IslandLearning.new());earlier.data.progress.grove=2;earlier.data.effort.grove=.9;earlier.study_advance()
	check(earlier.data.progress.grove==3 and is_equal_approx(earlier.data.effort.grove,.4),"a quota boundary carries fractional overflow into the next step")
	check(earlier.study_quota()==2,"the opening does not suddenly jump from two exercises to dozens")
	var opening_quota=earlier.study_quota();earlier.data.progress.quarry=6;earlier.data.progress.sawmill=8;earlier.data.progress.grove=6
	check(earlier.study_quota("cottage")>opening_quota,"book effort gradually reaches the planned pace as the first areas grow")
	learning.data.study_plan={"book":learning.data.book_id,"capacity":1,"quota":48}
	frontier.refresh_plan()
	check(learning.data.study_plan.capacity==frontier.content_units() and learning.data.study_plan.quota<48,"added world capacity causes a fresh effort allocation")
	var words=JSON.stringify(learning.data.words);var practice=JSON.stringify(learning.data.practice);var contexts=JSON.stringify(learning.data.contexts)
	frontier.choose("cottage");frontier.finish_for_development(false)
	check(frontier.done("cottage") and not frontier.done("grove"),"finish current worksite completes only the chosen building and its additions")
	frontier.finish_for_development(true)
	check(frontier.finished_units()==frontier.content_units() and frontier.cells().size()==33 and learning.all_done(),"one developer action finishes all terrain buildings and additions")
	check(JSON.stringify(learning.data.words)==words and JSON.stringify(learning.data.practice)==practice and JSON.stringify(learning.data.contexts)==contexts,"fast completion never fabricates words reading listening or sentence records")
	check(frontier.finish_for_development(true)==0,"repeated completion cannot accumulate more world progress")
	print("WORDBOOKS_RESULT ",passed," passed / ",failed," failed")
	quit(0 if failed==0 else 1)
