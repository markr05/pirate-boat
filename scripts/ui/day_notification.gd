extends CanvasLayer

@onready var day_label = $MarginContainer/Label
@onready var anim_player = $AnimationPlayer

func _ready():
	# The UI connects directly to the global manager
	TimeManager.day_started.connect(_on_day_started)
	

func _on_day_started(number: int):
	day_label.text = "Day " + str(number)
	anim_player.play("show_day")
