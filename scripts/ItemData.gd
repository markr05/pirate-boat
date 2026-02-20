extends Resource
class_name ItemData

@export var name: String = ""
@export var icon: Texture2D 
@export var description: String = ""
@export var equippable_scene: PackedScene 
@export var ground_mesh: Mesh
@export var stackable: bool = false
@export var max_stack_size: int = 64
@export var is_sellable: bool = true
@export var price: int = 0
@export var action_data: ActionData
	
