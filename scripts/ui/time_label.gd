extends Label


func _process(_delta: float) -> void:
	text = SimClock.label()
