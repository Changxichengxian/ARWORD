extends SceneTree
func _initialize():call_deferred("run")
func run():
	var g=load("res://main.tscn").instantiate();root.add_child(g)
	await physics_frame
	var results=[]
	for sample in range(6):
		seed(1024+sample);g.return_camp();g.lesson_index=sample;g.start_battle()
		var steps=0
		while g.phase=="battle" and steps<4800:
			await physics_frame;steps+=1
			if sample<2:continue # Idle baseline should be defeatable.
			g.hud.fire=true
			var target=g.nearest_enemy()
			var goal=Vector3(0,0,-7)
			if target:
				var offset=g.player.position-target.position
				if offset.length()<7:
					goal=target.position+offset.normalized()*5+Vector3(-offset.z,0,offset.x).normalized()*3
			var dir=g.world.steer(g.player.position,goal)
			g.hud.move=Vector2(dir.x,dir.z)
			for b in g.bullets:
				if is_instance_valid(b.source) and b.source!=g.player and b.node.position.distance_to(g.player.position)<2:
					g.do_dash();break
		results.append({"case":sample,"seconds":g.elapsed,"hp":g.player.hp,"remaining":g.living_enemies(),"shots":g.shots,"hits":g.hits,"counters":g.counters,"dodges":g.dodges,"settled":g.phase=="result"})
	print("ENCOUNTER_RESULTS "+JSON.stringify(results))
	var ok=results[0].settled and results[1].settled
	var victories=0
	for r in results:if r.hp>0 and r.remaining==0:victories+=1
	print("ENCOUNTER_RESULT idle_settles="+str(ok)+" active_wins="+str(victories)+"/4")
	g.queue_free();await physics_frame;await physics_frame
	quit(0 if ok and victories>0 else 1)
