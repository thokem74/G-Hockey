class_name HockeyRink
extends Node2D

## Reposition authored geometry and animate independent wall-impact flashes.

const WALL_SECTIONS: Array[StringName] = [&"TopLeft", &"TopRight", &"BottomLeft", &"BottomRight"]

@export_range(0.01, 1.0, 0.01) var flash_duration: float = 0.14
@export_range(0.0, 3.0, 0.1) var maximum_flash_boost: float = 1.5

var flash_remaining: Array[float] = [0.0, 0.0, 0.0, 0.0]
var flash_peaks: Array[float] = [0.0, 0.0, 0.0, 0.0]

@onready var wall_materials: Array[ShaderMaterial] = [
	$TopLeftEdge.material, $TopRightEdge.material,
	$BottomLeftEdge.material, $BottomRightEdge.material,
]

func _ready() -> void:
	clear_flashes()

func _process(delta: float) -> void:
	if Settings.reduced_effects:
		clear_flashes()
		return
	var flashing := false
	for index in range(WALL_SECTIONS.size()):
		if flash_remaining[index] <= 0.0:
			continue
		flash_remaining[index] = maxf(flash_remaining[index] - delta, 0.0)
		var fade := smoothstep(0.0, 1.0, flash_remaining[index] / flash_duration)
		wall_materials[index].set_shader_parameter("impact_boost", flash_peaks[index] * fade)
		if flash_remaining[index] > 0.0:
			flashing = true
		else:
			flash_peaks[index] = 0.0
	set_process(flashing)

func flash_wall(section: StringName, strength: float) -> void:
	if Settings.reduced_effects:
		return
	var index := WALL_SECTIONS.find(section)
	if index < 0:
		return
	var boost := maximum_flash_boost * clampf(strength / 1000.0, 0.15, 1.0)
	# Rapid contacts refresh the envelope without dimming a stronger recent hit.
	flash_peaks[index] = maxf(flash_peaks[index], boost)
	flash_remaining[index] = flash_duration
	wall_materials[index].set_shader_parameter("impact_boost", flash_peaks[index])
	set_process(true)

func clear_flashes() -> void:
	for index in range(WALL_SECTIONS.size()):
		flash_remaining[index] = 0.0
		flash_peaks[index] = 0.0
		wall_materials[index].set_shader_parameter("impact_boost", 0.0)
	set_process(false)

func apply_layout(layout: RinkLayout) -> void:
	clear_flashes()
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
	get_node(rail_name + "Edge").points = points

func _set_goal(goal: Polygon2D, layout: RinkLayout, y: float) -> void:
	goal.polygon = PackedVector2Array([
		Vector2(layout.goal_left, y - 12), Vector2(layout.goal_right, y - 12),
		Vector2(layout.goal_right, y + 12), Vector2(layout.goal_left, y + 12),
	])
