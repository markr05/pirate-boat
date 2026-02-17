extends Resource
class_name ItemData

@export var name: String = ""
@export var icon: Texture2D 
@export var description: String = ""
@export var equippable_scene: PackedScene 
@export var ground_mesh: Mesh

# --- NEW STACKING VARIABLES ---
@export var stackable: bool = false
@export var max_stack_size: int = 64
