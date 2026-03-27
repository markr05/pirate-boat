extends Node

func calculate_xp_level(experience: float) -> int:
	var level = experience / 99.9
	return ceil(level)
	
