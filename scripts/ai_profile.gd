class_name AIProfile
extends Resource

@export var display_name: String = "Normal"
@export var reaction_seconds: float = 0.16
@export var movement_speed: float = 680.0
@export var aiming_error: float = 40.0
@export_range(0.0, 1.0) var prediction_weight: float = 0.4
