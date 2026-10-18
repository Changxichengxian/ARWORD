extends SceneTree
func _initialize():
	var text="Godot "+Engine.get_version_info().string+"\n\n"+Engine.get_license_text()+"\n\nTHIRD PARTY COPYRIGHT\n"
	text+=JSON.stringify(Engine.get_copyright_info(),"  ")+"\n\nTHIRD PARTY LICENSE TEXTS\n"+JSON.stringify(Engine.get_license_info(),"  ")
	var file=FileAccess.open("res://assets/Godot-COPYRIGHT.txt",FileAccess.WRITE);file.store_string(text);file.close()
	print("Bundled runtime copyright and licenses exported")
	quit()
