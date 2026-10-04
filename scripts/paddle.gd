class_name HockeyPaddle
extends Node2D

const RADIUS := 42.0
const HUMAN_SPEED := 1500.0

@export var neon_color: Color = Color("35e5ff")

var target: Vector2
var velocity := Vector2.ZERO
var court := Rect2()

func _ready() -> void:
	modulate = neon_color
	target = position

func move_toward_target(delta: float, speed: float = HUMAN_SPEED) -> void:
	var previous := position
	var safe_target := Vector2(
		clampf(target.x, court.position.x, court.end.x),
		clampf(target.y, court.position.y, court.end.y)
	)
	position = position.move_toward(safe_target, speed * delta)
	velocity = (position - previous) / delta if delta > 0.0 else Vector2.ZERO

func reset_at(location: Vector2) -> void:
	position = location
	target = location
	velocity = Vector2.ZERO
