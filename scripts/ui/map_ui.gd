extends CanvasLayer

# --- REFERENCES ---
# Drag and drop your nodes into these exports in the Inspector
@export var option_button: OptionButton
@export var confirmation_checkbox: CheckBox

# --- CONFIGURATION ---
# Dictionary to map the OptionButton text to actual Scene Files
# Format: "Visible Name": "res://path_to_scene.tscn"
var scene_map: Dictionary = {
	"Main Level": "res://scenes/main.tscn",
}

func _ready() -> void:
	# 1. Clear placeholder items and fill OptionButton from our Map
	option_button.clear()
	for scene_name in scene_map.keys():
		option_button.add_item(scene_name)
	
	# 2. Connect the checkbox signal
	# We use 'toggled' because a CheckBox is a button that stays on/off
	confirmation_checkbox.toggled.connect(_on_checkbox_toggled)

func _on_checkbox_toggled(is_checked: bool) -> void:
	# Only proceed if the box was checked (not unchecked)
	if is_checked:
		launch_selected_scene()

func launch_selected_scene() -> void:
	# Get the text of the currently selected item
	var selected_idx = option_button.get_selected_id()
	var selected_text = option_button.get_item_text(selected_idx)
	
	# Look up the file path in our dictionary
	if scene_map.has(selected_text):
		var scene_path = scene_map[selected_text]
		
		# Change the scene
		print("Switching to: ", selected_text)
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("Selected item does not have a mapped scene path!")
		# Uncheck the box so the player can try again
		confirmation_checkbox.button_pressed = false
