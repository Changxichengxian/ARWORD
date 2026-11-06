extends RefCounted

var entries:Dictionary={}

func _init():
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/wordbooks/common-senses.json"))
	if data is Dictionary:entries=data.get("entries",{})

func prepare(word:Dictionary)->Dictionary:
	var entry:Dictionary=entries.get(str(word.get("id","")),{})
	var senses:Array=entry.get("senses",[])
	var distractors:Array=entry.get("distractors",[])
	if entry.get("status","")!="reviewed" or senses.size() not in [2,3] or senses.size()+distractors.size()!=6:return word
	var q=word.duplicate(true);q.options=[];q["correct_indices"]=[];q["sense_labels"]=[]
	var parts=[]
	for sense in senses:
		q.correct_indices.append(q.options.size());q.options.append(str(sense.zh));q.sense_labels.append(str(sense.pos)+" · "+str(sense.zh))
		for part in str(sense.pos).split("／"):
			if not parts.has(part):parts.append(part)
	q.pos="／".join(parts)
	q.options.append_array(distractors)
	return q

func is_multi(q:Dictionary)->bool:return q.get("correct_indices",[]).size() in [2,3]

func matches(q:Dictionary,selected:Array)->bool:
	var expected:Array=q.get("correct_indices",[])
	if not is_multi(q) or selected.size()!=expected.size():return false
	var unique={}
	for index in selected:
		if not expected.has(index) or unique.has(index):return false
		unique[index]=true
	return true
