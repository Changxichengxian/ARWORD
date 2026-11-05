extends RefCounted

# Pose calculation only. The worker owns movement, clocks, phase changes and
# rewards. Angles are radians; the character faces -Z, so positive torso X
# leans back. Keep expressions relative to the current action, not wall time.

static func _frame(pose:Dictionary)->Dictionary:
	return {"pose":pose,"rotation":Vector3.ZERO,"lift":0.0,"wrist":0.0,
		"head":Vector3.ZERO,"effort":0.0,"focus":0.0,"relax":0.0,
		"sleep":0.0,"look":Vector2.ZERO}

static func _window(time:float,start:float,raised:float,release:float,end:float)->float:
	return smoothstep(start,raised,time)*(1.0-smoothstep(release,end,time))

static func locomotion(angle:float,run:float,amount:float,size_ratio:float,loaded:bool=false)->Dictionary:
	run=clampf(run,0.0,1.0) if not loaded else 0.0
	amount=clampf(amount,0.0,1.0)
	var amplitude=(.32 if loaded else lerpf(.44,.68,run))*amount
	var pose={}
	for i in range(2):
		var side="L" if i==0 else "R"
		var phase=angle+i*PI
		var thigh=sin(phase)*amplitude
		pose["Leg"+side]=Vector3(thigh,0,0)
		# A loaded foot stays low; the knee gives under the weight at contact.
		var knee=pow(maxf(0.0,cos(phase)),2)*(.52 if loaded else lerpf(.65,1.18,run))*amount
		var pressure=pow(maxf(0.0,-sin(phase)),4)*.07*amount if loaded else 0.0
		pose["Knee"+side]=Vector3(-knee-pressure,0,0)
		pose["Arm"+side]=Vector3(.12-thigh*.72+run*.17*amount,0,.04 if i==0 else -.04)
		pose["Elbow"+side]=Vector3(lerpf(.24,.85,run)*amount,0,0)
	pose.Body=Vector3(-lerpf(.045,.16,run)*amount,sin(angle)*.055*amount,0)
	var contact=absf(sin(angle))
	var frame=_frame(pose)
	frame.rotation=Vector3(0,0,sin(angle)*(.015 if loaded else .025)*amount)
	frame.lift=(.010+contact*.012+run*contact*contact*.065)*size_ratio*amount
	frame.ground=(.015+run*.075*(1.0-contact)*amount)*size_ratio
	frame.head=Vector3(.025*run*amount,-sin(angle)*.014*amount,-sin(angle)*.008*amount)
	frame.effort=(.40 if loaded else lerpf(.08,.32,run))*amount
	frame.focus=.45*amount
	frame.relax=.15*(1.0-run)
	frame.look=Vector2(0,.04*run)
	return frame

static func _stroke(cycle:float,action:int)->Dictionary:
	# Keep the authored hand arc and the existing .48 apex / .64 contact.
	# Its old torso value is used below to compensate the shoulder angle when
	# correcting the torso's forward/backward direction.
	var ready={"arm":.72,"elbow":.35,"body":.06,"twist":-.05,"crouch":.025,"wrist":-.45}
	var raised={"arm":2.05 if action==0 else 2.40 if action==1 else 1.65,"elbow":.30,"body":-.10,"twist":-.36 if action==0 else -.10,"crouch":.055,"wrist":.05}
	var hit={"arm":.82 if action!=2 else .72,"elbow":.22,"body":.30 if action==0 else .43 if action==1 else .22,"twist":.30 if action==0 else .12,"crouch":.11 if action==1 else .075,"wrist":-1.80 if action==0 else -2.0 if action==1 else -1.6}
	var a:Dictionary
	var b:Dictionary
	var t:float
	if cycle<.48:
		a=ready;b=raised;t=smoothstep(0.0,.48,cycle)
	elif cycle<.64:
		a=raised;b=hit;t=pow((cycle-.48)/.16,1.7)
	elif cycle<.74:
		a=hit;b=ready;t=smoothstep(.64,.74,cycle)*.28
	else:
		a=hit;b=ready;t=.28+smoothstep(.74,1.0,cycle)*.72
	var result={}
	for key in ready:result[key]=lerpf(a[key],b[key],t)
	return result

static func strike(cycle:float,action:int,size_ratio:float)->Dictionary:
	cycle=clampf(cycle,0.0,1.0)
	action=clampi(action,0,2)
	var hand=_stroke(cycle,action)
	# The waist initiates the lift and the strike, then the shoulders catch it.
	# Both offsets return to zero at the apex/contact and at the loop boundary.
	var lead=0.0
	if cycle<.48:lead=.035*sin(cycle/.48*PI)
	elif cycle<.64:lead=.012*sin((cycle-.48)/.16*PI)
	var torso=_stroke(cycle+lead,action)
	var body=-float(torso.body)*.85
	var shoulder_compensation=float(hand.body)-body
	var frame=_frame({
		"ArmR":Vector3(hand.arm+shoulder_compensation,0,-.16),
		"ElbowR":Vector3(hand.elbow,0,-.06),
		"ArmL":Vector3(hand.arm*.78+shoulder_compensation,0,.48),
		"ElbowL":Vector3(.50,0,.08),
		"Body":Vector3(body,torso.twist,torso.twist*.08),
		"LegL":Vector3(.16+torso.crouch,0,-.035),
		"LegR":Vector3(-.11+torso.crouch,0,.035),
		"KneeL":Vector3(-.18-torso.crouch*1.1,0,0),
		"KneeR":Vector3(-.12-torso.crouch,0,0)})
	frame.rotation=Vector3(0,-torso.twist*.18,torso.twist*.04)
	frame.lift=-torso.crouch*size_ratio
	frame.wrist=hand.wrist
	frame.head=Vector3(-body*.14,-torso.twist*.16,-torso.twist*.025)
	frame.effort=.14+.64*_window(cycle,.20,.58,.67,.95)
	frame.focus=.70+.15*_window(cycle,.35,.56,.70,.92)
	frame.relax=.08*(1.0-_window(cycle,.0,.35,.80,1.0))
	frame.look=Vector2(-torso.twist*.12,-.16-.12*_window(cycle,.48,.64,.75,.98))
	frame.action=action;frame.action_phase=cycle
	return frame

static func _seated()->Dictionary:
	return {"LegL":Vector3(1.50,0,0),"LegR":Vector3(1.48,0,0),
		"KneeL":Vector3(-.12,0,0),"KneeR":Vector3(-.10,0,0),
		"ArmL":Vector3(.12,0,.12),"ArmR":Vector3(.12,0,-.12),
		"ElbowL":Vector3(.08,0,0),"ElbowR":Vector3(.08,0,0),
		"Body":Vector3(-.035,0,0)}

static func rest(variant:int,time:float,is_fish:bool,seated_lift:float,size_ratio:float)->Dictionary:
	time=maxf(time,0.0)
	var frame=_frame(_seated())
	frame.rotation.y=PI
	frame.lift=seated_lift
	frame.relax=.85
	# Seated hips and the lying support pose stay fixed after settling. Small
	# gestures belong to the head/arms, preserving the cached ground correction.
	match clampi(variant,0,3):
		0: # Six seconds: settle, glance right, then look back to the left.
			var glance=.30*_window(time,.75,1.10,1.70,2.15)-.24*_window(time,3.20,3.65,4.35,4.85)
			frame.look=Vector2(glance,.04)
			frame.head=Vector3(.012,-glance*.44,glance*.035)
			frame.focus=.12+.20*absf(glance)
		1: # Twelve seconds: the fixed fish dozes seated, the default lies back.
			if is_fish:
				frame.pose={"LegL":Vector3(1.15,0,0),"LegR":Vector3(1.10,0,0),
					"KneeL":Vector3(-.35,0,0),"KneeR":Vector3(-.30,0,0),
					"ArmL":Vector3(.18,0,.18),"ArmR":Vector3(.18,0,-.18),
					"ElbowL":Vector3(.08,0,0),"ElbowR":Vector3(.08,0,0),
					"Body":Vector3(-.06,0,0)}
				frame.head=Vector3(-.07,0,.025)
			else:
				frame.pose={"ArmL":Vector3(0,0,-.32),"ArmR":Vector3(0,0,.32),
					"ElbowL":Vector3(-.25,0,0),"ElbowR":Vector3(-.25,0,0),
					"LegL":Vector3(0,0,-.12),"LegR":Vector3(0,0,.12),
					"KneeL":Vector3.ZERO,"KneeR":Vector3.ZERO,"Body":Vector3.ZERO}
				frame.rotation=Vector3(PI/2,0,0)
				frame.lift=.18*size_ratio
			frame.sleep=smoothstep(.30,1.20,time)*(1.0-smoothstep(11.10,11.90,time))
			frame.relax=1.0
			frame.look=Vector2(0,-.12)
		2: # Four and a half seconds: one shoulder leads, then both arms lower.
			var left=_window(time,.12,.82,2.85,4.05)
			var right=_window(time,.28,1.02,3.05,4.30)
			var together=minf(left,right)
			frame.pose={"ArmL":Vector3(.10*left,0,-2.6*left),
				"ArmR":Vector3(.10*right,0,2.6*right),
				"ElbowL":Vector3(.30*left,0,0),"ElbowR":Vector3(.30*right,0,0),
				"Body":Vector3(.055*together,0,.055*(left-right)),
				"LegL":Vector3.ZERO,"LegR":Vector3.ZERO,
				"KneeL":Vector3.ZERO,"KneeR":Vector3.ZERO}
			frame.lift=0.0
			frame.head=Vector3(.05*together,0,-.02*(left-right))
			frame.look=Vector2(0,.32*together)
			frame.effort=.10*together
			frame.relax=.72
		3: # Seven seconds: a small foot swing and one unhurried forehead wipe.
			frame.pose.KneeL=Vector3(-.12+sin(time*1.8)*.075,0,0)
			var wipe=_window(time,1.90,2.55,3.60,4.25)
			var sweep=sin(clampf((time-2.55)/1.05,0.0,1.0)*PI)*wipe
			frame.pose.ArmR=Vector3(lerpf(.12,1.55,wipe),.08*sweep,lerpf(-.12,-.24,wipe))
			frame.pose.ElbowR=Vector3(lerpf(.08,1.10,wipe),0,0)
			frame.head=Vector3(-.035*wipe,.025*sweep,-.018*wipe)
			frame.look=Vector2(.06*sweep,-.10*wipe)
			frame.effort=.06*wipe
			frame.relax=.90
			if is_fish:
				# Short arms naturally rub the cheek instead of stretching the rig
				# past its authored reach to touch a much larger forehead.
				frame.head.x-=.025*wipe
				frame.look.y-=.08*wipe
	return frame

static func _hold_pose(body:float,arm:float,elbow:float)->Dictionary:
	return {"Body":Vector3(body,0,0),
		"ArmL":Vector3(arm,0,.28),"ArmR":Vector3(arm,0,-.28),
		"ElbowL":Vector3(elbow,0,.025),"ElbowR":Vector3(elbow,0,-.025)}

static func carrying(phase_time:float,walking:bool,angle:float,size_ratio:float,travel_time:float=0.0)->Dictionary:
	var frame=_frame(_hold_pose(.095,1.06,.62))
	frame.load=1.0
	frame.focus=.75
	if walking:
		# Only override the upper body: the distance-driven legs keep their phase.
		# A low, firm hold and a slight counter-lean carry the weight together.
		var pressure=pow(absf(sin(angle)),6)
		frame.pose.Body=Vector3(.095+.018*pressure,sin(angle)*.025,sin(angle)*.013)
		frame.pose.ArmL.x+=pressure*.015
		frame.pose.ArmR.x+=pressure*.015
		frame.rotation=Vector3(0,0,sin(angle)*.015)
		frame.lift=(.010+absf(sin(angle))*.012)*size_ratio
		frame.head=Vector3(-.045-.012*pressure,-sin(angle)*.018,sin(angle)*.010)
		frame.effort=.48+.10*pressure
		frame.look=Vector2(sin(angle)*.03,-.15)
		# Once in a longer trip, tighten the left grip and settle the load back
		# against the chest. This belongs to the carry, not every footstep.
		var grip=_window(fposmod(travel_time,6.2),2.10,2.32,2.50,2.85)
		frame.pose.ElbowL.x+=.12*grip
		frame.pose.ArmL.x+=.035*grip
		frame.pose.Body.z-=.012*grip
		frame.head.x-=.025*grip
		frame.effort+=.08*grip
		frame.look.y-=.10*grip
		return frame
	var squat=0.0
	if phase_time<.35:
		var take=clampf(phase_time/.35,0.0,1.0)
		squat=_window(take,0.0,.28,.43,1.0)
		var grip=smoothstep(.12,.52,take)
		var rise=smoothstep(.34,1.0,take)
		frame.pose=_hold_pose(-.28*squat+.095*rise,lerpf(.30,1.06,grip),lerpf(.20,.62,grip))
		frame.load=smoothstep(.26,.52,take)
		frame.head=Vector3(-.13*squat-.045*rise,0,0)
		frame.effort=.15+.48*squat+.33*rise
		frame.focus=.75+.15*squat
		frame.look=Vector2(0,-.55*squat-.15*rise)
	else:
		var lower=clampf((phase_time-.35)/.65,0.0,1.0)
		var bend=smoothstep(.12,.64,lower)
		var release=smoothstep(.60,.82,lower)
		var recover=smoothstep(.78,1.0,lower)
		squat=bend*(1.0-recover)
		var arm=lerpf(lerpf(1.06,.65,bend),.30,recover)
		var elbow=lerpf(lerpf(.62,.32,bend),.20,recover)
		frame.pose=_hold_pose(.095*(1.0-bend)-.24*squat-.025*recover,arm,elbow)
		frame.load=1.0-smoothstep(.62,.82,lower)
		frame.head=Vector3(-.045-.10*squat+.060*recover,0,0)
		frame.effort=.48*(1.0-release)+.08*recover
		frame.focus=lerpf(.75,.25,recover)
		frame.relax=.70*release
		frame.look=Vector2(0,-.15-.40*squat+.18*recover)
	# These stationary poses bend knees before lowering the root. The worker's
	# existing foot contact correction supplies the final height on real ground.
	frame.pose.LegL=Vector3(.10+.30*squat,0,-.025)
	frame.pose.LegR=Vector3(.06+.27*squat,0,.025)
	frame.pose.KneeL=Vector3(-.10-.58*squat,0,0)
	frame.pose.KneeR=Vector3(-.10-.52*squat,0,0)
	frame.lift=-.14*squat*size_ratio
	frame.ground=.015*size_ratio
	return frame
