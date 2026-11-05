extends SceneTree

const Voice=preload("res://scripts/study_voice.gd")
var passed=0
var failed=0

func check(ok:bool,label:String):
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	call_deferred("run")

func word_fixture()->IslandLearning:
	var learning=IslandLearning.new()
	learning.by_id={};learning.active_bank=[];learning.data.book_id="";learning.data.band=1
	for item in [["early",1],["later",1],["queued",1],["fresh-a",1],["fresh-b",1],["focus",1],["near",2],["far",3]]:
		var word={"id":item[0],"band":item[1]}
		learning.by_id[word.id]=word;learning.active_bank.append(word)
	return learning

func word_state(learning:IslandLearning,words:Dictionary,turn:int=5):
	learning.data.words=words.duplicate(true);learning.data.word_turn=turn
	learning.data.pending_help.clear();learning.data.help_pending="";learning.recent.clear()

func check_selection():
	var learning=word_fixture()
	word_state(learning,{"early":{"due":10},"later":{"due":20},"queued":{"review_at":1}},4)
	check(learning.next_word(100).id=="early","fourth word turn prioritizes the earliest overdue review")
	learning.data.word_turn=5
	check(learning.next_word(100).id=="queued","ready interleaved review precedes fresh words on other turns")
	learning.data.help_pending="later"
	check(learning.next_word(100).id=="later","unfinished help still overrides all candidates")
	word_state(learning,{"early":{"due":10},"later":{"due":20},"queued":{"review_at":9}})
	check(learning.next_word(100,["focus"]).id=="focus","eligible contextual focus precedes generic fresh candidates")
	word_state(learning,{"early":{"due":10},"later":{"due":20},"queued":{"review_at":9},"focus":{"mastered":true},"near":{"mastered":true},"far":{"mastered":true}})
	learning.rng.seed=20261105
	var expected=RandomNumberGenerator.new();expected.seed=20261105
	var random_sequence=true
	for i in range(12):
		if learning.next_word(100).id!=["fresh-a","fresh-b"][expected.randi_range(0,1)]:random_sequence=false
	check(random_sequence,"fresh words retain the same random selection and generator consumption")
	word_state(learning,{"early":{"mastered":true},"later":{"mastered":true},"queued":{"mastered":true},"fresh-a":{"mastered":true},"fresh-b":{"mastered":true},"focus":{"mastered":true}})
	check(learning.next_word(100).id=="near","out-of-band fresh candidates use the nearest difficulty")
	var future={}
	for word in learning.active_bank:future[word.id]={"due":500}
	future.early.due=200;future.later.due=300
	word_state(learning,future);learning.recent=["early"]
	check(learning.next_word(100).id=="later","fallback chooses earliest due time outside recent words")
	word_state(learning,future)
	for word in learning.active_bank:learning.recent.append(word.id)
	check(learning.next_word(100).id=="early","fallback can reuse a recent word when all candidates are recent")
	var excluded={}
	for word in learning.active_bank:excluded[word.id]={"mastered":true}
	excluded.early={"spot_hits":1,"review_at":9}
	word_state(learning,excluded)
	check(learning.next_word(100).is_empty(),"mastered words and pending spot checks do not leak into fallback")
	word_state(learning,{"early":{"due":10},"later":{"due":10},"queued":{"mastered":true},"fresh-a":{"mastered":true},"fresh-b":{"mastered":true},"focus":{"mastered":true},"near":{"mastered":true},"far":{"mastered":true}},4)
	check(learning.next_word(100).id in ["early","later"],"equal-priority overdue candidates remain eligible")

func zip_entry(zip:ZIPPacker,path:String,bytes:PackedByteArray)->bool:
	if zip.start_file(path)!=OK:return false
	var ok=zip.write_file(bytes)==OK
	return zip.close_file()==OK and ok

func write_voice_fixture(folder:String,sample:PackedByteArray,long_sample:PackedByteArray,oversized:PackedByteArray)->bool:
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:return false
	var zip=ZIPPacker.new()
	if zip.open(folder.path_join(Voice.PACK_NAME))!=OK:return false
	var ok=zip_entry(zip,"index.json","{}".to_utf8_buffer())
	for i in range(35):
		ok=zip_entry(zip,"short%d.mp3"%i,sample) and ok
		if not long_sample.is_empty():ok=zip_entry(zip,"long%d.mp3"%i,long_sample) and ok
	ok=zip_entry(zip,"empty.mp3",PackedByteArray()) and ok
	if not oversized.is_empty():ok=zip_entry(zip,"oversized.mp3",oversized) and ok
	return zip.close()==OK and ok

func check_voice_cache():
	var sample=FileAccess.get_file_as_bytes("res://assets/audio/work00_cue.mp3")
	var alternate=FileAccess.get_file_as_bytes("res://assets/audio/work00_full.mp3")
	check(not sample.is_empty() and not alternate.is_empty(),"cache fixtures use existing MP3 recordings")
	if sample.is_empty() or alternate.is_empty():return
	# Concatenate real MP3 recordings to exercise both limits without downloading
	# a private voice pack. Nothing in this test plays audio or opens a game save.
	var long_sample=sample.duplicate()
	while long_sample.size()<320*1024:long_sample.append_array(sample)
	var oversized=long_sample.duplicate()
	while oversized.size()<=Voice.CACHE_MAX_BYTES:oversized.append_array(long_sample)
	var folder="user://qa-runtime-resources/"+str(Time.get_ticks_usec())
	var first_folder=folder.path_join("first")
	var second_folder=folder.path_join("second")
	var prepared=write_voice_fixture(first_folder,sample,long_sample,oversized)
	prepared=write_voice_fixture(second_folder,alternate,PackedByteArray(),PackedByteArray()) and prepared
	check(prepared,"isolated archive fixtures were created")
	if not prepared:return
	var store=Voice.new();store.prepare(first_folder)
	var first=store.recording("short0.mp3")
	var second=store.recording("short1.mp3")
	check(first!=null and first==store.recording("short0.mp3"),"replaying a recording reuses its MP3 resource")
	for i in range(2,32):store.recording("short%d.mp3"%i)
	store.recording("short0.mp3");store.recording("short32.mp3")
	check(store._recordings.size()==32,"recording count is bounded at 32")
	check(store.recording("short0.mp3")==first and store.recording("short1.mp3")!=second,"recent replay survives eviction while the oldest recording is reloaded")
	store.prepare(first_folder)
	check(store._recordings.is_empty() and store._recording_bytes==0 and store.recording("short0.mp3")!=first,"prepare invalidates cached objects even when opening the same folder")
	store.prepare(first_folder)
	for i in range(35):store.recording("long%d.mp3"%i)
	var stored_bytes=0
	for item in store._recordings.values():stored_bytes+=item.stream.data.size()
	check(store._recordings.size()<32 and stored_bytes<=Voice.CACHE_MAX_BYTES and stored_bytes==store._recording_bytes,"encoded recording data remains within the 8 MiB limit")
	var count=store._recordings.size();var bytes=store._recording_bytes
	check(store.recording("missing.mp3")==null and store.recording("empty.mp3")==null and store._recordings.size()==count and store._recording_bytes==bytes,"missing and empty entries never occupy the cache")
	var large_stream=store.recording("oversized.mp3") as AudioStreamMP3
	check(large_stream!=null and large_stream.data.size()>Voice.CACHE_MAX_BYTES and store._recordings.size()==count and store._recording_bytes==bytes,"an oversized recording can load without displacing the recent cache")
	store.prepare(second_folder)
	var replaced=store.recording("short0.mp3") as AudioStreamMP3
	check(replaced!=null and replaced.data==alternate,"opening another archive replaces recordings with the same path")
	store.prepare(folder.path_join("missing"))
	check(store.archive==null and store._recordings.is_empty() and store._recording_bytes==0 and store.recording("short0.mp3")==null,"a missing archive also invalidates the old cache")
	for directory in [first_folder,second_folder]:
		DirAccess.remove_absolute(directory.path_join(Voice.PACK_NAME));DirAccess.remove_absolute(directory)
	DirAccess.remove_absolute(folder)

func run():
	check_selection();check_voice_cache()
	print("RUNTIME_RESOURCES_RESULT ",passed," passed / ",failed," failed")
	quit(0 if failed==0 else 1)
