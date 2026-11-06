extends "res://scripts/main.gd"

var spoken:Array=[]
func play_speech(path:String,slow=false):
	spoken.append(path)
	super.play_speech(path,slow)
