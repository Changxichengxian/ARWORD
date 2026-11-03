extends RefCounted

# Physical display coordinates are intersected with the actual game window
# before converting to logical UI units. Insets need not be symmetric.
static func from_display(window:Rect2,logical:Vector2,safe:Rect2,cutouts:Array)->Rect2:
	if not window.has_area():return Rect2(Vector2.ZERO,logical)
	var allowed=window.intersection(safe) if safe.has_area() else window
	for raw in cutouts:
		var cut=Rect2(raw).intersection(allowed)
		if not cut.has_area():continue
		var costs=[cut.end.x-allowed.position.x,cut.end.y-allowed.position.y,allowed.end.x-cut.position.x,allowed.end.y-cut.position.y]
		var end=allowed.end
		match costs.find(costs.min()):
			0:allowed.position.x=cut.end.x;allowed.end=end
			1:allowed.position.y=cut.end.y;allowed.end=end
			2:allowed.end.x=cut.position.x
			3:allowed.end.y=cut.position.y
	var scale=logical/window.size
	return Rect2((allowed.position-window.position)*scale,allowed.size*scale)

static func current(view:Viewport)->Rect2:
	var logical=view.get_visible_rect().size
	var entire=Rect2(Vector2.ZERO,logical)
	if not OS.has_feature("android"):return entire
	var plugin=Engine.get_singleton("PlanetUpdates")
	if plugin and plugin.has_method("safe_viewport_insets"):
		var e=plugin.call("safe_viewport_insets")
		if e!=null and e.size()==4 and e[0]+e[2]<1 and e[1]+e[3]<1:
			return Rect2(Vector2(e[0],e[1])*logical,Vector2(1.-e[0]-e[2],1.-e[1]-e[3])*logical)
	return from_display(Rect2(Vector2(DisplayServer.window_get_position()),Vector2(DisplayServer.window_get_size())),logical,Rect2(DisplayServer.get_display_safe_area()),DisplayServer.get_display_cutouts())
