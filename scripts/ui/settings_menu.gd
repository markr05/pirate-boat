extends CanvasLayer
@onready var sensitivity_label: Node = $MarginContainer/GridContainer/SensitivityMargin/Label
@onready var music_label: Node = $MarginContainer/GridContainer/MusicMargin/Label
@onready var sfx_label: Node = $MarginContainer/GridContainer/SfxMargin/Label

@onready var sens_slider: HSlider = $MarginContainer/GridContainer/SensitivityMargin/HSlider
@onready var music_slider: HSlider = $MarginContainer/GridContainer/MusicMargin/HSlider
@onready var sfx_slider: HSlider = $MarginContainer/GridContainer/SfxMargin/HSlider

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 1. Initialize Sensitivity
	# We reverse the math: if Global is (val * .0001), then val is (Global / .0001)
	var current_sens_val = GlobalSettings.look_sensitivity / 0.0001
	sens_slider.value = current_sens_val
	sensitivity_label.text = "%d" % current_sens_val

	# 2. Initialize Music
	var music_bus = AudioServer.get_bus_index("Music")
	# We convert the DB back to a 0-100 linear value
	var music_val = db_to_linear(AudioServer.get_bus_volume_db(music_bus)) * 100
	music_slider.value = music_val
	music_label.text = "%d" % music_val

	# 3. Initialize SFX
	var sfx_bus = AudioServer.get_bus_index("Sfx")
	var sfx_val = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)) * 100
	sfx_slider.value = sfx_val
	sfx_label.text = "%d" % sfx_val


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_music_value_changed(value: float) -> void:
	music_label.text = "%d" % value
	
	# Get the index of the "Music" bus
	var bus_index = AudioServer.get_bus_index("Music")
	
	# Convert slider (0.0 to 1.0) to decibels
	# Note: If your slider is 0-100, use (value / 100.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))
	
	# Mute if the slider is at 0
	AudioServer.set_bus_mute(bus_index, value == 0)


func _on_sfx_value_changed(value: float) -> void:
	sfx_label.text = "%d" % value
	
	var bus_index = AudioServer.get_bus_index("Sfx")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))
	AudioServer.set_bus_mute(bus_index, value == 0)


func _on_sens_value_changed(value: float) -> void:
	GlobalSettings.look_sensitivity = value * .0001
	sensitivity_label.text = "%d" % value
