extends SceneTree
func _initialize():
	var font=load("res://assets/fonts/FrontierSC.ttf")
	var fallback=load("res://assets/fonts/FrontierLatin.ttf")
	var phonetics="ŋɒɔəɪʃʌʒˈˌєә"
	var missing=[]
	for character in phonetics:
		if not font.has_char(character.unicode_at(0)) and not fallback.has_char(character.unicode_at(0)):missing.append(character)
	print("FONT_RESULT bundled_fallback=",fallback.get_font_name()," missing=",missing)
	quit(0 if missing.is_empty() else 1)
