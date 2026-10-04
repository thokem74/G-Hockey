class_name HockeyPuck
extends Node2D

signal impact(location: Vector2, strength: float, paddle_hit: bool)
signal goal_scored(player: int)

const RADIUS := 20.0
const MAX_SPEED := 1800.0
const GOAL_LEFT := 270.0
const GOAL_RIGHT := 450.0
const GOAL_POSTS: Array[Vector2] = [
	Vector2(270, 210), Vector2(450, 210),
	Vector2(270, 1130), Vector2(450, 1130),
]

var velocity := Vector2.ZERO
var active: bool = false
var collision_cooldown: float = 0.0

func reset_at(location: Vector2) -> void:
	position = location
	velocity = Vector2.ZERO
	active = false
	collision_cooldown = 0.0

func simulate(delta: float, paddles: Array[HockeyPaddle]) -> void:
	if not active:
		return
	collision_cooldown = maxf(collision_cooldown - delta, 0.0)
	# Small steps keep both the puck and fast paddles from crossing a collision.
	var steps := maxi(1, ceili(MAX_SPEED * delta / 8.0))
	var step_delta := delta / steps
	for step in range(steps):
		position += velocity * step_delta
		for paddle in paddles:
			var sample := paddle.position - paddle.velocity * step_delta * (steps - step - 1)
			_collide_paddle(paddle, sample)
		_collide_walls()
		if position.y < 180.0:
			active = false
			goal_scored.emit(0)
			return
		if position.y > 1160.0:
			active = false
			goal_scored.emit(1)
			return
	velocity *= pow(0.985, delta)

func _collide_paddle(paddle: HockeyPaddle, sample: Vector2) -> void:
	var separation := position - sample
	var distance := separation.length()
	var combined_radius := RADIUS + HockeyPaddle.RADIUS
	if distance >= combined_radius:
		return
	var normal := separation / distance if distance > 0.001 else Vector2.DOWN
	position = sample + normal * (combined_radius + 0.1)
	var incoming := (velocity - paddle.velocity).dot(normal)
	if incoming < 0.0:
		velocity -= normal * incoming * 1.92
		velocity = velocity.limit_length(MAX_SPEED)
		_emit_impact(absf(incoming), true)

func _collide_walls() -> void:
	if position.x < 68.0:
		position.x = 68.0
		velocity.x = absf(velocity.x)
		_emit_impact(absf(velocity.x), false)
	elif position.x > 652.0:
		position.x = 652.0
		velocity.x = -absf(velocity.x)
		_emit_impact(absf(velocity.x), false)
	# The puck must fit fully through the goal; round posts close the corners.
	for post in GOAL_POSTS:
		var separation: Vector2 = position - post
		if separation.length() < RADIUS + 6.0:
			var normal := separation.normalized() if separation.length() > 0.001 else Vector2.DOWN
			position = post + normal * (RADIUS + 6.1)
			if velocity.dot(normal) < 0.0:
				velocity = velocity.bounce(normal)
				_emit_impact(velocity.length(), false)
	var outside_goal := position.x < GOAL_LEFT or position.x > GOAL_RIGHT
	if outside_goal and position.y < 230.0 and velocity.y < 0.0:
		position.y = 230.0
		velocity.y = absf(velocity.y)
		_emit_impact(absf(velocity.y), false)
	elif outside_goal and position.y > 1110.0 and velocity.y > 0.0:
		position.y = 1110.0
		velocity.y = -absf(velocity.y)
		_emit_impact(absf(velocity.y), false)

func _emit_impact(strength: float, paddle_hit: bool) -> void:
	if collision_cooldown <= 0.0 and strength > 60.0:
		impact.emit(position, strength, paddle_hit)
		collision_cooldown = 0.035
