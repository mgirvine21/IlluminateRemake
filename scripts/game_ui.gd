extends CanvasLayer

## Persistent UI that survives scene changes (autoload):
##   - resource list under the light meter (censored "???" until discovered)
##   - achievement / event toasts
##   - station menus (statue, workbench, shipping)
##   - Tab journal: Overview, Collection, Nightlights, Achievements, Upgrades
## Everything is built in code so it reacts to the lists in GameData.

const TEXT := Color(0.75, 0.84, 0.98)
const MUTED := Color(0.48, 0.54, 0.68)
const ACCENT := Color(1.0, 0.84, 0.3)
const BORDER := Color(0.54, 0.48, 1.0)
const BG := Color(0.05, 0.07, 0.13, 0.94)
const LOCKED := Color(0.16, 0.18, 0.27)

var font: Font = load("res://Assets/Fonts/Pixelta.ttf")

var _hud: Control
var _resource_rows := {}
var _dust_label: Label
var _rate_label: Label
var _stock_label: Label
var _cave_label: Label
var _toasts: VBoxContainer

var _modal: Control
var _modal_title: Label
var _modal_body: MarginContainer
var _modal_kind := ""
var _journal_tab := 0
var _afford_buttons: Array = []
var _reset_armed := false
var _ach_detail: Label

var _fade: ColorRect


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_modal()
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)

	Inventory.item_changed.connect(func(_id, _c): _refresh_resources())
	GameState.resources_changed.connect(_refresh_resources)
	GameState.nightlights_changed.connect(_refresh_resources)
	GameState.upgrades_changed.connect(_on_progress_changed)
	GameState.toast_requested.connect(show_toast)
	GameState.achievement_unlocked.connect(func(_d): _on_progress_changed())
	get_tree().scene_changed.connect(_refresh_resources)
	_refresh_resources()


func _process(_delta: float) -> void:
	_dust_label.text = "%s %s" % [GameData.fmt(GameState.dreamdust), GameData.CURRENCY_NAME]
	var rate := GameState.dust_per_second()
	_rate_label.visible = rate > 0.0
	_rate_label.text = "+%s / sec" % GameData.fmt_rate(rate)
	for entry in _afford_buttons:
		var btn: Button = entry[0]
		if is_instance_valid(btn):
			btn.disabled = not entry[1].call()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if _modal_kind == "journal":
			close_modal()
		elif _modal_kind == "":
			open_journal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _modal_kind != "":
		close_modal()
		get_viewport().set_input_as_handled()


func _on_progress_changed() -> void:
	_refresh_resources()
	if _modal_kind != "":
		_rebuild_modal()


# ================================================================ HUD

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	var panel := _panel(Color(0.05, 0.07, 0.13, 0.7))
	panel.position = Vector2(24, 410)
	panel.custom_minimum_size = Vector2(330, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	_cave_label = _label("", 22, MUTED)
	col.add_child(_cave_label)
	_dust_label = _label("", 30, ACCENT)
	col.add_child(_dust_label)
	_rate_label = _label("", 20, MUTED)
	col.add_child(_rate_label)
	col.add_child(HSeparator.new())

	for r in GameData.RESOURCES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var name_label := _label("", 24, TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var count_label := _label("", 24, TEXT)
		row.add_child(icon)
		row.add_child(name_label)
		row.add_child(count_label)
		col.add_child(row)
		_resource_rows[r.id] = {"icon": icon, "name": name_label, "count": count_label}

	col.add_child(HSeparator.new())
	_stock_label = _label("", 22, TEXT)
	col.add_child(_stock_label)
	col.add_child(_label("[E] Use   [Tab] Journal", 18, MUTED))

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.position = Vector2(-460, 24)
	_toasts.custom_minimum_size = Vector2(436, 0)
	_toasts.add_theme_constant_override("separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_toasts)


func _refresh_resources() -> void:
	if _cave_label == null:
		return
	var scene := get_tree().current_scene
	if GameState.in_cave:
		_cave_label.text = GameData.CAVES[GameState.current_tier].name
	elif scene and scene.scene_file_path == GameState.NEST_SCENE:
		_cave_label.text = "The Nest"
	else:
		_cave_label.text = ""
	for r in GameData.RESOURCES:
		var row: Dictionary = _resource_rows[r.id]
		var known := GameState.has_discovered(r.id)
		row.icon.color = r.color if known else LOCKED
		row.name.text = r.name if known else "???"
		row.name.add_theme_color_override("font_color", TEXT if known else MUTED)
		row.count.text = str(Inventory.get_count(StringName(r.id))) if known else "-"
		row.count.add_theme_color_override("font_color", TEXT if known else MUTED)
	var stock := GameState.stock_total()
	_stock_label.text = "Nightlights ready: %d" % stock
	_stock_label.visible = GameState.get_stat("nightlights_crafted") > 0


func show_toast(title: String, body: String = "", color: Color = TEXT) -> void:
	var p := _panel(BG)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = p.get_theme_stylebox("panel").duplicate()
	style.border_color = color
	p.add_theme_stylebox_override("panel", style)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(_label(title, 26, color))
	if body != "":
		var b := _label(body, 22, TEXT)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		v.add_child(b)
	p.modulate.a = 0.0
	_toasts.add_child(p)
	var t := p.create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.25)
	t.tween_interval(3.5)
	t.tween_property(p, "modulate:a", 0.0, 0.5)
	t.tween_callback(p.queue_free)
	while _toasts.get_child_count() > 5:
		_toasts.get_child(0).free()


func fade_out() -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.3)
	await t.finished


func fade_in() -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, 0.4)


# ================================================================ modal shell

func _build_modal() -> void:
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.visible = false
	add_child(_modal)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)

	var panel := _panel(BG)
	panel.custom_minimum_size = Vector2(1240, 820)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	_modal_title = _label("", 44, ACCENT)
	_modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_modal_title)
	var hint := _label("[Esc] Close", 22, MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(hint)
	header.add_child(_button("X", close_modal))

	col.add_child(HSeparator.new())
	_modal_body = MarginContainer.new()
	_modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_modal_body)


func _open(kind: String) -> void:
	_modal_kind = kind
	_reset_armed = false
	_modal.visible = true
	GameState.ui_blocking = true
	_rebuild_modal()


func close_modal() -> void:
	_modal_kind = ""
	_modal.visible = false
	_afford_buttons.clear()
	GameState.ui_blocking = false


func is_open() -> bool:
	return _modal_kind != ""


func open_statue() -> void:
	GameState.add_stat("statue_visits")
	_open("statue")


func open_workbench() -> void:
	_open("workbench")


func open_shipping() -> void:
	_open("shipping")


func open_journal() -> void:
	GameState.add_stat("journal_opens")
	_open("journal")


func _rebuild_modal() -> void:
	_afford_buttons.clear()
	for c in _modal_body.get_children():
		c.free()
	match _modal_kind:
		"statue":
			_modal_title.text = "Statue of the Star Wyrm"
			_modal_body.add_child(_scroll(_build_statue()))
		"workbench":
			_modal_title.text = "Nightlight Workbench"
			_modal_body.add_child(_scroll(_build_workbench()))
		"shipping":
			_modal_title.text = "Moonlight Post"
			_modal_body.add_child(_scroll(_build_shipping()))
		"journal":
			_modal_title.text = "Dragon Journal"
			_modal_body.add_child(_build_journal())


# ================================================================ statue

func _build_statue() -> VBoxContainer:
	var col := _column()
	col.add_child(_label("Spend %s on blessings for your dragon and dream engines that earn while you explore."
		% GameData.CURRENCY_NAME, 24, MUTED, true))

	col.add_child(_section("Blessings"))
	for u in GameData.UPGRADES:
		var lvl := GameState.upgrade_level(u.id)
		var requires_ok: bool = not u.has("requires") or GameState.has_upgrade(u.requires)
		var row := _card_row()
		var info := _column(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var level_text := "" if u.max == 1 else "  Lv %d/%d" % [lvl, u.max]
		info.add_child(_label("%s%s" % [u.name, level_text], 28, TEXT))
		var desc: String = u.desc if requires_ok else "Requires %s." % GameData.upgrade_def(u.requires).name
		info.add_child(_label("[%s] %s" % [u.cat, desc], 20, MUTED, true))
		row.add_child(info)
		if lvl >= u.max:
			row.add_child(_label("OWNED", 26, ACCENT))
		else:
			var id: String = u.id
			var cost := GameState.upgrade_cost(id)
			var btn := _button("%s" % GameData.fmt(cost), func():
				if GameState.buy_upgrade(id):
					show_toast("Blessing received", GameData.upgrade_def(id).name, ACCENT))
			btn.custom_minimum_size = Vector2(170, 0)
			_afford_buttons.append([btn, func(): return GameState.upgrade_available(id) and GameState.dreamdust >= cost])
			row.add_child(btn)
		col.add_child(_wrap_card(row))

	col.add_child(_section("Dream Engines  (%s / sec)" % GameData.fmt_rate(GameState.dust_per_second())))
	var shown_locked := false
	for e in GameData.ENGINES:
		var sold := GameState.get_stat("nightlights_sold")
		if sold < e.unlock_sold:
			if shown_locked:
				break
			shown_locked = true
			var lrow := _card_row()
			lrow.add_child(_label("???  -  ship %d nightlights to reveal." % e.unlock_sold, 24, MUTED))
			col.add_child(_wrap_card(lrow))
			continue
		var owned := int(GameState.engines.get(e.id, 0))
		var row := _card_row()
		var info := _column(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label("%s  x%d" % [e.name, owned], 28, TEXT))
		info.add_child(_label("%s  +%s/sec each" % [e.desc, GameData.fmt_rate(e.rate)], 20, MUTED, true))
		row.add_child(info)
		var eid: String = e.id
		var cost := GameState.engine_cost(eid)
		var btn := _button(GameData.fmt(cost), func(): GameState.buy_engine(eid))
		btn.custom_minimum_size = Vector2(170, 0)
		_afford_buttons.append([btn, func(): return GameState.dreamdust >= cost])
		row.add_child(btn)
		col.add_child(_wrap_card(row))
	return col


# ================================================================ workbench

func _build_workbench() -> VBoxContainer:
	var col := _column()
	col.add_child(_label("Bind stars with glowvine fiber to build nightlights for sleepy dragons.", 24, MUTED, true))
	for r in GameData.RECIPES:
		var row := _card_row()
		var info := _column(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not GameState.recipe_discovered(r):
			info.add_child(_label("??? Unknown Nightlight", 28, MUTED))
			var missing := 0
			for id in r.cost:
				if not GameState.has_discovered(id):
					missing += 1
			info.add_child(_label("Discover %d more ingredient(s) to reveal this recipe." % missing, 20, MUTED))
			row.add_child(info)
			col.add_child(_wrap_card(row))
			continue
		var stock := int(GameState.nightlight_stock.get(r.id, 0))
		info.add_child(_label("%s   (sells %s, %d ready)" % [r.name, GameData.fmt(GameState.nightlight_price(r.id)), stock], 28, TEXT))
		var parts: Array[String] = []
		for id in r.cost:
			var have := Inventory.get_count(StringName(id))
			parts.append("%s %d/%d" % [GameData.resource_def(id).name, have, r.cost[id]])
		info.add_child(_label("   ".join(parts), 20, MUTED, true))
		row.add_child(info)
		var rid: String = r.id
		var cost: Dictionary = r.cost
		var one := _button("Craft", func(): _craft(rid, 1))
		_afford_buttons.append([one, func(): return GameState.can_afford_cost(cost)])
		row.add_child(one)
		var max_n := GameState.max_craftable(cost)
		var all_btn := _button("Max (%d)" % max_n, func(): _craft(rid, GameState.max_craftable(cost)))
		all_btn.disabled = max_n <= 1
		row.add_child(all_btn)
		col.add_child(_wrap_card(row))
	return col


func _craft(recipe_id: String, times: int) -> void:
	var made := GameState.craft(recipe_id, times)
	if made > 0:
		var extra := " (+%d bonus!)" % (made - times) if made > times else ""
		show_toast("Crafted %d %s%s" % [times, GameData.recipe_def(recipe_id).name, extra], "", ACCENT)
	_rebuild_modal()


# ================================================================ shipping

func _build_shipping() -> VBoxContainer:
	var col := _column()
	col.add_child(_label("Send finished nightlights off to sleepy dragons across the valley. Price bonus: x%.2f"
		% GameState.sell_mult(), 24, MUTED, true))
	var total := 0.0
	var any := false
	for r in GameData.RECIPES:
		var n := int(GameState.nightlight_stock.get(r.id, 0))
		if n <= 0:
			continue
		any = true
		var price := GameState.nightlight_price(r.id)
		total += price * n
		var row := _card_row()
		var name_label := _label("%s  x%d" % [r.name, n], 28, TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(_label("%s each  =  %s" % [GameData.fmt(price), GameData.fmt(price * n)], 24, MUTED))
		col.add_child(_wrap_card(row))
	if not any:
		col.add_child(_label("No nightlights ready. Craft some at the workbench first.", 26, MUTED))
	col.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	var total_label := _label("Total: %s %s" % [GameData.fmt(total), GameData.CURRENCY_NAME], 32, ACCENT)
	total_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(total_label)
	var ship := _button("Ship All", func():
		var earned := GameState.ship_all()
		if earned > 0.0:
			show_toast("Shipped!", "+%s %s" % [GameData.fmt(earned), GameData.CURRENCY_NAME], ACCENT)
		_rebuild_modal())
	ship.disabled = not any
	footer.add_child(ship)
	col.add_child(footer)
	col.add_child(_label("Lifetime shipped: %s" % GameData.fmt(GameState.get_stat("nightlights_sold")), 22, MUTED))
	return col


# ================================================================ journal

func _build_journal() -> TabContainer:
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_override("font", font)
	tabs.add_theme_font_size_override("font_size", 26)
	tabs.focus_mode = Control.FOCUS_NONE
	var pages := {
		"Overview": _build_overview(),
		"Collection": _build_collection(),
		"Nightlights": _build_nightlights(),
		"Achievements": _build_achievements(),
		"Upgrades": _build_owned(),
	}
	for title in pages:
		var s := _scroll(pages[title])
		s.name = title
		tabs.add_child(s)
	tabs.current_tab = clampi(_journal_tab, 0, pages.size() - 1)
	tabs.tab_changed.connect(func(i): _journal_tab = i)
	return tabs


func _stat_line(col: VBoxContainer, label: String, value: String) -> void:
	var row := HBoxContainer.new()
	var l := _label(label, 26, MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(_label(value, 26, TEXT))
	col.add_child(row)


func _build_overview() -> VBoxContainer:
	var col := _column(6)
	var s := GameState
	col.add_child(_section("Wealth"))
	_stat_line(col, GameData.CURRENCY_NAME, GameData.fmt(s.dreamdust))
	_stat_line(col, "Per second", GameData.fmt_rate(s.dust_per_second()))
	_stat_line(col, "Earned all time", GameData.fmt(s.get_stat("dreamdust_earned")))
	col.add_child(_section("Adventure"))
	_stat_line(col, "Stars collected", GameData.fmt(s.get_stat("stars_total")))
	_stat_line(col, "Trips into the caves", GameData.fmt(s.get_stat("trips")))
	_stat_line(col, "Best single-trip haul", GameData.fmt(s.get_stat("trip_stars_max")))
	_stat_line(col, "Deepest cave", GameData.CAVES[clampi(int(s.get_stat("deepest_cave")), 1, 3)].name
		if s.get_stat("deepest_cave") > 0 else "-")
	_stat_line(col, "Times slept", GameData.fmt(s.get_stat("sleeps")))
	_stat_line(col, "Burnouts", GameData.fmt(s.get_stat("burnouts")))
	_stat_line(col, "Jumps", GameData.fmt(s.get_stat("jumps")))
	_stat_line(col, "Time played", GameData.fmt_time(s.get_stat("play_time")))
	col.add_child(_section("Crafting"))
	_stat_line(col, "Nightlights crafted", GameData.fmt(s.get_stat("nightlights_crafted")))
	_stat_line(col, "Nightlights shipped", GameData.fmt(s.get_stat("nightlights_sold")))
	_stat_line(col, "Achievements", "%d / %d  (+%d%% to sales and engines)"
		% [s.achievement_count(), s.achievement_defs.size(), s.achievement_count()])
	col.add_child(HSeparator.new())
	var reset := _button("Reset Save", func():
		if _reset_armed:
			GameState.reset_save()
			show_toast("Save reset", "A brand new dragon awakens.")
			_reset_armed = false
		else:
			_reset_armed = true
			show_toast("Are you sure?", "Press Reset Save again to erase all progress.", Color(1, 0.5, 0.65))
		_rebuild_modal())
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(reset)
	return col


func _table_header(col: VBoxContainer, headers: Array) -> void:
	var row := HBoxContainer.new()
	for i in headers.size():
		var l := _label(headers[i], 22, ACCENT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_stretch_ratio = 2.5 if i == 0 else 1.0
		row.add_child(l)
	col.add_child(row)
	col.add_child(HSeparator.new())


func _table_row(col: VBoxContainer, cells: Array, color: Color, swatch: Color = Color(0, 0, 0, 0)) -> void:
	var row := HBoxContainer.new()
	for i in cells.size():
		var cell: Control
		if i == 0 and swatch.a > 0.0:
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			var icon := ColorRect.new()
			icon.color = swatch
			icon.custom_minimum_size = Vector2(20, 20)
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(icon)
			h.add_child(_label(cells[i], 26, color))
			cell = h
		else:
			cell = _label(cells[i], 26, color)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_stretch_ratio = 2.5 if i == 0 else 1.0
		row.add_child(cell)
	col.add_child(row)


func _build_collection() -> VBoxContainer:
	var col := _column(8)
	_table_header(col, ["Resource", "Carrying", "Lifetime"])
	for r in GameData.RESOURCES:
		if GameState.has_discovered(r.id):
			_table_row(col, [r.name, str(Inventory.get_count(StringName(r.id))),
				GameData.fmt(GameState.get_stat("got_" + r.id))], TEXT, r.color)
		else:
			_table_row(col, ["???", "-", "-"], MUTED, LOCKED)
	col.add_child(HSeparator.new())
	_stat_line(col, "Glowvines harvested", GameData.fmt(GameState.get_stat("vines_harvested")))
	_stat_line(col, "Walls broken", GameData.fmt(GameState.get_stat("walls_broken")))
	_stat_line(col, "Geodes opened", GameData.fmt(GameState.get_stat("geodes_opened")))
	return col


func _build_nightlights() -> VBoxContainer:
	var col := _column(8)
	_table_header(col, ["Nightlight", "Crafted", "Shipped", "Ready", "Value"])
	for r in GameData.RECIPES:
		if GameState.get_stat("crafted_" + r.id) > 0 or GameState.recipe_discovered(r):
			_table_row(col, [r.name,
				GameData.fmt(GameState.get_stat("crafted_" + r.id)),
				GameData.fmt(GameState.get_stat("sold_" + r.id)),
				str(GameState.nightlight_stock.get(r.id, 0)),
				GameData.fmt(GameState.nightlight_price(r.id))], TEXT, ACCENT)
		else:
			_table_row(col, ["???", "-", "-", "-", "-"], MUTED, LOCKED)
	return col


func _build_achievements() -> VBoxContainer:
	var col := _column(10)
	var s := GameState
	col.add_child(_label("%d / %d unlocked   -   each one adds +1%% to sales and dream engines"
		% [s.achievement_count(), s.achievement_defs.size()], 26, ACCENT))
	_ach_detail = _label("Hover an icon to see its details.", 24, MUTED, true)
	_ach_detail.custom_minimum_size = Vector2(0, 64)
	col.add_child(_ach_detail)

	var by_cat := {}
	for def in s.achievement_defs:
		if not by_cat.has(def.cat):
			by_cat[def.cat] = []
		by_cat[def.cat].append(def)

	for cat in GameData.ACHIEVEMENT_CATEGORIES:
		if not by_cat.has(cat):
			continue
		var defs: Array = by_cat[cat]
		var got := 0
		for d in defs:
			if s.achievements.has(d.id):
				got += 1
		col.add_child(_section("%s  %d/%d" % [cat, got, defs.size()]))
		var grid := GridContainer.new()
		grid.columns = 14
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for d in defs:
			grid.add_child(_achievement_icon(d, GameData.ACHIEVEMENT_CATEGORIES[cat]))
		col.add_child(grid)
	return col


## Placeholder achievement icon: swap the ColorRect + letter for your pixel art later.
func _achievement_icon(def: Dictionary, cat_color: Color) -> Control:
	var unlocked: bool = GameState.achievements.has(def.id)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(68, 68)
	var style := StyleBoxFlat.new()
	style.bg_color = cat_color.darkened(0.55) if unlocked else LOCKED
	style.border_color = cat_color if unlocked else Color(0.25, 0.27, 0.38)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	tile.add_theme_stylebox_override("panel", style)
	var letter := _label(def.name.substr(0, 1) if unlocked else "?", 34,
		cat_color if unlocked else MUTED)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_child(letter)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_entered.connect(func(): _show_achievement(def))
	return tile


func _show_achievement(def: Dictionary) -> void:
	if _ach_detail == null or not is_instance_valid(_ach_detail):
		return
	var unlocked: bool = GameState.achievements.has(def.id)
	if unlocked:
		var when := Time.get_datetime_string_from_unix_time(int(GameState.achievements[def.id]), true)
		_ach_detail.text = "%s  -  %s\nUnlocked %s" % [def.name, def.desc, when]
		_ach_detail.add_theme_color_override("font_color", TEXT)
	elif def.hidden:
		_ach_detail.text = "???  -  A secret achievement. Keep exploring."
		_ach_detail.add_theme_color_override("font_color", MUTED)
	else:
		var progress := minf(GameState.get_stat(def.stat), def.goal)
		_ach_detail.text = "%s  -  %s\nProgress: %s / %s" % [def.name, def.desc,
			GameData.fmt(progress), GameData.fmt(def.goal)]
		_ach_detail.add_theme_color_override("font_color", MUTED)


func _build_owned() -> VBoxContainer:
	var col := _column(6)
	col.add_child(_section("Blessings"))
	var any := false
	for u in GameData.UPGRADES:
		var lvl := GameState.upgrade_level(u.id)
		if lvl > 0:
			any = true
			_stat_line(col, u.name, "Lv %d/%d" % [lvl, u.max] if u.max > 1 else "Owned")
	if not any:
		col.add_child(_label("None yet. Visit the statue in your nest.", 24, MUTED))
	col.add_child(_section("Dream Engines"))
	any = false
	for e in GameData.ENGINES:
		var n := int(GameState.engines.get(e.id, 0))
		if n > 0:
			any = true
			_stat_line(col, e.name, "x%d  (%s/sec)" % [n, GameData.fmt_rate(e.rate * n * GameState.achievement_bonus())])
	if not any:
		col.add_child(_label("None yet.", 24, MUTED))
	col.add_child(_section("Current Bonuses"))
	_stat_line(col, "Max light", str(int(GameState.max_light())))
	_stat_line(col, "Light drain", "%.1f / sec in %s" % [GameState.drain_rate(), GameData.CAVES[GameState.current_tier].name])
	_stat_line(col, "Move speed", "x%.2f" % GameState.speed_mult())
	_stat_line(col, "Burnout loss", "%d%%" % int(GameState.burnout_loss() * 100))
	_stat_line(col, "Sale price", "x%.2f" % GameState.sell_mult())
	return col


# ================================================================ widget helpers

func _label(text: String, size: int, color: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 26)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.2, 0.17, 0.4)
	normal.border_color = BORDER
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate()
	hover.bg_color = Color(0.3, 0.26, 0.58)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.12, 0.13, 0.2)
	disabled.border_color = Color(0.25, 0.27, 0.38)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.pressed.connect(on_press)
	return b


func _panel(bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	p.add_theme_stylebox_override("panel", style)
	return p


func _column(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


func _card_row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	return h


func _wrap_card(content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.2, 0.9)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", style)
	p.add_child(content)
	return p


func _section(title: String) -> Label:
	var l := _label(title, 30, BORDER.lightened(0.3))
	return l


func _scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_right", 16)
	m.add_child(content)
	s.add_child(m)
	return s
