extends Node2D

@onready var sparks: CPUParticles2D = $Sparks
@onready var burst: CPUParticles2D = $GoalBurst
@onready var trail: Line2D = $Trail

var trail_points := PackedVector2Array()

func clear() -> void:
	trail_points.clear()
	trail.clear_points()
	sparks.emitting = false
	burst.emitting = false

func update_trail(location: Vector2, moving: bool) -> void:
	trail.visible = not Settings.reduced_effects
	if not moving or Settings.reduced_effects:
		trail_points.clear()
	else:
		trail_points.append(location)
		if trail_points.size() > 12:
			trail_points.remove_at(0)
	trail.points = trail_points

func impact(location: Vector2, color: Color) -> void:
	if Settings.reduced_effects:
		return
	sparks.position = location
	sparks.color = color
	sparks.restart()
	sparks.emitting = true

func celebrate(location: Vector2, color: Color) -> void:
	if Settings.reduced_effects:
		return
	burst.position = location
	burst.color = color
	burst.restart()
	burst.emitting = true
