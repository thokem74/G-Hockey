extends HSlider

## Add native finger dragging without enabling mouse emulation during gameplay.

var finger_index: int = -1

func _ready() -> void:
	set_process_input(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release_finger()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_release_finger()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and editable:
		accept_event()
		if event.pressed and not event.canceled and finger_index == -1:
			finger_index = event.index
			set_process_input(true)
			grab_focus()
			_set_value_from_position(event.position.x)

func _input(event: InputEvent) -> void:
	# Capture the owning finger even when it moves beyond the slider's rectangle.
	if event is InputEventScreenDrag and event.index == finger_index:
		var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		_set_value_from_position(local_position.x)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == finger_index:
		if not event.pressed or event.canceled:
			_release_finger()
		get_viewport().set_input_as_handled()

func _set_value_from_position(local_x: float) -> void:
	# Match the thumb's travel so touching its center preserves the current value.
	var grabber_width := float(get_theme_icon("grabber").get_width())
	var travel := maxf(size.x - grabber_width, 1.0)
	var fraction := clampf((local_x - grabber_width * 0.5) / travel, 0.0, 1.0)
	value = lerpf(min_value, max_value, fraction)

func _release_finger() -> void:
	finger_index = -1
	set_process_input(false)
