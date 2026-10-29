extends RefCounted
class_name IslandWordbooks

var books:Array=[]
var entries:Dictionary={}
var ids:Dictionary={}
func _init():
	if not FileAccess.file_exists("res://assets/wordbooks/catalog.json"):return
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/wordbooks/catalog.json"))
	var lexicon=JSON.parse_string(FileAccess.get_file_as_string("res://assets/wordbooks/lexicon.json"))
	if not catalog is Dictionary or not lexicon is Array:return
	for entry in lexicon:
		if entry is Dictionary and entry.has_all(["id","word","zh","options","audio"]):
			var q=entry.duplicate();q.correct=int(q.get("correct",0));q.band=int(q.get("band",1));q.pos=str(q.get("pos",""));q.example=str(q.get("example",""));q.translation=str(q.get("translation",""));entries[q.id]=q
	for item in catalog.get("books",[]):
		if not item is Dictionary or not item.has_all(["id","title","words"]):continue
		var book=item.duplicate(true);var valid=[];var members={}
		for id in book.words:
			if entries.has(id) and not members.has(id):valid.append(id);members[id]=true
		if valid.is_empty():continue
		book.words=valid;books.append(book);ids[book.id]=members
func find(id:String)->Dictionary:
	for book in books:
		if book.id==id:return book
	return {}
func contains(book:String,word:String)->bool:return ids.get(book,{}).has(word)
func default_id()->String:return "senior" if ids.has("senior") else str(books[0].id) if not books.is_empty() else ""
