extends RefCounted

var entries:Dictionary
var dictionary:Dictionary
var full_entries:Dictionary
var senses:Dictionary={}
var examples:Dictionary={}
var keys:Array=[]

func _init(words:Dictionary,lookup_words:Dictionary,lexicon:Dictionary={}):
	entries=words;dictionary=lookup_words;full_entries=lexicon
	var all=words.duplicate()
	for word in dictionary:all[word]=true
	keys=all.keys();keys.sort()

func normalize(value:String)->String:
	return value.strip_edges().to_lower().replace("’","'").replace("‘","'")

func has_word(value:String)->bool:
	var word=normalize(value)
	return entries.has(word) or dictionary.has(word)

func search(value:String,limit=24)->Array:
	var query=normalize(value);var exact=[];var prefix=[];var rest=[]
	if query.is_empty():return []
	for word in keys:
		if word==query:exact.append(word)
		elif str(word).begins_with(query):prefix.append(word)
		elif query.length()>=2 and query in str(word):rest.append(word)
	return (exact+prefix+rest).slice(0,limit)

func entry(value:String)->Dictionary:
	var word=normalize(value);var q:Dictionary=entries.get(word,{});var d:Dictionary=dictionary.get(word,{})
	var full:Dictionary=full_entries.get(word,q)
	var common=str(q.get("zh",""))
	if senses.has(word):
		var lines=[]
		for sense in senses[word].senses:lines.append(str(sense.pos)+" · "+str(sense.zh))
		common="\n".join(lines)
	return {"word":word,"common":common,"pos":str(q.get("pos","")),"phonetic":str(full.get("phonetic",d.get("phonetic",""))),"definition":str(full.get("definition",d.get("translation",q.get("zh",""))))}

func sentences(value:String)->Array:
	if examples.is_empty() and FileAccess.file_exists("res://assets/word_examples.json"):
		var loaded=JSON.parse_string(FileAccess.get_file_as_string("res://assets/word_examples.json"))
		if loaded is Dictionary:examples=loaded
	var word=normalize(value);var result:Array=examples.get(word,[]).duplicate()
	if result.is_empty():
		var q:Dictionary=entries.get(word,{})
		if not str(q.get("example","")).is_empty():result.append({"en":q.example,"zh":q.get("translation",""),"credit":"ARWORD 原创例句"})
	return result
