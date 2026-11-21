extends RefCounted

const MODEL_HASH="c14879ff5c42501043896aae03ce971b2c11eee2e76106d47ee98741aa842ff5"
const BUILTIN="res://assets/characters/whale_girl.glb"
var folder:String
var model_path=""

func _init(directory:String):
	folder=directory

func prepare(bundled:String=BUILTIN):
	model_path = BUILTIN if bundled==BUILTIN and ResourceLoader.exists(BUILTIN,"PackedScene") else ""

func preferred()->String:
	return "deepseek" if not model_path.is_empty() else ""

func remember(id:String)->bool:
	return id=="deepseek" and not model_path.is_empty()
