extends "res://tests/word_details_game.gd"
var update_requests=0
func can_update()->bool:return true
func open_updates():
	update_requests+=1
	var box=hud.modal("应用更新");hud.screen="updates"
	hud.text(box,"测试更新入口")
	hud.ghost(box,"返回",settings)
