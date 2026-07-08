extends HBoxContainer
@onready var SilkGuiClass = preload("uid://cfyfvjubvn4ki")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func setMaxSilk(max: int):
	for i in range(max):
		var silk = SilkGuiClass.instantiate()
		add_child(silk)
		
func updateSilk(currentSilk: int):
	var silks = get_children()
	
	for i in range(currentSilk):
		silks[i].update(true)
		
	for i in range(currentSilk, silks.size()):
		silks[i].update(false)
