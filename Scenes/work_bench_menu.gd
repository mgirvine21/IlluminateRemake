extends MenuBase

@onready var recipe_list: VBoxContainer = %RecipeList
@onready var name_label: Label = %NameLabel
@onready var desc_label: Label = %DescLabel
@onready var inputs_box: VBoxContainer = %InputBox
@onready var craft_button: Button = %CraftButton
@onready var sell_button: Button = %SellButton
@onready var currency_label: Label = %CurrencyLabel

var _selected: RecipeData

func _ready() -> void:
	super._ready()
	craft_button.pressed.connect(_on_craft)
	sell_button.pressed.connect(_on_sell)
	Inventory.item_changed.connect(func(_id, _n): _refresh_detail())
	Inventory.currency_changed.connect(func(_n): _refresh_detail())

func _on_open() -> void:
	_rebuild_list()
	var list: Array[RecipeData] = Recipes.available()
	_select(list[0] if not list.is_empty() else null)

func _rebuild_list() -> void:
	for c in recipe_list.get_children():
		c.queue_free()
	for r in Recipes.available():
		var b := Button.new()
		b.text = r.display_name
		b.icon = r.icon
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_select.bind(r))
		recipe_list.add_child(b)

func _select(recipe: RecipeData) -> void:
	_selected = recipe
	_refresh_detail()

func _refresh_detail() -> void:
	currency_label.text = "Coins: %d" % Inventory.currency
	for c in inputs_box.get_children():
		c.queue_free()
	if _selected == null:
		name_label.text = "Nothing to craft yet"
		desc_label.text = ""
		craft_button.disabled = true
		sell_button.disabled = true
		sell_button.visible = WorldState.has_flag(&"merchant_got_lamp")
		return
	
	name_label.text = _selected.display_name
	desc_label.text = _selected.description
	for id in _selected.inputs:
		var need: int = _selected.inputs[id]
		var have := Inventory.get_count(id)
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 25)
		row.text = "%s %d / %d" % [String(id).capitalize(), have, need]
		if have < need:
			row.modulate = Color(1, 0.4, 0.4)
		inputs_box.add_child(row)
	
	var held := Inventory.get_count(_selected.id)
	craft_button.disabled = not Inventory.can_craft(_selected)
	sell_button.text = "Sell all (%d) for %d" % [held, held * _selected.sale_value]
	sell_button.disabled = held <= 0

func _on_craft() -> void:
	if _selected:
		Inventory.craft(_selected)

func _on_sell() -> void:
	if _selected:
		Inventory.sell(_selected, 9999)
# Called every  frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
