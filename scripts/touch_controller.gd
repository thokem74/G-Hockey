class_name TouchController
extends Node

var paddles: Array[HockeyPaddle] = []
var player_count: int = 1
var layout: RinkLayout
var fingers: Dictionary = {}
var offsets: Dictionary = {}

func clear() -> void:
	fingers.clear()
	offsets.clear()
	for paddle in paddles:
		paddle.target = paddle.position

func press(finger: int, point: Vector2) -> void:
	if not layout.bounds.has_point(point):
		return
	var player := 0 if point.y >= layout.center.y else 1
	if player == 1 and player_count == 1:
		return
	if fingers.values().has(player):
		return
	fingers[finger] = player
	offsets[finger] = paddles[player].position - point

func drag(finger: int, point: Vector2) -> void:
	if fingers.has(finger):
		paddles[fingers[finger]].target = point + offsets[finger]

func release(finger: int) -> void:
	fingers.erase(finger)
	offsets.erase(finger)
