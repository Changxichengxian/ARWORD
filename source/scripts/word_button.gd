extends Button

signal short_pressed
signal held
const HOLD_SECONDS=.5
const MOVE_LIMIT=12.0
var elapsed=0.0
var holding=false
var consumed=false
var origin=Vector2.ZERO

func _ready():
	set_process(false)
	button_down.connect(begin_hold)
	button_up.connect(func():holding=false;set_process(false))
	pressed.connect(func():if not consumed:short_pressed.emit())
	mouse_exited.connect(cancel_hold)

func begin_hold():
	consumed=false;holding=true;elapsed=0.;set_process(true)

func cancel_hold():
	if holding:consumed=true
	holding=false;set_process(false)

func _gui_input(event):
	# Use the delivered control coordinates, including emulated touch input.
	if event is InputEventMouseButton and event.pressed:origin=event.position
	if event is InputEventScreenTouch:
		if event.pressed:origin=event.position
		if event.canceled:cancel_hold()
	if event is InputEventMouseMotion and holding and event.position.distance_to(origin)>MOVE_LIMIT:cancel_hold()
	if event is InputEventScreenDrag and holding and event.position.distance_to(origin)>MOVE_LIMIT:cancel_hold()

func _notification(what):
	if what in [NOTIFICATION_SCROLL_BEGIN,NOTIFICATION_DRAG_BEGIN,NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_OUT]:cancel_hold()

func _process(dt):
	if not is_visible_in_tree() or disabled:cancel_hold();return
	elapsed+=dt
	if elapsed>=HOLD_SECONDS:
		consumed=true;holding=false;set_process(false);held.emit()
