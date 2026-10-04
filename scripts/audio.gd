extends Node

const SOUNDS := {
	"wall": preload("res://assets/audio/wall.wav"),
	"paddle": preload("res://assets/audio/paddle.wav"),
	"countdown": preload("res://assets/audio/countdown.wav"),
	"goal": preload("res://assets/audio/goal.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
	"click": preload("res://assets/audio/click.wav"),
}

@onready var voices: Array[Node] = $Voices.get_children()

var next_voice: int = 0

func play_sound(sound_name: String, strength: float = 1.0) -> void:
	if Settings.effects_volume <= 0.0 or DisplayServer.get_name() == "headless":
		return
	var voice := voices[next_voice] as AudioStreamPlayer
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = SOUNDS[sound_name]
	voice.volume_db = linear_to_db(maxf(Settings.effects_volume * clampf(strength, 0.15, 1.0), 0.0001))
	voice.play()

func stop_all() -> void:
	for voice in voices:
		voice.stop()

func _exit_tree() -> void:
	stop_all()
