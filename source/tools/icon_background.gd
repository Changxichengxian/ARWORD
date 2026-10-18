extends SceneTree
func _initialize():
	var image=Image.create(432,432,false,Image.FORMAT_RGBA8);image.fill(Color("105d69"))
	image.save_png("res://assets/icon-background.png")
	quit()
