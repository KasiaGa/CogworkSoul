extends CanvasLayer

const SELECTION_OVERLAY_TEXTURE = preload("res://assets/images/gui/itemelected.png")

@onready var inventory_view: Control = $Background/MenuContainer/InventoryView
@onready var map_view: Control = $Background/MenuContainer/MapView
@onready var wishs_view: Control = $Background/MenuContainer/WishsView
@onready var modules_view: Control = $Background/MenuContainer/ModulesView
@onready var journal_view: Control = $Background/MenuContainer/JournalView

@onready var inventory_button: Button = $Background/MenuContainer/Tabs/InventoryButton
@onready var map_button: Button = $Background/MenuContainer/Tabs/MapButton
@onready var wishs_button: Button = $Background/MenuContainer/Tabs/WishsButton
@onready var modules_button: Button = $Background/MenuContainer/Tabs/ModulesButton
@onready var journal_button: Button = $Background/MenuContainer/Tabs/JournalButton
@onready var journal_gap: Control = $Background/MenuContainer/Tabs/JournalGap

@onready var item_grid: GridContainer = $Background/MenuContainer/InventoryView/ItemGrid
@onready var item_title: Label = $Background/MenuContainer/InventoryView/DescriptionPanel/MarginContainer/VBoxContainer/ItemTitleRow/ItemTitle
@onready var item_title_start_decor: TextureRect = $Background/MenuContainer/InventoryView/DescriptionPanel/MarginContainer/VBoxContainer/ItemTitleRow/TitleDecorStart
@onready var item_title_end_decor: TextureRect = $Background/MenuContainer/InventoryView/DescriptionPanel/MarginContainer/VBoxContainer/ItemTitleRow/TitleDecorEnd
@onready var item_desc: Label = $Background/MenuContainer/InventoryView/DescriptionPanel/MarginContainer/VBoxContainer/ItemDesc
@onready var item_selection_overlay: TextureRect = $Background/MenuContainer/InventoryView/ItemSelectionOverlay
@onready var shards_label: Label = $Background/MenuContainer/InventoryView/ShardsDisplay/ShardsLabel

@onready var wish_grid: VBoxContainer = $Background/MenuContainer/WishsView/WishGrid
@onready var wish_title: Label = $Background/MenuContainer/WishsView/DescriptionPanel/MarginContainer/VBoxContainer/WishTitleRow/WishTitle
@onready var wish_title_start_decor: TextureRect = $Background/MenuContainer/WishsView/DescriptionPanel/MarginContainer/VBoxContainer/WishTitleRow/TitleDecorStart
@onready var wish_title_end_decor: TextureRect = $Background/MenuContainer/WishsView/DescriptionPanel/MarginContainer/VBoxContainer/WishTitleRow/TitleDecorEnd
@onready var wish_desc: Label = $Background/MenuContainer/WishsView/DescriptionPanel/MarginContainer/VBoxContainer/WishDesc

@onready var module_slots: HBoxContainer = $Background/MenuContainer/ModulesView/ModuleSlots
@onready var module_list: VBoxContainer = $Background/MenuContainer/ModulesView/ModuleScroll/ModuleList
@onready var module_empty_label: Label = $Background/MenuContainer/ModulesView/ModuleScroll/ModuleList/EmptyModulesLabel
@onready var module_title: Label = $Background/MenuContainer/ModulesView/DescriptionPanel/MarginContainer/VBoxContainer/ModuleTitleRow/ModuleTitle
@onready var module_title_start_decor: TextureRect = $Background/MenuContainer/ModulesView/DescriptionPanel/MarginContainer/VBoxContainer/ModuleTitleRow/TitleDecorStart
@onready var module_title_end_decor: TextureRect = $Background/MenuContainer/ModulesView/DescriptionPanel/MarginContainer/VBoxContainer/ModuleTitleRow/TitleDecorEnd
@onready var module_desc: Label = $Background/MenuContainer/ModulesView/DescriptionPanel/MarginContainer/VBoxContainer/ModuleDesc
@onready var journal_enemy_grid: GridContainer = $Background/MenuContainer/JournalView/EnemyScroll/EnemyGrid
@onready var journal_artwork: TextureRect = $Background/MenuContainer/JournalView/EnemyArtwork
@onready var journal_artwork_fallback: Label = $Background/MenuContainer/JournalView/EnemyArtworkFallback
@onready var journal_enemy_name: Label = $Background/MenuContainer/JournalView/DescriptionPanel/MarginContainer/VBoxContainer/EnemyTitleRow/EnemyName
@onready var journal_title_start_decor: TextureRect = $Background/MenuContainer/JournalView/DescriptionPanel/MarginContainer/VBoxContainer/EnemyTitleRow/TitleDecorStart
@onready var journal_title_end_decor: TextureRect = $Background/MenuContainer/JournalView/DescriptionPanel/MarginContainer/VBoxContainer/EnemyTitleRow/TitleDecorEnd
@onready var journal_enemy_description: Label = $Background/MenuContainer/JournalView/DescriptionPanel/MarginContainer/VBoxContainer/EnemyDescription
@onready var journal_empty_label: Label = $Background/MenuContainer/JournalView/JournalEmptyLabel

var module_slot_buttons: Array[Button] = []
var selected_module_slot: int = -1
var journal_enemy_buttons: Dictionary = {}
var _scaled_icon_cache: Dictionary = {}
var _selected_item_slot: TextureRect
var _selection_pulse_tween: Tween
var _selection_decor_tweens: Dictionary = {}

# Simple local item database matching your exact naming style for descriptions
var item_info: Dictionary = {
	"needle": {"name": "Needle", "desc": "A sharp, elegant weapon used to slash enemies and channel silk."},
	"cogwork_battery": {"name": "Cogwork Battery", "desc": "A buzzing brass cell filled with residual energy. Powers strange machinery."},
	"key_to_lab_21": {"name": "Lab 21 Key", "desc": "An old, grease-stained key. Accesses the restricted sector of the Desultory Lab."},
	"health_upgrade": {"name": "Mask Shard", "desc": "An ancient fragment. Collect more to increase your maximum health."},
	"silk_upgrade": {"name": "Silk Vessel", "desc": "A fragile spool that increases your maximum capacity for silk."},
	"journal": {"name": "Journal", "desc": "A field journal for recording the creatures you defeat."},
	"flower": {"name": "Flower", "desc": "A beautiful flower found in the wild."}
}

func _ready() -> void:
	hide()
	
	# Connect your top navigation buttons
	inventory_button.pressed.connect(show_inventory_tab)
	map_button.pressed.connect(show_map_tab)
	wishs_button.pressed.connect(show_wishs_tab)
	modules_button.pressed.connect(show_modules_tab)
	journal_button.pressed.connect(show_journal_tab)
	for slot_index in range(module_slots.get_child_count()):
		var slot_button = module_slots.get_child(slot_index) as Button
		slot_button.add_theme_font_size_override("font_size", 14)
		_create_selection_overlay(slot_button, "SelectionOverlay")
		module_slot_buttons.append(slot_button)
		slot_button.focus_entered.connect(_on_module_slot_focused.bind(slot_index))
		slot_button.pressed.connect(_on_module_slot_pressed.bind(slot_index))
	for tab_button in [inventory_button, wishs_button, modules_button, journal_button, map_button]:
		tab_button.focus_entered.connect(_deselect_module_slot)
	
	# Connect focus events directly to the nodes themselves
	for slot in item_grid.get_children():
		if slot is TextureRect:
			slot.focus_mode = Control.FOCUS_ALL
			slot.focus_entered.connect(_on_item_focused.bind(slot))
			slot.focus_exited.connect(_on_item_unfocused.bind(slot))
			slot.gui_input.connect(_on_item_slot_input.bind(slot))
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
	_update_journal_access()
	update_journal_display()
	
	# 3. Build navigation map ONLY using the visible items!
	setup_navigation_paths()
	show_inventory_tab()
	
	# Start in the tab row; Down enters the selected tab's content.
	inventory_button.grab_focus()

func close_menu() -> void:
	_hide_item_selection()
	hide()
	get_tree().paused = false

func show_inventory_tab() -> void:
	_set_active_tab(inventory_button)
	inventory_view.show()
	map_view.hide()
	wishs_view.hide()
	modules_view.hide()
	journal_view.hide()

func show_map_tab() -> void:
	_set_active_tab(map_button)
	inventory_view.hide()
	map_view.show()
	wishs_view.hide()
	modules_view.hide()
	journal_view.hide()

func show_wishs_tab() -> void:
	_set_active_tab(wishs_button)
	inventory_view.hide()
	map_view.hide()
	wishs_view.show()
	modules_view.hide()
	journal_view.hide()

func show_modules_tab() -> void:
	_set_active_tab(modules_button)
	inventory_view.hide()
	map_view.hide()
	wishs_view.hide()
	modules_view.show()
	journal_view.hide()
	_refresh_module_slots()

func show_journal_tab() -> void:
	if not Global.collected_items.has(Global.JOURNAL_ITEM_ID):
		_update_journal_access()
		return
	_set_active_tab(journal_button)
	inventory_view.hide()
	map_view.hide()
	wishs_view.hide()
	modules_view.hide()
	journal_view.show()
	update_journal_display()

func _set_active_tab(active_button: Button) -> void:
	for tab_button in [inventory_button, wishs_button, modules_button, journal_button, map_button]:
		var selected_decor = tab_button.get_node_or_null("SelectedDecor") as TextureRect
		if selected_decor != null:
			selected_decor.visible = tab_button == active_button

func _update_journal_access() -> void:
	journal_button.visible = Global.collected_items.has(Global.JOURNAL_ITEM_ID)
	journal_gap.visible = journal_button.visible
	if not journal_button.visible and journal_view.visible:
		show_inventory_tab()

func update_journal_display() -> void:
	for child in journal_enemy_grid.get_children():
		var selection_overlay = child.get_node_or_null("SelectionOverlay") as TextureRect
		if selection_overlay != null:
			_hide_selection_decor(selection_overlay)
		journal_enemy_grid.remove_child(child)
		child.queue_free()
	journal_enemy_buttons.clear()
	journal_title_start_decor.hide()
	journal_title_end_decor.hide()
	journal_enemy_name.text = ""
	journal_enemy_description.text = ""
	journal_artwork.texture = null
	journal_artwork.hide()
	journal_artwork_fallback.hide()

	if not Global.collected_items.has(Global.JOURNAL_ITEM_ID):
		journal_enemy_name.text = ""
		journal_enemy_description.text = ""
		journal_empty_label.hide()
		return

	var first_enemy_id: String = ""
	for enemy_id in Global.ENEMY_JOURNAL_DATA:
		if not Global.is_enemy_defeated(enemy_id):
			continue
		var enemy_data: Dictionary = Global.ENEMY_JOURNAL_DATA[enemy_id]
		var icon_button := Button.new()
		icon_button.name = "Enemy_" + enemy_id
		icon_button.custom_minimum_size = Vector2(94, 94)
		icon_button.focus_mode = Control.FOCUS_ALL
		icon_button.tooltip_text = enemy_data.get("name", enemy_id)
		var image_path: String = enemy_data.get("image_path", "")
		if not image_path.is_empty() and ResourceLoader.exists(image_path):
			icon_button.icon = _get_icon_with_max_width(load(image_path) as Texture2D, 76)
		else:
			icon_button.text = str(enemy_data.get("name", enemy_id)).left(2).to_upper()
		icon_button.pressed.connect(_select_journal_enemy.bind(enemy_id))
		icon_button.focus_entered.connect(_select_journal_enemy.bind(enemy_id))
		icon_button.focus_exited.connect(_on_journal_enemy_unfocused.bind(icon_button))
		icon_button.mouse_entered.connect(func(): icon_button.grab_focus())
		_create_selection_overlay(icon_button, "SelectionOverlay")
		journal_enemy_grid.add_child(icon_button)
		journal_enemy_buttons[enemy_id] = icon_button
		if first_enemy_id.is_empty():
			first_enemy_id = enemy_id

	journal_empty_label.visible = first_enemy_id.is_empty()
	if first_enemy_id.is_empty():
		journal_enemy_name.text = ""
		journal_enemy_description.text = ""
		return

func _select_journal_enemy(enemy_id: String) -> void:
	var enemy_data: Dictionary = Global.ENEMY_JOURNAL_DATA.get(enemy_id, {})
	if enemy_data.is_empty():
		return
	journal_enemy_name.text = enemy_data.get("name", enemy_id)
	journal_enemy_description.text = enemy_data.get("description", "No field notes are available for this enemy yet.")
	journal_artwork.texture = null
	journal_artwork.hide()
	journal_artwork_fallback.text = "Artwork unavailable."
	journal_artwork_fallback.show()
	var image_path: String = enemy_data.get("image_path", "")
	if not image_path.is_empty() and ResourceLoader.exists(image_path):
		journal_artwork.texture = load(image_path) as Texture2D
		journal_artwork.show()
		journal_artwork_fallback.hide()
	for button_enemy_id in journal_enemy_buttons:
		var enemy_button: Button = journal_enemy_buttons[button_enemy_id]
		var selection_overlay = enemy_button.get_node_or_null("SelectionOverlay") as TextureRect
		if selection_overlay == null:
			continue
		if button_enemy_id == enemy_id and journal_view.visible:
			journal_title_start_decor.show()
			journal_title_end_decor.show()
			_show_selection_decor(selection_overlay)
		else:
			_hide_selection_decor(selection_overlay)

func _on_journal_enemy_unfocused(enemy_button: Button) -> void:
	var selection_overlay = enemy_button.get_node_or_null("SelectionOverlay") as TextureRect
	if selection_overlay != null:
		_hide_selection_decor(selection_overlay)
	journal_title_start_decor.hide()
	journal_title_end_decor.hide()
	journal_enemy_name.text = ""
	journal_enemy_description.text = ""
	journal_artwork.texture = null
	journal_artwork.hide()
	journal_artwork_fallback.hide()

func update_modules_display() -> void:
	module_title.text = ""
	module_desc.text = ""
	module_title_start_decor.hide()
	module_title_end_decor.hide()
	for child in module_list.get_children():
		if child != module_empty_label:
			var selection_overlay = child.get_node_or_null("SelectionOverlay") as TextureRect
			if selection_overlay != null:
				_hide_selection_decor(selection_overlay)
			child.queue_free()

	module_empty_label.visible = Global.collected_modules.is_empty()
	for module_id in Global.collected_modules:
		var module_data = Global.get_module_data(module_id)
		var module_button = Button.new()
		module_button.name = "Module_" + module_id
		module_button.custom_minimum_size = Vector2(650, 76)
		module_button.icon = _get_module_icon(module_data, 54)
		module_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		module_button.text_alignment = HORIZONTAL_ALIGNMENT_LEFT
		module_button.focus_mode = Control.FOCUS_ALL
		module_button.focus_entered.connect(_on_module_focused.bind(module_button, module_id))
		module_button.focus_exited.connect(_on_module_unfocused.bind(module_button))
		module_button.pressed.connect(_on_module_activated.bind(module_id))
		module_button.mouse_entered.connect(func(): module_button.grab_focus())
		_create_selection_overlay(module_button, "SelectionOverlay", false)
		module_list.add_child(module_button)

	_refresh_module_slots()
	_refresh_module_buttons()

func _get_module_icon(module_data: Dictionary, max_width: int) -> Texture2D:
	var image_path: String = module_data.get("image_path", "")
	if not image_path.is_empty() and ResourceLoader.exists(image_path):
		return _get_icon_with_max_width(load(image_path) as Texture2D, max_width)
	return _get_icon_with_max_width(load("res://assets/images/item/item.png") as Texture2D, max_width)

func _get_icon_with_max_width(texture: Texture2D, max_width: int) -> Texture2D:
	if texture == null or max_width <= 0 or texture.get_width() <= max_width:
		return texture

	var cache_key := "%d:%d" % [texture.get_instance_id(), max_width]
	if _scaled_icon_cache.has(cache_key):
		return _scaled_icon_cache[cache_key] as Texture2D

	var image: Image = texture.get_image()
	if image == null or image.is_empty() or image.get_width() <= max_width:
		return texture
	var scaled_height := maxi(1, roundi(float(image.get_height()) * max_width / image.get_width()))
	image.resize(max_width, scaled_height)
	var scaled_texture := ImageTexture.create_from_image(image)
	_scaled_icon_cache[cache_key] = scaled_texture
	return scaled_texture

func _refresh_module_slots() -> void:
	for slot_index in range(module_slot_buttons.size()):
		var module_id = Global.equipped_modules[slot_index]
		var slot_button = module_slot_buttons[slot_index]
		var selection_overlay = slot_button.get_node_or_null("SelectionOverlay") as TextureRect
		if selection_overlay != null:
			if slot_index == selected_module_slot:
				_show_selection_decor(selection_overlay)
			else:
				_hide_selection_decor(selection_overlay)
		if module_id.is_empty():
			slot_button.text = "Slot %d\nEmpty" % (slot_index + 1)
			slot_button.tooltip_text = "Slot %d is empty" % (slot_index + 1)
			slot_button.icon = null
		else:
			var module_data = Global.get_module_data(module_id)
			slot_button.text = "Slot %d" % (slot_index + 1)
			slot_button.tooltip_text = "Slot %d: %s" % [slot_index + 1, module_data.name]
			slot_button.icon = _get_module_icon(module_data, 30)

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

func _on_module_slot_focused(slot_index: int) -> void:
	_select_module_slot(slot_index)

func _on_module_slot_pressed(slot_index: int) -> void:
	_select_module_slot(slot_index)
	var focused_control = get_viewport().gui_get_focus_owner()
	if focused_control is Button and focused_control.name.begins_with("Module_"):
		_on_module_focused(focused_control, focused_control.name.trim_prefix("Module_"))

func _select_module_slot(slot_index: int) -> void:
	if selected_module_slot == slot_index:
		return
	selected_module_slot = slot_index
	_refresh_module_slots()

func _deselect_module_slot() -> void:
	if selected_module_slot < 0:
		return
	selected_module_slot = -1
	_refresh_module_slots()

func _on_module_focused(module_button: Button, module_id: String) -> void:
	if not modules_view.visible:
		show_modules_tab()
	var module_data = Global.get_module_data(module_id)
	var selection_overlay = module_button.get_node_or_null("SelectionOverlay") as TextureRect
	if selection_overlay != null:
		_show_selection_decor(selection_overlay)
	module_title_start_decor.show()
	module_title_end_decor.show()
	module_title.text = module_data.name
	module_desc.text = module_data.description
	var equipped_slot = Global.equipped_modules.find(module_id)
	if selected_module_slot < 0:
		module_desc.text += "\n\nChoose a slot above before equipping or unequipping this module."
	elif equipped_slot == selected_module_slot:
		module_desc.text += "\n\nPress Enter or click to unequip this module."
	else:
		module_desc.text += "\n\nPress Enter or click to equip it in Slot %d." % (selected_module_slot + 1)

func _on_module_unfocused(module_button: Button) -> void:
	module_button.modulate = Color(1, 1, 1, 1)
	var selection_overlay = module_button.get_node_or_null("SelectionOverlay") as TextureRect
	if selection_overlay != null:
		_hide_selection_decor(selection_overlay)
	module_title_start_decor.hide()
	module_title_end_decor.hide()
	module_title.text = ""
	module_desc.text = ""

func _on_module_activated(module_id: String) -> void:
	if selected_module_slot < 0:
		var module_data = Global.get_module_data(module_id)
		module_desc.text = module_data.description + "\n\nChoose a slot above before equipping or unequipping this module."
		return
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
	item_title.text = ""
	item_desc.text = ""
	_hide_item_selection()
	
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
		var selection_overlay = child.get_node_or_null("WishImageFrame/WishImage/SelectionOverlay") as TextureRect
		if selection_overlay != null:
			_hide_selection_decor(selection_overlay)
		child.queue_free()
	
	# Clear description boxes
	wish_title.text = ""
	wish_desc.text = ""
	wish_title_start_decor.hide()
	wish_title_end_decor.hide()
	
	# Get all accepted wishes
	var accepted_wishes = Global.get_all_accepted_wishes()
	
	if accepted_wishes.is_empty():
		wish_title.text = ""
		wish_desc.text = ""
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
		wish_image_bg.name = "WishImageFrame"
		wish_image_bg.custom_minimum_size = Vector2(110, 110)
		wish_image_bg.self_modulate = Color(0.8, 0.8, 0.8, 1.0)
		
		var wish_image = TextureRect.new()
		wish_image.name = "WishImage"
		wish_image.custom_minimum_size = Vector2(100, 100)
		wish_image.expand_mode = 2  # EXPAND_FIT_WIDTH_IGNORING_ASPECT_RATIO
		if ResourceLoader.exists(wish_data.image_path):
			wish_image.texture = load(wish_data.image_path)
		else:
			# Placeholder if image doesn't exist
			wish_image.modulate = Color(0.5, 0.5, 0.5, 1.0)
		
		wish_image_bg.add_child(wish_image)
		_create_selection_overlay(wish_image, "SelectionOverlay")
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
	
func setup_navigation_paths() -> void:
	# Get a clean array containing ONLY the slots that are currently visible
	var visible_items = item_grid.get_children().filter(func(node): return node.visible)
	
	# Keep the tab cycle in sync with the Journal's unlock state.
	var tabs: Array[Button] = [inventory_button, wishs_button, modules_button]
	if journal_button.visible:
		tabs.append(journal_button)
	tabs.append(map_button)
	for tab_index in range(tabs.size()):
		tabs[tab_index].focus_neighbor_right = tabs[(tab_index + 1) % tabs.size()].get_path()
		tabs[tab_index].focus_neighbor_left = tabs[(tab_index - 1 + tabs.size()) % tabs.size()].get_path()
	
	# Inventory has no content target when the player owns no items.
	inventory_button.focus_neighbor_bottom = inventory_button.get_path()

	if visible_items.size() == 0:
		# Keep tab navigation available, but don't jump into unrelated controls.
		return
		
	var first_item = visible_items[0] as Control
	var last_item = visible_items[visible_items.size() - 1] as Control
	inventory_button.focus_neighbor_bottom = first_item.get_path()
	
	# CLEAN ALL NEIGHBORS: Stops hidden elements from pulling focus up or down randomly
	for item in visible_items:
		item.focus_neighbor_right = NodePath("")
		item.focus_neighbor_left = NodePath("")
		item.focus_neighbor_top = NodePath("")
		item.focus_neighbor_bottom = NodePath("")
	
	# Horizontal movement stays within the grid instead of switching tabs.
	first_item.focus_neighbor_left = first_item.get_path()
	last_item.focus_neighbor_right = last_item.get_path()
	
	# Up always returns from an item to the Inventory tab.
	for item in visible_items:
		item.focus_neighbor_top = inventory_button.get_path()

func _on_item_focused(slot: TextureRect) -> void:
	if not inventory_view.visible:
		show_inventory_tab()

	var item_id = slot.name
	var player_owns_it: bool = (item_id == "needle" and Global.has_needle) or Global.collected_items.has(item_id)
	
	if player_owns_it:
		_show_item_selection(slot)
		
		if item_info.has(item_id):
			item_title.text = item_info[item_id]["name"]
			item_desc.text = item_info[item_id]["desc"]
	else:
		# Fallback just in case a hidden or missing item somehow triggers focus
		_hide_item_selection()
		item_title.text = ""
		item_desc.text = ""

func _on_item_unfocused(slot: TextureRect) -> void:
	slot.modulate = Color(1, 1, 1, 1)
	_hide_item_selection()
	item_title.text = ""
	item_desc.text = ""

func _show_item_selection(slot: TextureRect) -> void:
	var selection_changed: bool = _selected_item_slot != slot or not item_selection_overlay.visible
	_selected_item_slot = slot
	item_selection_overlay.global_position = slot.global_position
	item_selection_overlay.size = slot.size
	item_selection_overlay.pivot_offset = item_selection_overlay.size / 2.0
	item_selection_overlay.show()
	item_title_start_decor.show()
	item_title_end_decor.show()
	if selection_changed:
		if _selection_pulse_tween != null:
			_selection_pulse_tween.kill()
		item_selection_overlay.scale = Vector2.ONE
		_selection_pulse_tween = create_tween().set_loops()
		_selection_pulse_tween.tween_property(item_selection_overlay, "scale", Vector2(1.06, 1.06), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_selection_pulse_tween.tween_property(item_selection_overlay, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _hide_item_selection() -> void:
	if _selection_pulse_tween != null:
		_selection_pulse_tween.kill()
		_selection_pulse_tween = null
	_selected_item_slot = null
	item_selection_overlay.scale = Vector2.ONE
	item_selection_overlay.hide()
	item_title_start_decor.hide()
	item_title_end_decor.hide()

func _create_selection_overlay(parent: Control, overlay_name: String, fill_parent: bool = true) -> TextureRect:
	var overlay = TextureRect.new()
	overlay.name = overlay_name
	overlay.texture = SELECTION_OVERLAY_TEXTURE
	overlay.expand_mode = 1
	overlay.stretch_mode = 5
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 1
	if fill_parent:
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		overlay.position = Vector2.ZERO
		overlay.size = Vector2(76, 76)
	parent.add_child(overlay)
	overlay.hide()
	return overlay

func _show_selection_decor(overlay: TextureRect) -> void:
	overlay.show()
	call_deferred("_start_selection_decor_pulse", overlay)

func _start_selection_decor_pulse(overlay: TextureRect) -> void:
	if not is_instance_valid(overlay) or not overlay.is_visible_in_tree():
		return
	var tween_id = overlay.get_instance_id()
	if _selection_decor_tweens.has(tween_id):
		var previous_tween: Tween = _selection_decor_tweens[tween_id]
		previous_tween.kill()
	overlay.pivot_offset = overlay.size / 2.0
	overlay.scale = Vector2.ONE
	var pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(overlay, "scale", Vector2(1.06, 1.06), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(overlay, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_selection_decor_tweens[tween_id] = pulse_tween

func _hide_selection_decor(overlay: TextureRect) -> void:
	if not is_instance_valid(overlay):
		return
	var tween_id = overlay.get_instance_id()
	if _selection_decor_tweens.has(tween_id):
		var pulse_tween: Tween = _selection_decor_tweens[tween_id]
		pulse_tween.kill()
		_selection_decor_tweens.erase(tween_id)
	overlay.scale = Vector2.ONE
	overlay.hide()

func _on_item_slot_input(event: InputEvent, slot: TextureRect) -> void:
	# Detect when the mouse hovers or clicks an item to display information
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		var item_id: String = slot.name
		var player_owns_it: bool = (item_id == "needle" and Global.has_needle) or Global.collected_items.has(item_id)
		
		if player_owns_it and item_info.has(item_id):
			_show_item_selection(slot)
			item_title.text = item_info[item_id]["name"]
			item_desc.text = item_info[item_id]["desc"]

func _on_wish_focused(wish_container: HBoxContainer, wish_id: String) -> void:
	if not wishs_view.visible:
		show_wishs_tab()
	
	var wish_data = Global.get_wish(wish_id)
	if wish_data.is_empty():
		return
	
	# Update the selected wish title and description.
	wish_title.text = wish_data.name
	wish_desc.text = wish_data.description
	wish_title_start_decor.show()
	wish_title_end_decor.show()
	var selection_overlay = wish_container.get_node_or_null("WishImageFrame/WishImage/SelectionOverlay") as TextureRect
	if selection_overlay != null:
		_show_selection_decor(selection_overlay)

	if wish_data.type == "collect_items":
		var progress_info = "\n\nRequired Items:\n"
		for item_name in wish_data.required_items:
			var required = wish_data.required_items[item_name]
			var progress = Global.get_wish_progress(wish_id)
			var collected = progress.get(item_name, 0)
			progress_info += "%s %s: %d / %d\n" % [item_name, "(collected)" if collected >= required else "", collected, required]
		wish_desc.text += progress_info
	
func _on_wish_unfocused() -> void:
	# Reset all wish containers' modulate and clear description
	for child in wish_grid.get_children():
		if child is HBoxContainer:
			child.modulate = Color(1, 1, 1, 1)
			var selection_overlay = child.get_node_or_null("WishImageFrame/WishImage/SelectionOverlay") as TextureRect
			if selection_overlay != null:
				_hide_selection_decor(selection_overlay)
	wish_title_start_decor.hide()
	wish_title_end_decor.hide()
	wish_title.text = ""
	wish_desc.text = ""
