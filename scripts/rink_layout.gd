class_name RinkLayout
extends Resource

## Geometry shared by the scene, physics, touch input, and AI.
## Units are based on a 720-wide canvas; only its height changes with the display.

const LOGICAL_WIDTH := 720.0
const POST_RADIUS := 6.0

@export var logical_size := Vector2(720, 1280)
@export var rail_inset: float = 12.0
@export var goal_width: float = 180.0

var bounds: Rect2:
	get:
		return Rect2(Vector2.ONE * rail_inset, logical_size - Vector2.ONE * rail_inset * 2.0)
var center: Vector2:
	get:
		return logical_size * 0.5
var goal_left: float:
	get:
		return center.x - goal_width * 0.5
var goal_right: float:
	get:
		return center.x + goal_width * 0.5
var goal_posts := PackedVector2Array()

func configure(size: Vector2) -> void:
	logical_size = size
	goal_posts = PackedVector2Array([
		Vector2(goal_left, bounds.position.y), Vector2(goal_right, bounds.position.y),
		Vector2(goal_left, bounds.end.y), Vector2(goal_right, bounds.end.y),
	])

func paddle_court(player: int, radius: float) -> Rect2:
	var inset_bounds := bounds.grow(-radius)
	var first_y := center.y + radius if player == 0 else inset_bounds.position.y
	var last_y := inset_bounds.end.y if player == 0 else center.y - radius
	return Rect2(Vector2(inset_bounds.position.x, first_y), Vector2(inset_bounds.size.x, last_y - first_y))

func paddle_start(player: int) -> Vector2:
	return Vector2(center.x, bounds.position.y + bounds.size.y * (0.84 if player == 0 else 0.16))

func serve_position(player: int) -> Vector2:
	return Vector2(center.x, bounds.position.y + bounds.size.y * (0.65 if player == 0 else 0.35))

func goal_position(player: int) -> Vector2:
	return Vector2(center.x, bounds.position.y if player == 0 else bounds.end.y)

func remap_position(point: Vector2, previous_bounds: Rect2) -> Vector2:
	var fraction := (point - previous_bounds.position) / previous_bounds.size
	return bounds.position + fraction * bounds.size
