class_name HockeyRink
extends Node2D

## Reposition authored scene geometry only when the display layout changes.

func apply_layout(layout: RinkLayout) -> void:
	var left := layout.bounds.position.x
	var right := layout.bounds.end.x
	var top := layout.bounds.position.y
	var bottom := layout.bounds.end.y
	var middle := layout.center.y
	$Surface.polygon = PackedVector2Array([
		Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom),
	])
	_set_rail("TopLeft", PackedVector2Array([Vector2(left, middle), Vector2(left, top), Vector2(layout.goal_left, top)]))
	_set_rail("TopRight", PackedVector2Array([Vector2(layout.goal_right, top), Vector2(right, top), Vector2(right, middle)]))
	_set_rail("BottomLeft", PackedVector2Array([Vector2(left, middle), Vector2(left, bottom), Vector2(layout.goal_left, bottom)]))
	_set_rail("BottomRight", PackedVector2Array([Vector2(layout.goal_right, bottom), Vector2(right, bottom), Vector2(right, middle)]))
	_set_rail("CenterLine", PackedVector2Array([Vector2(left, middle), Vector2(right, middle)]))
	$CenterCircle.position = layout.center
	_set_goal($TopGoal, layout, top)
	_set_goal($BottomGoal, layout, bottom)
	# Distribute the existing editor-visible grid nodes over the new surface.
	for index in range(15):
		var x := lerpf(left, right, float(index + 1) / 16.0)
		get_node("GridVertical%d" % index).points = PackedVector2Array([Vector2(x, top), Vector2(x, bottom)])
	for index in range(23):
		var y := lerpf(top, bottom, float(index + 1) / 24.0)
		get_node("GridHorizontal%d" % index).points = PackedVector2Array([Vector2(left, y), Vector2(right, y)])

func _set_rail(rail_name: String, points: PackedVector2Array) -> void:
	get_node(rail_name + "Glow").points = points
	get_node(rail_name + "Edge").points = points

func _set_goal(goal: Polygon2D, layout: RinkLayout, y: float) -> void:
	goal.polygon = PackedVector2Array([
		Vector2(layout.goal_left, y - 12), Vector2(layout.goal_right, y - 12),
		Vector2(layout.goal_right, y + 12), Vector2(layout.goal_left, y + 12),
	])
