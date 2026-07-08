extends CanvasLayer

@onready var inventory_view: Control = $Background/MenuContainer/InventoryView
@onready var map_view: Control = $Background/MenuContainer/MapView

@onready var inventory_button: Button = $Background/MenuContainer/Tabs/InventoryButton
@onready var map_button: Button = $Background/MenuContainer/Tabs/MapButton

@onready var item_grid: GridContainer = $Background/MenuContainer/InventoryView/ItemGrid
@onready var item_title: Label = $Background/MenuContainer/InventoryView/DescriptionPanel/VBoxContainer/ItemTitle
@onready var item_desc: Label = $Background/MenuContainer/InventoryView/DescriptionPanel/VBoxContainer/ItemDesc

# Simple local item database matching your exact naming style for descriptions
var item_info: Dictionary = {
	"needle": {"name": "The Needle", "desc": "A sharp, elegant weapon used to slash enemies and channel silk."},
	"cogwork_battery": {"name": "Cogwork Battery", "desc": "A buzzing brass cell filled with residual energy. Powers strange machinery."},
	"key_to_lab_21": {"name": "Lab 21 Key", "desc": "An old, grease-stained key. Accesses the restricted sector of the Desultory Lab."},
	"health_upgrade": {"name": "Mask Shard", "desc": "An ancient fragment. Collect more to increase your maximum health."},
	"silk_upgrade": {"name": "Silk Vessel", "desc": "A fragile spool that increases your maximum capacity for silk."}
}

func _ready() -> void:
	hide()
	
	# Connect your top navigation buttons
	inventory_button.pressed.connect(show_inventory_tab)
	map_button.pressed.connect(show_map_tab)
	
	# Loop through your TextureRects inside the ItemGrid to catch mouse hover events
	for slot in item_grid.get_children():
		if slot is TextureRect:
			slot.focus_mode = Control.FOCUS_ALL
			slot.focus_entered.connect(_on_item_focused.bind(slot.name))
			slot.mouse_entered.connect(func(): if slot.visible: slot.grab_focus())

func _process(_delta: float) -> void:
	# Check for the inventory shortcut key 'Q'
	if Input.is_action_just_pressed("toggle_inventory"):
		if visible:
			close_menu()
		else:
			open_menu()

func open_menu() -> void:
	show()
	get_tree().paused = true
	
	# 1. Hide/Show items first
	update_inventory_display()
	
	# 2. Build navigation map ONLY using the visible items!
	setup_navigation_paths()
	
	show_inventory_tab() # Defaults to inventory view upon opening
	
	# 3. Focus on the first VISIBLE item if the player owns anything
	var visible_items = item_grid.get_children().filter(func(node): return node.visible)
	if visible_items.size() > 0:
		visible_items[0].grab_focus()
	else:
		# If player has absolutely zero items, default focus directly to the tabs instead
		inventory_button.grab_focus()

func close_menu() -> void:
	hide()
	get_tree().paused = false

func show_inventory_tab() -> void:
	inventory_view.show()
	map_view.hide()

func show_map_tab() -> void:
	inventory_view.hide()
	map_view.show()

func update_inventory_display() -> void:
	# Clear out the text boxes by default in case nothing is highlighted yet
	item_title.text = "???"
	item_desc.text = "Select an item to inspect."
	
	# Update every item visibility based on your real global data
	for slot in item_grid.get_children():
		var item_id = slot.name
		var player_owns_it: bool = false
		
		# Specialized check for the needle since it lives in its own Global variable
		if item_id == "needle":
			player_owns_it = Global.has_needle
		else:
			player_owns_it = Global.collected_items.has(item_id)
		
		# Toggle visibility completely
		slot.visible = player_owns_it

func setup_navigation_paths() -> void:
	# Get a clean array containing ONLY the slots that are currently visible
	var visible_items = item_grid.get_children().filter(func(node): return node.visible)
	
	# Clear fallback links on tabs if no items are held
	inventory_button.focus_neighbor_right = map_button.get_path()
	map_button.focus_neighbor_left = inventory_button.get_path()
	
	if visible_items.size() == 0:
		# If the inventory is completely empty, tabs just cycle between each other
		inventory_button.focus_neighbor_left = map_button.get_path()
		map_button.focus_neighbor_right = inventory_button.get_path()
		return
		
	var first_item = visible_items[0] as Control
	var last_item = visible_items[visible_items.size() - 1] as Control
	
	# Clean out default left/right path maps for all visible items first so they follow natural grid order
	for i in range(visible_items.size()):
		var item = visible_items[i] as Control
		item.focus_neighbor_right = NodePath("")
		item.focus_neighbor_left = NodePath("")
	
	# 1. Last visible item to Map button link
	last_item.focus_neighbor_right = map_button.get_path()
	
	# 2. Map button to Inventory tab wrap-around link
	# When on the Map tab button, hitting Right Arrow goes to the Inventory tab button
	map_button.focus_neighbor_right = inventory_button.get_path()
	
	# 3. Inventory tab to First visible item wrap-around link
	inventory_button.focus_neighbor_right = first_item.get_path()
	
	# 4. Reverse cycling directions (Left Arrow Support)
	first_item.focus_neighbor_left = inventory_button.get_path()
	inventory_button.focus_neighbor_left = map_button.get_path()
	map_button.focus_neighbor_left = last_item.get_path()
	
func _on_item_focused(item_id: String) -> void:
	# Automatically switch to inventory view tab if an item gets focus
	if not inventory_view.visible:
		show_inventory_tab()

	var player_owns_it: bool = (item_id == "needle" and Global.has_needle) or Global.collected_items.has(item_id)
	
	if player_owns_it and item_info.has(item_id):
		item_title.text = item_info[item_id]["name"]
		item_desc.text = item_info[item_id]["desc"]

func _on_item_slot_input(event: InputEvent, item_id: String) -> void:
	# Detect when the mouse hovers or clicks an item to display information
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		var player_owns_it: bool = (item_id == "needle" and Global.has_needle) or Global.collected_items.has(item_id)
		
		if player_owns_it and item_info.has(item_id):
			item_title.text = item_info[item_id]["name"]
			item_desc.text = item_info[item_id]["desc"]
