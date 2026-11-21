extends SceneTree
# Bake sparse indices for this approved mesh once. Source vertex data is not exported.
class RigHost extends Node3D:
	var worker=null
	var motion_speed=0.0
func _initialize():call_deferred("run")
func run():
	var host=RigHost.new()
	root.add_child(host)
	var avatar=preload("res://scripts/avatar.gd").new()
	avatar.rebuild_contacts=true
	host.add_child(avatar)
	var cast=preload("res://scripts/fixed_cast.gd")
	avatar.load_file(host,cast.BUILTIN)
	if avatar.used_baked_surfaces>0:print("Contact profile already baked");quit();return
	if avatar.baked_surfaces.is_empty():push_error("No weighted surfaces");quit(2);return
	var file=FileAccess.open("res://assets/characters/whale_contacts.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"surfaces":avatar.baked_surfaces},"\t"))
	file.close()
	print("BAKED_CONTACTS ",avatar.baked_surfaces.size()," surfaces / ",avatar.support_probes.size()," unique points / ",avatar.foot_probes.size()," foot contacts")
	host.free()
	quit()
