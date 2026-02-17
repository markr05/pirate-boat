extends StaticBody3D

# --- EXPORTS ---
@export var chest_inventory: Array[ItemData] = []
@export var chest_name: String = "Old Wooden Box"

# --- COMPONENTS ---
# Optional: If you add an AnimationPlayer node to the chest later, this will work automatically.
#@onready var anim_player: AnimationPlayer = $AnimationPlayer

# --- STATE ---
var is_open: bool = false
var current_player: CharacterBody3D = null

func _ready():
	# Ensure the chest starts closed visually if needed
	#if anim_player and anim_player.has_animation("Close"):
		#anim_player.play("Close")
	
	# 2. THE FIX: Find the menu and Force Hide it immediately
	var menus = get_tree().get_nodes_in_group("inventory_menu")
	if menus.size() > 0:
		menus[0].visible = false # Force hide
		
	# 3. Ensure mouse is captured so you can look around
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# --- INTERACTION ---
# This function is called by the Player Controller via Raycast
# We receive the 'player' variable so we know who opened it
func interact(player):
	current_player = player
	
	if is_open:
		close_chest()
	else:
		open_chest()

func open_chest():
	is_open = true
	print("Opening Chest: ", chest_name)

	# 1. Visuals
	#if anim_player and anim_player.has_animation("Open"):
		#anim_player.play("Open")
		
	# 2. Find UI Components
	var grids = get_tree().get_nodes_in_group("inventory_grid")
	var menus = get_tree().get_nodes_in_group("inventory_menu")
	
	if grids.size() > 0 and menus.size() > 0:
		var inventory_ui = grids[0]
		var ui_container = menus[0]
		
		# 3. Show UI and Unlock Mouse
		ui_container.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# 4. Lock Player Movement
		if current_player:
			current_player.is_menu_open = true

		# 5. Build the Grid
		# Rebuild the grid slots to match this chest's size
		inventory_ui.setup_grid(inventory_ui.columns_count, inventory_ui.total_slots)
		
		# WAIT ONE FRAME: This is the critical fix to ensure slots are created before we fill them
		await get_tree().process_frame
		
		# 6. Fill the slots with chest items
		for i in range(chest_inventory.size()):
			# Check if the index is within the grid's limit to prevent crashes
			if i < chest_inventory.size() and chest_inventory[i] != null:
				inventory_ui.set_item_at_slot(i, chest_inventory[i])
	else:
		print("Error: Could not find 'inventory_grid' or 'inventory_menu' groups! Check your HUD scene.")

func close_chest():
	is_open = false
	print("Closing Chest")

	# 1. Visuals
	#if anim_player:
		#if anim_player.has_animation("Close"):
			#anim_player.play("Close")
		#elif anim_player.has_animation("Open"):
			#anim_player.play_backwards("Open")

	# 2. Hide UI
	var menus = get_tree().get_nodes_in_group("inventory_menu")
	if menus.size() > 0:
		menus[0].hide()

	# 3. Restore Player State
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if current_player:
		current_player.is_menu_open = false
		current_player = null # Clear the reference
