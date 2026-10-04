extends Node

const SAVE_PATH := "user://settings.cfg"

var music_volume: float = 0.55
var effects_volume: float = 0.8
var vibration: bool = true
var screen_shake: bool = true
var reduced_effects: bool = false

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		music_volume = clampf(float(config.get_value("audio", "music", 0.55)), 0.0, 1.0)
		effects_volume = clampf(float(config.get_value("audio", "effects", 0.8)), 0.0, 1.0)
		vibration = bool(config.get_value("feedback", "vibration", true))
		screen_shake = bool(config.get_value("feedback", "screen_shake", true))
		reduced_effects = bool(config.get_value("feedback", "reduced_effects", false))

func save() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "effects", effects_volume)
	config.set_value("feedback", "vibration", vibration)
	config.set_value("feedback", "screen_shake", screen_shake)
	config.set_value("feedback", "reduced_effects", reduced_effects)
	return config.save(SAVE_PATH)
