extends Node

## Long-term progress: currency, lifetime stats, upgrades, dream engines,
## nightlights, achievements, the current cave seed, and saving/loading.
## Inventory still holds what the dragon is carrying right now.

signal dreamdust_changed(value: float)
signal resources_changed
signal nightlights_changed
signal upgrades_changed
signal achievement_unlocked(def: Dictionary)
signal toast_requested(title: String, body: String, color: Color)

const SAVE_PATH := "user://illuminate_save.json"
const NEST_SCENE := "res://Scenes/nest.tscn"
const CAVE_SCENE := "res://Scenes/main.tscn"
const AUTOSAVE_SECONDS := 30.0
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0
const BASE_BURNOUT_LOSS := 0.35

var dreamdust: float = 0.0
var stats: Dictionary = {}
var upgrades: Dictionary = {}
var engines: Dictionary = {}
var nightlight_stock: Dictionary = {}
var achievements: Dictionary = {}
var cave_seed: int = 0
var current_tier: int = 1
## "tier:x:y" keys of stars / vines already taken from the current cave seed.
## Sleeping clears this so the caves repopulate.
var depleted: Dictionary = {}

var session_started := false
var ui_blocking := false
var in_cave := false
var trip_stars := 0
var trip_started_msec := 0

var achievement_defs: Array = GameData.build_achievements()
var _achievements_by_stat: Dictionary = {}
var _autosave_timer := 0.0
var _traveling := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input_actions()
	for def in achievement_defs:
		if not _achievements_by_stat.has(def.stat):
			_achievements_by_stat[def.stat] = []
		_achievements_by_stat[def.stat].append(def)
	if cave_seed == 0:
		cave_seed = randi()
	load_game()


func _register_input_actions() -> void:
	_add_key_action(&"journal", KEY_TAB)
	_add_key_action(&"mine", KEY_F)


func _add_key_action(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _process(delta: float) -> void:
	var rate := dust_per_second()
	if rate > 0.0:
		add_dreamdust(rate * delta)
	add_stat("play_time", delta)
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_SECONDS:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# ---------------------------------------------------------------- stats

func get_stat(id: String) -> float:
	return float(stats.get(id, 0.0))


func add_stat(id: String, amount: float = 1.0) -> void:
	stats[id] = get_stat(id) + amount
	_check_achievements(id)


func set_stat_max(id: String, value: float) -> void:
	if value > get_stat(id):
		stats[id] = value
		_check_achievements(id)


func _check_achievements(stat: String) -> void:
	if not _achievements_by_stat.has(stat):
		return
	var value := get_stat(stat)
	for def in _achievements_by_stat[stat]:
		if value >= def.goal and not achievements.has(def.id):
			achievements[def.id] = Time.get_unix_time_from_system()
			achievement_unlocked.emit(def)
			toast_requested.emit("Achievement Unlocked", def.name,
				GameData.ACHIEVEMENT_CATEGORIES.get(def.cat, Color.WHITE))
			# "achievements" is itself a stat, so meta-achievements chain naturally.
			add_stat("achievements")


func achievement_count() -> int:
	return achievements.size()


func toast(title: String, body: String = "", color: Color = Color(0.75, 0.83, 0.98)) -> void:
	toast_requested.emit(title, body, color)


# ---------------------------------------------------------------- resources

func has_discovered(id: String) -> bool:
	return get_stat("got_" + id) > 0


## Use this instead of Inventory.add so lifetime stats + achievements update.
func gain(id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	Inventory.add(StringName(id), amount)
	add_stat("got_" + id, amount)
	if id in GameData.STAR_IDS:
		add_stat("stars_total", amount)
		if in_cave:
			trip_stars += amount
	set_stat_max("max_held", held_star_count())
	resources_changed.emit()


func held_star_count() -> int:
	var total := 0
	for sid in GameData.STAR_IDS:
		total += Inventory.get_count(StringName(sid))
	return total


func can_afford_cost(cost: Dictionary, times: int = 1) -> bool:
	for id in cost:
		if Inventory.get_count(StringName(id)) < int(cost[id]) * times:
			return false
	return true


func max_craftable(cost: Dictionary) -> int:
	var best := 1 << 30
	for id in cost:
		best = mini(best, Inventory.get_count(StringName(id)) / int(cost[id]))
	return best


func on_star_collected(id: String) -> void:
	gain(id, 1)
	var chance: float = GameData.CAVES[current_tier].comet_chance
	if chance > 0.0 and randf() < chance:
		gain("comet_shard", 1)
		toast("Comet Shard!", "A shard fell from the star.", GameData.resource_def("comet_shard").color)


# ---------------------------------------------------------------- dreamdust

func add_dreamdust(amount: float) -> void:
	dreamdust += amount
	add_stat("dreamdust_earned", amount)
	dreamdust_changed.emit(dreamdust)


func spend_dreamdust(amount: float) -> bool:
	if dreamdust + 0.0001 < amount:
		return false
	dreamdust = maxf(dreamdust - amount, 0.0)
	set_stat_max("biggest_purchase", amount)
	dreamdust_changed.emit(dreamdust)
	return true


func achievement_bonus() -> float:
	return 1.0 + 0.01 * achievement_count()


func dust_per_second() -> float:
	var total := 0.0
	for e in GameData.ENGINES:
		total += e.rate * engines.get(e.id, 0)
	return total * achievement_bonus()


# ---------------------------------------------------------------- upgrades

func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func has_upgrade(id: String) -> bool:
	return upgrade_level(id) > 0


func upgrade_cost(id: String) -> float:
	var def := GameData.upgrade_def(id)
	return floor(def.base_cost * pow(def.cost_mult, upgrade_level(id)))


func upgrade_available(id: String) -> bool:
	var def := GameData.upgrade_def(id)
	if def.has("requires") and not has_upgrade(def.requires):
		return false
	return upgrade_level(id) < def.max


func buy_upgrade(id: String) -> bool:
	if not upgrade_available(id):
		return false
	if not spend_dreamdust(upgrade_cost(id)):
		return false
	upgrades[id] = upgrade_level(id) + 1
	add_stat("upgrades_bought")
	var all_maxed := true
	for u in GameData.UPGRADES:
		if upgrade_level(u.id) < u.max:
			all_maxed = false
	if all_maxed:
		set_stat_max("all_upgrades", 1)
	Global.refresh_light_cap()
	upgrades_changed.emit()
	return true


func engine_cost(id: String) -> float:
	for e in GameData.ENGINES:
		if e.id == id:
			return floor(e.base_cost * pow(GameData.ENGINE_COST_MULT, engines.get(id, 0)))
	return INF


func buy_engine(id: String) -> bool:
	if not spend_dreamdust(engine_cost(id)):
		return false
	engines[id] = int(engines.get(id, 0)) + 1
	add_stat("engines_owned")
	upgrades_changed.emit()
	return true


func is_cave_unlocked(tier: int) -> bool:
	return tier <= 1 or has_upgrade("cave%d" % tier)


# Derived values used by the player, light and stars.
func max_light() -> float:
	return Global.MAX_LIGHT_METER + 20.0 * upgrade_level("lungs")


func drain_rate() -> float:
	var tier_mult: float = GameData.CAVES[current_tier].drain
	return Global.DRAIN_PER_SECOND * tier_mult * pow(0.88, upgrade_level("slow_burn"))


func speed_mult() -> float:
	return 1.0 + 0.08 * upgrade_level("wings")


func magnet_radius() -> float:
	return 128.0 * upgrade_level("magnet")


func burnout_loss() -> float:
	return maxf(BASE_BURNOUT_LOSS - 0.07 * upgrade_level("pouch"), 0.0)


func sell_mult() -> float:
	return (1.0 + 0.1 * upgrade_level("haggle")) * achievement_bonus()


# ---------------------------------------------------------------- crafting / selling

func recipe_discovered(recipe: Dictionary) -> bool:
	for id in recipe.cost:
		if not has_discovered(id):
			return false
	return true


func craft(recipe_id: String, times: int = 1) -> int:
	var r := GameData.recipe_def(recipe_id)
	if r.is_empty() or times <= 0 or not can_afford_cost(r.cost, times):
		return 0
	for id in r.cost:
		Inventory.spend(StringName(id), int(r.cost[id]) * times)
	var made := times
	var bonus_chance := 0.1 * upgrade_level("deft")
	for i in times:
		if randf() < bonus_chance:
			made += 1
	nightlight_stock[recipe_id] = int(nightlight_stock.get(recipe_id, 0)) + made
	add_stat("nightlights_crafted", made)
	add_stat("crafted_" + recipe_id, made)
	resources_changed.emit()
	nightlights_changed.emit()
	return made


func nightlight_price(recipe_id: String) -> float:
	return floor(GameData.recipe_def(recipe_id).value * sell_mult())


func stock_total() -> int:
	var total := 0
	for id in nightlight_stock:
		total += int(nightlight_stock[id])
	return total


func ship_all() -> float:
	var earned := 0.0
	var count := 0
	for id in nightlight_stock.keys():
		var n := int(nightlight_stock[id])
		if n <= 0:
			continue
		earned += nightlight_price(id) * n
		count += n
		add_stat("sold_" + id, n)
		nightlight_stock[id] = 0
	if count == 0:
		return 0.0
	add_stat("nightlights_sold", count)
	set_stat_max("sold_batch_max", count)
	add_dreamdust(earned)
	nightlights_changed.emit()
	return earned


# ---------------------------------------------------------------- caves & travel

func depletion_key(cell: Vector2i) -> String:
	return "%d:%d:%d" % [current_tier, cell.x, cell.y]


func is_depleted(cell: Vector2i) -> bool:
	return depleted.has(depletion_key(cell))


func mark_depleted(cell: Vector2i) -> void:
	depleted[depletion_key(cell)] = true


func enter_cave() -> void:
	in_cave = true
	trip_stars = 0
	trip_started_msec = Time.get_ticks_msec()
	set_stat_max("deepest_cave", current_tier)
	Global.refill_light()


func travel_to_cave(tier: int) -> void:
	if _traveling or not is_cave_unlocked(tier):
		return
	current_tier = tier
	add_stat("trips")
	add_stat("trips_since_sleep")
	set_stat_max("trips_since_sleep_max", get_stat("trips_since_sleep"))
	_change_scene(CAVE_SCENE)


func return_to_nest() -> void:
	if _traveling:
		return
	if Global.light_meter < Global.max_light_meter * 0.1:
		set_stat_max("close_call", 1)
	var seconds := (Time.get_ticks_msec() - trip_started_msec) / 1000.0
	if trip_stars >= 10 and seconds < 60.0:
		set_stat_max("smash_and_grab", 1)
	set_stat_max("trip_stars_max", trip_stars)
	in_cave = false
	_change_scene(NEST_SCENE)


func burnout() -> void:
	if not in_cave or _traveling:
		return
	in_cave = false
	add_stat("burnouts")
	if held_star_count() >= 30:
		set_stat_max("big_burnout", 1)
	set_stat_max("trip_stars_max", trip_stars)
	var loss := burnout_loss()
	var lost := 0
	for r in GameData.RESOURCES:
		var id := StringName(r.id)
		var amount := int(floor(Inventory.get_count(id) * loss))
		if amount > 0:
			Inventory.spend(id, amount)
			lost += amount
	resources_changed.emit()
	toast("Your light burned out...", "You drifted home and dropped %d resources." % lost,
		Color(1.0, 0.5, 0.65))
	_change_scene(NEST_SCENE)


## Sleeping in the nest rolls a fresh cave layout and repopulates every star and vine.
func sleep() -> void:
	add_stat("sleeps")
	stats["trips_since_sleep"] = 0
	cave_seed = randi()
	depleted.clear()
	Global.refill_light()
	save_game()
	toast("You feel well rested", "The caves have shifted and the stars have returned.")


func _change_scene(path: String) -> void:
	_traveling = true
	save_game()
	var ui := get_node_or_null("/root/GameUI")
	if ui:
		await ui.fade_out()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	_traveling = false
	if ui:
		ui.fade_in()


# ---------------------------------------------------------------- save / load

func save_game() -> void:
	var inv := {}
	for id in Inventory.counts:
		inv[str(id)] = Inventory.counts[id]
	var data := {
		"version": 1,
		"saved_at": Time.get_unix_time_from_system(),
		"dreamdust": dreamdust,
		"stats": stats,
		"upgrades": upgrades,
		"engines": engines,
		"nightlight_stock": nightlight_stock,
		"achievements": achievements,
		"cave_seed": cave_seed,
		"depleted": depleted.keys(),
		"inventory": inv,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	dreamdust = float(data.get("dreamdust", 0.0))
	stats = data.get("stats", {})
	upgrades = _int_values(data.get("upgrades", {}))
	engines = _int_values(data.get("engines", {}))
	nightlight_stock = _int_values(data.get("nightlight_stock", {}))
	achievements = data.get("achievements", {})
	cave_seed = int(data.get("cave_seed", randi()))
	depleted.clear()
	for key in data.get("depleted", []):
		depleted[key] = true
	Inventory.counts.clear()
	var inv: Dictionary = data.get("inventory", {})
	for id in inv:
		Inventory.counts[StringName(id)] = int(inv[id])
	Global.refresh_light_cap()

	var away := Time.get_unix_time_from_system() - float(data.get("saved_at", 0.0))
	var offline := dust_per_second() * clampf(away, 0.0, MAX_OFFLINE_SECONDS)
	if offline >= 1.0:
		add_dreamdust(offline)
		call_deferred("toast", "While you were away...",
			"Your dream engines made %s %s." % [GameData.fmt(offline), GameData.CURRENCY_NAME])


func reset_save() -> void:
	dreamdust = 0.0
	stats.clear()
	upgrades.clear()
	engines.clear()
	nightlight_stock.clear()
	achievements.clear()
	depleted.clear()
	cave_seed = randi()
	Inventory.counts.clear()
	Global.refresh_light_cap()
	save_game()
	resources_changed.emit()
	nightlights_changed.emit()
	upgrades_changed.emit()
	dreamdust_changed.emit(dreamdust)


func _int_values(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(d[k])
	return out
