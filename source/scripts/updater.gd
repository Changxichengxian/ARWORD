extends RefCounted

static func open(game):
	var native = Engine.get_singleton("PlanetUpdates")
	var box = game.hud.modal("应用更新")
	game.hud.screen = "updates"
	var info = game.hud.text(box, "正在检查版本", 20)
	var action = game.hud.button(box, "下载并安装", func():
		var state = JSON.parse_string(native.call("update_state"))
		match state.get("phase", ""):
			"offer": native.call("download_update")
			"install": native.call("install_update")
			_: native.call("check_update")
	, true, 50)
	game.hud.ghost(box, "返回", game.settings)
	var state = JSON.parse_string(native.call("update_state"))
	if state.get("phase", "") not in ["working","checking","install","offer"]:
		native.call("check_update")
	var refresh = func():
		var latest = JSON.parse_string(native.call("update_state"))
		info.text = str(latest.get("message", ""))
		var phase = latest.get("phase", "")
		action.visible = phase in ["offer","error","install","current"]
		action.text = {"offer":"下载并安装","install":"打开系统安装器"}.get(phase, "重新检查")
	refresh.call()
	var timer = Timer.new()
	box.add_child(timer)
	timer.wait_time = 0.3
	timer.timeout.connect(refresh)
	timer.start()
