extends ProgressBar

var fill_style = StyleBoxFlat.new()

func _ready():
	# Set the bar to green once at the start
	fill_style.bg_color = Color.GREEN
	
	# Inject our custom style so it overrides the default look
	add_theme_stylebox_override("fill", fill_style)

func update_hp(current_hp: float, max_hp: float):
	if max_hp <= 0: return
	
	# Update the actual bar value (this handles the shrinking/growing)
	value = (current_hp / max_hp) * 100
