extends SceneTree

const Avatar=preload("res://scripts/avatar.gd")
var passed=0
var failed=0

class ExpressionWorker extends RefCounted:
	var expression={"effort":0.0,"focus":0.0,"relax":0.0,"sleep":0.0,"look":Vector2.ZERO}
	var work_left=12.0
	var rest_variant=0
	var waking=0.0
	var head_pivot:Node3D

class ExpressionWorld extends RefCounted:
	var worker=ExpressionWorker.new()
	var time=0.0
	var motion_speed=0.0
	var limbs={}

func check(ok:bool,label:String):
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)

func _initialize():
	if not "--qa" in OS.get_cmdline_user_args():quit(2);return
	call_deferred("run")

func check_values():
	var state={"effort":.7,"focus":.5,"relax":.3,"sleep":.2,"look":Vector2(.8,-.6)}
	var original=state.duplicate(true);var first=Avatar.expression_values(state,8.25)
	Avatar.expression_values({"sleep":1.0},1000.0)
	check(first==Avatar.expression_values(state,8.25) and state==original,"sampling an expression again is stable and leaves the motion state untouched")
	var closed=0;var opened=0;var valid=true
	for i in range(5100):
		var value=Avatar.natural_blink(float(i)*.01)
		closed+=int(value>.98);opened+=int(value==0)
		valid=valid and is_finite(value) and value>=0 and value<=1
	check(closed>5 and opened>4500 and valid,"natural blinking has brief complete blinks separated by open eyes")
	var focused=Avatar.expression_values({"focus":1.0},0)
	var effort=Avatar.expression_values({"effort":1.0,"focus":1.0},0)
	var relaxed=Avatar.expression_values({"relax":1.0},0)
	check(is_equal_approx(focused.angry,.10) and is_equal_approx(effort.angry,.28) and is_equal_approx(effort.ih,.07),"focus and effort use restrained brow and mouth shapes")
	check(is_equal_approx(relaxed.happy,.08) and is_equal_approx(relaxed.relaxed,.18) and relaxed.angry==0,"resting gives a slight relaxed smile")
	var tired=Avatar.expression_values({"sleep":.5,"look":Vector2.ONE},0)
	var asleep=Avatar.expression_values({"sleep":1.0,"effort":1.0,"focus":1.0,"look":Vector2.ONE},0)
	check(is_equal_approx(tired.blink,.47) and is_equal_approx(asleep.blink,.94) and tired.lookUp>0 and asleep.lookUp==0 and asleep.angry==0 and asleep.ih==0,"sleep blends the eyes closed while gaze and exertion settle")
	var right_up=Avatar.expression_values({"look":Vector2.ONE},0)
	var left_down=Avatar.expression_values({"look":-Vector2.ONE},0)
	check(right_up.lookRight==left_down.lookLeft and right_up.lookUp==left_down.lookDown and right_up.lookLeft==0 and left_down.lookRight==0,"gaze is symmetric with positive X right and positive Y up")
	var cleared=Avatar.expression_values(state,8.25,true);var neutral=true
	for value in cleared.values():neutral=neutral and value==0
	check(neutral,"neutral clears all state expressions including blink")
	for item in [{},{"effort":"bad","sleep":NAN,"focus":INF,"look":Vector2(NAN,0)},{"effort":4,"focus":-5,"relax":8,"sleep":-2,"look":Vector2(20,-20)}]:
		for value in Avatar.expression_values(item,NAN).values():valid=valid and is_finite(value) and value>=0 and value<=1
	check(valid,"missing or invalid expression inputs remain finite and bounded")

func check_model(path:String):
	if not FileAccess.file_exists(path):
		print("SKIP model binding check: supply --avatar-file with the private fixed character")
		return
	var before=FileAccess.get_sha256(path)
	var world=ExpressionWorld.new();var avatar=Avatar.new();root.add_child(avatar)
	var result=avatar.load_file(world,path)
	check(result.get("ok",false),"the real fixed model loads for expression binding inspection")
	if not result.get("ok",false):avatar.free();return
	var all_bound=true
	for name in Avatar.FACE_EXPRESSIONS:all_bound=all_bound and not avatar.expression_bindings.get(name,[]).is_empty()
	check(all_bound and avatar.expression_targets.size()==11,"the fixed model supplies the eleven named face shapes")
	check(not avatar.blink_bindings.is_empty(),"the existing blink binding interface remains available")
	var clothing=[]
	for mesh in avatar.meshes:
		for i in mesh.mesh.get_blend_shape_count():
			if str(mesh.mesh.get_blend_shape_name(i))=="TiePen":
				mesh.set_blend_shape_value(i,.37);clothing.append({"mesh":mesh,"index":i})
	world.worker.expression={"effort":1.0,"focus":1.0,"sleep":.5,"look":Vector2(1,-1)}
	avatar.apply_expression(world.worker.expression,0)
	var applied=true
	for name in ["angry","ih","blink","lookRight","lookDown"]:
		for binding in avatar.expression_bindings.get(name,[]):applied=applied and binding.mesh.get_blend_shape_value(binding.index)>0
	for name in ["blinkLeft","blinkRight"]:
		for binding in avatar.expression_bindings.get(name,[]):applied=applied and binding.mesh.get_blend_shape_value(binding.index)==0
	check(applied,"expressions reach the real model without stacking combined and per-eye blink shapes")
	var snapshot=[]
	for target in avatar.expression_targets:snapshot.append(target.mesh.get_blend_shape_value(target.index))
	avatar.apply_expression(world.worker.expression,0)
	var stable=true
	for i in avatar.expression_targets.size():
		var target=avatar.expression_targets[i]
		stable=stable and snapshot[i]==target.mesh.get_blend_shape_value(target.index)
	check(stable and world.worker.work_left==12.0 and world.time==0,"repeated rendering preserves both expression values and earned work time")
	avatar.update_pose(true)
	var neutral=true
	for target in avatar.expression_targets:neutral=neutral and target.mesh.get_blend_shape_value(target.index)==0
	check(neutral,"the neutral skeleton pose also clears the real face shapes")
	var untouched=not clothing.is_empty()
	for target in clothing:untouched=untouched and is_equal_approx(target.mesh.get_blend_shape_value(target.index),.37)
	check(untouched,"clothing shape TiePen remains untouched")
	check(before==FileAccess.get_sha256(path),"preparing and posing the avatar leaves the model file byte-identical")
	avatar.free()

func run():
	check_values()
	var path="res://assets/characters/deepseek.vrm"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--avatar-file="):path=arg.trim_prefix("--avatar-file=")
	check_model(path)
	print("AVATAR_EXPRESSION_RESULT ",passed," passed / ",failed," failed")
	quit.call_deferred(0 if failed==0 else 1)
