extends ProgressBar

var fill_style = StyleBoxFlat.new()

func _ready():
	# Set the bar to green once at the start
	fill_style.bg_color = Color.YELLOW
	
	# Inject our custom style so it overrides the default look
	add_theme_stylebox_override("fill", fill_style)

func update_stamina(current_stamina: float, max_stamina: float):
	if max_stamina <= 0: return
	
	# Update the actual bar value (this handles the shrinking/growing)
	value = (current_stamina / max_stamina) * 100
