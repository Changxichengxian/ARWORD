extends RefCounted

var meanings:Dictionary={}
var entries:Dictionary={}
var splitter=RegEx.new()

func setup(bank:Dictionary):
	entries=bank
	splitter.compile("[；;，,、／/\\n（）()]+")
	for id in entries:
		var q=entries[id]
		for label in labels(str(q.zh)):
			if not meanings.has(label):meanings[label]=[]
			meanings[label].append(id)

func labels(value:String)->Array:
	var result=[value.strip_edges()]
	for part in splitter.sub(value,"|",true).split("|",false):
		var clean=part.strip_edges()
		if not clean.is_empty() and not result.has(clean):result.append(clean)
	return result

func overlaps(a:String,b:String)->bool:
	for left in labels(a):
		for right in labels(b):
			if left==right or (mini(left.length(),right.length())>=2 and (left.contains(right) or right.contains(left))):return true
	return false

func valid_other(q:Dictionary,other:Dictionary,used:Array)->bool:
	if other.id==q.id or used.has(other.word):return false
	if str(other.word).to_lower().begins_with(str(q.word).to_lower()) or str(q.word).to_lower().begins_with(str(other.word).to_lower()):return false
	return not overlaps(str(q.zh),str(other.get("definition",other.zh))) and not overlaps(str(q.get("definition",q.zh)),str(other.zh))

func alternative(q:Dictionary,bank:Array,used:Array,seed:int)->Dictionary:
	for offset in bank.size():
		var other:Dictionary=bank[posmod(seed+offset*37,bank.size())]
		if valid_other(q,other,used):return other
	for other in entries.values():
		if valid_other(q,other,used):return other
	return {}

func prepare(word:Dictionary,kind:String,bank:Array)->Dictionary:
	var q=word.duplicate(true)
	q["review_kind"]=kind;q["option_words"]=[];q["option_meanings"]=[]
	if kind=="reverse":
		q.erase("correct_indices");q.correct=0;q.options=[q.word]
		q.option_words=[q.word];q.option_meanings=[q.zh]
		for i in 3:
			var other=alternative(q,bank,q.option_words,posmod(str(q.id).hash()+i*131,2147483647))
			if other.is_empty():break
			q.options.append(other.word);q.option_words.append(other.word);q.option_meanings.append(other.zh)
		return q
	var correct:Array=q.get("correct_indices",[int(q.correct)])
	var used=[q.word]
	for i in q.options.size():
		if correct.has(i):
			q.option_words.append(q.word);q.option_meanings.append(q.options[i]);continue
		var match_word=""
		for id in meanings.get(str(q.options[i]),[]):
			if valid_other(q,entries[id],used):match_word=str(entries[id].word);break
		if match_word.is_empty():
			var other=alternative(q,bank,used,posmod(str(q.id).hash()+i*131,2147483647))
			if not other.is_empty():match_word=other.word;q.options[i]=other.zh
		used.append(match_word);q.option_words.append(match_word);q.option_meanings.append(q.options[i])
	return q
