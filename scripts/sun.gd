extends DirectionalLight3D

func _ready():
	# Tell the global TimeManager "I am the sun!"
	if TimeManager:
		TimeManager.register_sun(self)
