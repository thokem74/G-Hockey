class_name MatchOptions
extends Resource

@export_range(1, 2) var player_count: int = 1
@export_range(0, 3) var difficulty: int = 1
@export_enum("3", "5", "7", "10") var winning_score_index: int = 2

func winning_score() -> int:
	return [3, 5, 7, 10][winning_score_index]
