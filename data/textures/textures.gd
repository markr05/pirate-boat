extends Node

# Drag your .tres file into this slot in the inspector
@export var noise_res : NoiseTexture2D 

func _ready():
	if noise_res:
		await noise_res.changed 
		
		var img = noise_res.get_image()
		
		img.save_png("res://data/textures/grass_normal_baked.png")
		print("Successfully saved image!")
