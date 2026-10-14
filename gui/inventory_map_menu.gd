extends CanvasLayer

@onready var inventory_view: Control = $Background/MenuContainer/InventoryView
@onready var map_view: Control = $Background/MenuContainer/MapView
@onready var wishs_view: Control = $Background/MenuContainer/WishsView
@onready var modules_view: Control = $Background/MenuContainer/ModulesView

@onready var inventory_button: Button = $Background/MenuContainer/Tabs/InventoryButton
@onready var map_button: Button = $Background/MenuContainer/Tabs/MapButton
@onready var wishs_button: Button = $Background/MenuContainer/Tabs/WishsButton
@onready var modules_button: Button = $Background/MenuContainer/Tabs/ModulesButton

@onready var item_grid: GridContainer = $Background/MenuContainer/InventoryView/ItemGrid
@onready var item_title: Label = $Background/MenuContainer/InventoryView/DescriptionPanel/MarginContainer/VBoxContainer/ItemTitle
@onready var item_desc: Label = $Background/MenuContainer/InventoryView/DescriptionPanel/MarginContainer/VBoxContainer/ItemDesc
@onready var shards_label: Label = $Background/MenuContainer/InventoryView/ShardsLabel

@onready var wish_grid: VBoxContainer = $Background/MenuContainer/WishsView/WishGrid
@onready var wish_title: Label = $Background/MenuContainer/WishsView/DescriptionPanel/MarginContainer/VBoxContainer/WishTitle
@onready var wish_desc: Label = $Background/MenuContainer/WishsView/DescriptionPanel/MarginContainer/VBoxContainer/WishDesc

@onready var module_slots: HBoxContainer = $Background/MenuContainer/ModulesView/ModuleSlots
@onready var module_list: VBoxContainer = $Background/MenuContainer/ModulesView/ModuleScroll/ModuleList
@onready var module_empty_label: Label = $Background/MenuContainer/ModulesView/ModuleScroll/ModuleList/EmptyModulesLabel
@onready var module_title: Label = $Background/MenuContainer/ModulesView/DescriptionPanel/MarginContainer/VBoxContainer/ModuleTitle
@onready var module_desc: Label = $Background/MenuContainer/ModulesView/DescriptionPanel/MarginContainer/VBoxContainer/ModuleDesc

var module_slot_buttons: Array[Button] = []
var selected_module_slot: int = 0

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
	wishs_button.pressed.connect(show_wishs_tab)
	modules_button.pressed.connect(show_modules_tab)
	for slot_index in range(module_slots.get_child_count()):
		var slot_button = module_slots.get_child(slot_index) as Button
		module_slot_buttons.append(slot_button)
		slot_button.pressed.connect(_on_module_slot_pressed.bind(slot_index))
	
	# Connect focus events directly to the nodes themselves
	for slot in item_grid.get_children():
		if slot is TextureRect:
			slot.focus_mode = Control.FOCUS_ALL
			slot.focus_entered.connect(_on_item_focused.bind(slot))
			slot.focus_exited.connect(_on_item_unfocused.bind(slot))
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
	
	# 2. Update wishes display
	update_wishs_display()
	update_modules_display()
	
	# 3. Build navigation map ONLY using the visible items!
	setup_navigation_paths()
	show_inventory_tab()
	
	# Focus on the first visible item
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
	wishs_view.hide()
	modules_view.hide()

func show_map_tab() -> void:
	inventory_view.hide()
	map_view.show()
	wishs_view.hide()
	modules_view.hide()

func show_wishs_tab() -> void:
	inventory_view.hide()
	map_view.hide()
	wishs_view.show()
	modules_view.hide()

func show_modules_tab() -> void:
	inventory_view.hide()
	map_view.hide()
	wishs_view.hide()
	modules_view.show()

func update_modules_display() -> void:
	module_title.text = "Modules"
	module_desc.text = "Choose a slot above, then select a module below to equip it."
	for child in module_list.get_children():
		if child != module_empty_label:
			child.queue_free()

	module_empty_label.visible = Global.collected_modules.is_empty()
	for module_id in Global.collected_modules:
		var module_data = Global.get_module_data(module_id)
		var module_button = Button.new()
		module_button.name = "Module_" + module_id
		module_button.custom_minimum_size = Vector2(650, 76)
		module_button.icon = _get_module_icon(module_data)
		module_button.icon_max_width = 54
		module_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		module_button.text_alignment = HORIZONTAL_ALIGNMENT_LEFT
		module_button.focus_mode = Control.FOCUS_ALL
		module_button.focus_entered.connect(_on_module_focused.bind(module_button, module_id))
		module_button.focus_exited.connect(_on_module_unfocused.bind(module_button))
		module_button.pressed.connect(_on_module_activated.bind(module_id))
		module_button.mouse_entered.connect(func(): module_button.grab_focus())
		module_list.add_child(module_button)

	_refresh_module_slots()
	_refresh_module_buttons()

func _get_module_icon(module_data: Dictionary) -> Texture2D:
	var image_path: String = module_data.get("image_path", "")
	if not image_path.is_empty() and ResourceLoader.exists(image_path):
		return load(image_path) as Texture2D
	return load("res://assets/images/item/item.png") as Texture2D

func _refresh_module_slots() -> void:
	for slot_index in range(module_slot_buttons.size()):
		var module_id = Global.equipped_modules[slot_index]
		var slot_button = module_slot_buttons[slot_index]
		slot_button.button_pressed = slot_index == selected_module_slot
		if module_id.is_empty():
			slot_button.text = "Slot %d\nEmpty" % (slot_index + 1)
			slot_button.icon = null
		else:
			var module_data = Global.get_module_data(module_id)
			slot_button.text = "Slot %d\n%s" % [slot_index + 1, module_data.name]
			slot_button.icon = _get_module_icon(module_data)

func _refresh_module_buttons() -> void:
	for child in module_list.get_children():
		if not child is Button:
			continue
		var module_id = child.name.trim_prefix("Module_")
		var module_data = Global.get_module_data(module_id)
		var equipped_slot = Global.equipped_modules.find(module_id)
		child.text = module_data.name
		if equipped_slot >= 0:
			child.text += "  (Equipped: Slot %d)" % (equipped_slot + 1)

func _on_module_slot_pressed(slot_index: int) -> void:
	selected_module_slot = slot_index
	_refresh_module_slots()
	var focused_control = get_viewport().gui_get_focus_owner()
	if focused_control is Button and focused_control.name.begins_with("Module_"):
		_on_module_focused(focused_control, focused_control.name.trim_prefix("Module_"))

func _on_module_focused(module_button: Button, module_id: String) -> void:
	if not modules_view.visible:
		show_modules_tab()
	var module_data = Global.get_module_data(module_id)
	var equipped_slot = Global.equipped_modules.find(module_id)
	module_button.modulate = Color(1.6, 1.6, 1.6, 1.0)
	module_title.text = module_data.name
	module_desc.text = module_data.description
	if equipped_slot == selected_module_slot:
		module_desc.text += "\n\nPress Enter or click to unequip this module."
	else:
		module_desc.text += "\n\nPress Enter or click to equip it in Slot %d." % (selected_module_slot + 1)

func _on_module_unfocused(module_button: Button) -> void:
	module_button.modulate = Color(1, 1, 1, 1)

func _on_module_activated(module_id: String) -> void:
	var equipped_slot = Global.equipped_modules.find(module_id)
	if equipped_slot == selected_module_slot:
		Global.unequip_module(equipped_slot)
	else:
		if not Global.equip_module(module_id, selected_module_slot):
			module_title.text = "No Empty Slots"
			module_desc.text = "Choose one of the three slots above, then activate a collected module."
			return
	Global.save_game()
	_refresh_module_slots()
	_refresh_module_buttons()
	for child in module_list.get_children():
		if child is Button and child.name == "Module_" + module_id:
			_on_module_focused(child, module_id)
			break

func update_inventory_display() -> void:
	shards_label.text = "Shards: " + str(Global.shards_collected)
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
		# Reset tint to normal full color when hidden or drawn
		slot.modulate = Color(1, 1, 1, 1)

func update_wishs_display() -> void:
	# Clear the wish grid
	for child in wish_grid.get_children():
		child.queue_free()
	
	# Clear description boxes
	wish_title.text = "???"
	wish_desc.text = "Select a wish to inspect."
	
	# Get all accepted wishes
	var accepted_wishes = Global.get_all_accepted_wishes()
	
	if accepted_wishes.is_empty():
		wish_title.text = "No Wishes"
		wish_desc.text = "Complete quests to unlock wishes."
		return
	
	# Create wish items for each accepted wish
	for wish_id in accepted_wishes:
		var wish_data = Global.get_wish(wish_id)
		if wish_data.is_empty():
			continue
		
		var wish_container = HBoxContainer.new()
		wish_container.custom_minimum_size = Vector2(650, 100)
		wish_container.add_theme_constant_override("separation", 15)
		wish_container.name = wish_id
		
		# Wish image with styled background
		var wish_image_bg = PanelContainer.new()
		wish_image_bg.custom_minimum_size = Vector2(110, 110)
		wish_image_bg.self_modulate = Color(0.8, 0.8, 0.8, 1.0)
		
		var wish_image = TextureRect.new()
		wish_image.custom_minimum_size = Vector2(100, 100)
		wish_image.expand_mode = 2  # EXPAND_FIT_WIDTH_IGNORING_ASPECT_RATIO
		if ResourceLoader.exists(wish_data.image_path):
			wish_image.texture = load(wish_data.image_path)
		else:
			# Placeholder if image doesn't exist
			wish_image.modulate = Color(0.5, 0.5, 0.5, 1.0)
		
		wish_image_bg.add_child(wish_image)
		wish_container.add_child(wish_image_bg)
		
		# Content: Name and Progress (for multi-item wishes)
		var content = VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Wish name
		var name_label = Label.new()
		name_label.text = wish_data.name
		name_label.add_theme_font_size_override("font_size", 20)
		content.add_child(name_label)
		
		# Progress bar (only for collect_items wishes with multiple items)
		if wish_data.type == "collect_items" and wish_data.required_items.size() > 0:
			var total_items = 0
			var collected_items = 0
			
			# Calculate total and collected
			for item_name in wish_data.required_items:
				var required = wish_data.required_items[item_name]
				total_items += required
				var progress = Global.get_wish_progress(wish_id)
				collected_items += progress.get(item_name, 0)
			
			# Show progress bar only if more than one item type or quantity > 1
			if total_items > 1:
				var progress_label = Label.new()
				progress_label.text = "%d / %d collected" % [collected_items, total_items]
				progress_label.add_theme_font_size_override("font_size", 14)
				content.add_child(progress_label)
				
				var progress_bar = ProgressBar.new()
				progress_bar.min_value = 0
				progress_bar.max_value = total_items
				progress_bar.value = collected_items
				progress_bar.custom_minimum_size = Vector2(200, 20)
				content.add_child(progress_bar)
		
		wish_container.add_child(content)
		
		# Make it focusable
		wish_container.focus_mode = Control.FOCUS_ALL
		wish_container.focus_entered.connect(_on_wish_focused.bind(wish_container, wish_id))
		wish_container.focus_exited.connect(_on_wish_unfocused)
		wish_container.mouse_entered.connect(func(): wish_container.grab_focus())
		
		wish_grid.add_child(wish_container)
	
	# Focus on first wish if available
	if wish_grid.get_child_count() > 0:
		wish_grid.get_child(0).grab_focus()

func setup_navigation_paths() -> void:
	# Get a clean array containing ONLY the slots that are currently visible
	var visible_items = item_grid.get_children().filter(func(node): return node.visible)
	
	# Set up tab navigation: Inventory -> Modules -> Wishes -> Map -> Inventory
	inventory_button.focus_neighbor_right = modules_button.get_path()
	modules_button.focus_neighbor_left = inventory_button.get_path()
	modules_button.focus_neighbor_right = wishs_button.get_path()
	wishs_button.focus_neighbor_left = modules_button.get_path()
	wishs_button.focus_neighbor_right = map_button.get_path()
	map_button.focus_neighbor_left = wishs_button.get_path()
	map_button.focus_neighbor_right = inventory_button.get_path()
	inventory_button.focus_neighbor_left = map_button.get_path()
	
	if visible_items.size() == 0:
		# If the inventory is completely empty, tabs cycle but items aren't involved
		return
		
	var first_item = visible_items[0] as Control
	var last_item = visible_items[visible_items.size() - 1] as Control
	
	# CLEAN ALL NEIGHBORS: Stops hidden elements from pulling focus up or down randomly
	for item in visible_items:
		item.focus_neighbor_right = NodePath("")
		item.focus_neighbor_left = NodePath("")
		item.focus_neighbor_top = NodePath("")
		item.focus_neighbor_bottom = NodePath("")
	
	# 1. Last item -> Modules button (first tab after items)
	last_item.focus_neighbor_right = modules_button.get_path()
	
	# 2. Inventory button -> First item
	inventory_button.focus_neighbor_right = first_item.get_path()
	
	# 3. Reverse cycling directions (Left Arrow Support)
	first_item.focus_neighbor_left = inventory_button.get_path()
	inventory_button.focus_neighbor_left = map_button.get_path()
	wishs_button.focus_neighbor_left = modules_button.get_path()
	map_button.focus_neighbor_left = wishs_button.get_path()
	
	# 4. Prevent UP Arrow on items from breaking UI. It will now jump cleanly back up to the tabs
	for item in visible_items:
		item.focus_neighbor_top = inventory_button.get_path()

func _on_item_focused(slot: TextureRect) -> void:
	if not inventory_view.visible:
		show_inventory_tab()

	var item_id = slot.name
	var player_owns_it: bool = (item_id == "needle" and Global.has_needle) or Global.collected_items.has(item_id)
	
	if player_owns_it:
		slot.modulate = Color(1.6, 1.6, 1.6, 1.0) 
		
		if item_info.has(item_id):
			item_title.text = item_info[item_id]["name"]
			item_desc.text = item_info[item_id]["desc"]
	else:
		# Fallback just in case a hidden or missing item somehow triggers focus
		slot.modulate = Color(1, 1, 1, 1) # Keep normal tint if they don't own it
		item_title.text = "???"
		item_desc.text = "An undiscovered artifact hidden somewhere in the world."

func _on_item_unfocused(slot: TextureRect) -> void:
	# RESET TINT: Return back to default white lighting
	slot.modulate = Color(1, 1, 1, 1)
	item_title.text = ""
	item_desc.text = ""

func _on_item_slot_input(event: InputEvent, item_id: String) -> void:
	# Detect when the mouse hovers or clicks an item to display information
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		var player_owns_it: bool = (item_id == "needle" and Global.has_needle) or Global.collected_items.has(item_id)
		
		if player_owns_it and item_info.has(item_id):
			item_title.text = item_info[item_id]["name"]
			item_desc.text = item_info[item_id]["desc"]

func _on_wish_focused(wish_container: HBoxContainer, wish_id: String) -> void:
	if not wishs_view.visible:
		show_wishs_tab()
	
	var wish_data = Global.get_wish(wish_id)
	if wish_data.is_empty():
		return
	
	# Update title and description
	wish_title.text = wish_data.name
	wish_desc.text = wish_data.description
	
	# Add progress info for collect_items wishes
	if wish_data.type == "collect_items":
		var progress_info = "\n\nRequired Items:\n"
		for item_name in wish_data.required_items:
			var required = wish_data.required_items[item_name]
			var progress = Global.get_wish_progress(wish_id)
			var collected = progress.get(item_name, 0)
			progress_info += "%s %s: %d / %d\n" % [item_name, "(collected)" if collected >= required else "", collected, required]
		wish_desc.text += progress_info
	
	# Highlight the container
	wish_container.modulate = Color(1.6, 1.6, 1.6, 1.0)

func _on_wish_unfocused() -> void:
	# Reset all wish containers' modulate and clear description
	for child in wish_grid.get_children():
		if child is HBoxContainer:
			child.modulate = Color(1, 1, 1, 1)
	wish_title.text = ""
	wish_desc.text = ""
