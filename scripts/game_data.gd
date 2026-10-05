class_name GameData
extends RefCounted

## All of the game's tunable content lives here: resources, recipes, upgrades,
## idle "dream engines", cave tiers and achievements. Add to these lists and the
## HUD, journal, statue and workbench pick the new entries up automatically.

const CURRENCY_NAME := "Dreamdust"

## Order here is the order shown in the HUD resource list.
## Anything the player has never obtained is shown censored as "???".
const RESOURCES := [
	{"id": "star_common", "name": "Common Star", "color": Color(0.95, 0.95, 1.0), "kind": "star"},
	{"id": "star_blue", "name": "Blue Star", "color": Color(0.35, 0.9, 1.0), "kind": "star"},
	{"id": "star_gold", "name": "Gold Star", "color": Color(1.0, 0.84, 0.3), "kind": "star"},
	{"id": "star_violet", "name": "Violet Star", "color": Color(0.72, 0.5, 1.0), "kind": "star"},
	{"id": "star_rose", "name": "Rose Star", "color": Color(1.0, 0.5, 0.65), "kind": "star"},
	{"id": "vine_fiber", "name": "Glowvine Fiber", "color": Color(0.45, 0.85, 0.5), "kind": "material"},
	{"id": "geode_crystal", "name": "Geode Crystal", "color": Color(0.6, 0.75, 1.0), "kind": "material"},
	{"id": "comet_shard", "name": "Comet Shard", "color": Color(1.0, 0.65, 0.35), "kind": "material"},
	{"id": "moonstone", "name": "Moonstone", "color": Color(0.85, 0.9, 0.8), "kind": "material"},
]

const STAR_IDS := ["star_common", "star_blue", "star_gold", "star_violet", "star_rose"]

const RECIPES := [
	{"id": "candle", "name": "Ember Candle", "value": 12,
		"cost": {"star_common": 3, "vine_fiber": 1}},
	{"id": "azure", "name": "Azure Lantern", "value": 40,
		"cost": {"star_blue": 2, "star_common": 2, "vine_fiber": 1}},
	{"id": "sunglow", "name": "Sunglow Orb", "value": 130,
		"cost": {"star_gold": 2, "star_blue": 1, "vine_fiber": 2}},
	{"id": "geode", "name": "Geode Glowlight", "value": 450,
		"cost": {"geode_crystal": 2, "star_gold": 2, "vine_fiber": 2}},
	{"id": "moonlit", "name": "Moonlit Jar", "value": 420,
		"cost": {"star_violet": 3, "star_gold": 1, "vine_fiber": 2}},
	{"id": "rosedream", "name": "Rosedream Lamp", "value": 1400,
		"cost": {"star_rose": 3, "star_violet": 2, "vine_fiber": 3}},
	{"id": "comet", "name": "Comet Mobile", "value": 3000,
		"cost": {"comet_shard": 1, "star_common": 5, "star_blue": 3, "star_gold": 2, "vine_fiber": 4}},
]

## cost = base_cost * cost_mult ^ current_level
const UPGRADES := [
	{"id": "lungs", "name": "Bigger Lungs", "cat": "Body", "max": 5, "base_cost": 25, "cost_mult": 1.8,
		"desc": "+20 maximum light per level."},
	{"id": "slow_burn", "name": "Slow Ember", "cat": "Body", "max": 5, "base_cost": 40, "cost_mult": 1.9,
		"desc": "Your light drains 12% slower per level."},
	{"id": "wings", "name": "Swift Wings", "cat": "Body", "max": 4, "base_cost": 30, "cost_mult": 1.8,
		"desc": "+8% move speed per level."},
	{"id": "glide", "name": "Gossamer Wings", "cat": "Ability", "max": 1, "base_cost": 60, "cost_mult": 1.0,
		"desc": "Hold jump while falling to glide."},
	{"id": "double_jump", "name": "Second Wind", "cat": "Ability", "max": 1, "base_cost": 150, "cost_mult": 1.0,
		"desc": "Jump again in mid-air."},
	{"id": "magnet", "name": "Star Magnet", "cat": "Ability", "max": 4, "base_cost": 60, "cost_mult": 2.0,
		"desc": "Nearby stars drift toward you. +1 tile of range per level."},
	{"id": "claws", "name": "Stone Claws", "cat": "Ability", "max": 1, "base_cost": 400, "cost_mult": 1.0,
		"desc": "Press F to break cave walls. Sealed geodes with rare stars now form in caves."},
	{"id": "pouch", "name": "Ember Pouch", "cat": "Body", "max": 5, "base_cost": 50, "cost_mult": 1.7,
		"desc": "Lose 7% fewer resources when your light burns out."},
	{"id": "shears", "name": "Vine Shears", "cat": "Craft", "max": 3, "base_cost": 80, "cost_mult": 2.5,
		"desc": "+1 Glowvine Fiber per vine harvested."},
	{"id": "deft", "name": "Deft Talons", "cat": "Craft", "max": 4, "base_cost": 200, "cost_mult": 2.2,
		"desc": "+10% chance per level to craft a bonus nightlight."},
	{"id": "haggle", "name": "Sleepy Bargains", "cat": "Trade", "max": 5, "base_cost": 100, "cost_mult": 2.0,
		"desc": "Nightlights sell for 10% more per level."},
	{"id": "cave2", "name": "Crystal Depths Key", "cat": "Caves", "max": 1, "base_cost": 600, "cost_mult": 1.0,
		"desc": "Opens the second cave door. Bigger cave, Violet Stars, faster light drain."},
	{"id": "cave3", "name": "Ember Abyss Key", "cat": "Caves", "max": 1, "base_cost": 6000, "cost_mult": 1.0,
		"requires": "cave2", "desc": "Opens the third cave door. Rose Stars and Comet Shards."},
]

## Cookie-clicker style buildings: cost = base_cost * 1.15 ^ owned
const ENGINES := [
	{"id": "hatchling", "name": "Lullaby Hatchling", "rate": 0.2, "base_cost": 50, "unlock_sold": 1,
		"desc": "A tiny dragon hums bedtime songs."},
	{"id": "firefly", "name": "Firefly Jar", "rate": 1.5, "base_cost": 400, "unlock_sold": 25,
		"desc": "Fireflies trade their glow for dreams."},
	{"id": "choir", "name": "Moth Choir", "rate": 10.0, "base_cost": 3500, "unlock_sold": 150,
		"desc": "A chorus of moths sings the whole valley to sleep."},
	{"id": "loom", "name": "Dream Loom", "rate": 60.0, "base_cost": 30000, "unlock_sold": 600,
		"desc": "Weaves loose dreams into dreamdust."},
	{"id": "moonbell", "name": "Moon Bell", "rate": 400.0, "base_cost": 300000, "unlock_sold": 2500,
		"desc": "Each toll puts a mountain to sleep."},
]
const ENGINE_COST_MULT := 1.15

const CAVES := {
	1: {"name": "Shallow Hollow", "width": 90, "height": 60, "stars": 20, "drain": 1.0,
		"star_ids": ["star_common", "star_blue", "star_gold"], "comet_chance": 0.0},
	2: {"name": "Crystal Depths", "width": 120, "height": 75, "stars": 30, "drain": 1.3,
		"star_ids": ["star_common", "star_blue", "star_gold", "star_violet"], "comet_chance": 0.0},
	3: {"name": "Ember Abyss", "width": 150, "height": 90, "stars": 40, "drain": 1.6,
		"star_ids": ["star_blue", "star_gold", "star_violet", "star_rose"], "comet_chance": 0.03},
}

const ACHIEVEMENT_CATEGORIES := {
	"Stars": Color(1.0, 0.84, 0.3),
	"Craft": Color(0.45, 0.85, 0.5),
	"Trade": Color(0.35, 0.9, 1.0),
	"Explore": Color(0.72, 0.5, 1.0),
	"Rest": Color(0.75, 0.83, 0.98),
	"Growth": Color(1.0, 0.5, 0.65),
	"Secret": Color(1.0, 0.65, 0.35),
}


static func resource_def(id: String) -> Dictionary:
	for r in RESOURCES:
		if r.id == id:
			return r
	return {"id": id, "name": id, "color": Color.WHITE, "kind": "material"}


static func recipe_def(id: String) -> Dictionary:
	for r in RECIPES:
		if r.id == id:
			return r
	return {}


static func upgrade_def(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}


static func fmt(value: float) -> String:
	var v := absf(value)
	var suffixes := ["", "K", "M", "B", "T", "Qa", "Qi"]
	var i := 0
	while v >= 1000.0 and i < suffixes.size() - 1:
		v /= 1000.0
		i += 1
	var sign_str := "-" if value < 0 else ""
	if i == 0:
		return sign_str + str(int(floor(v)))
	return sign_str + ("%.2f" % v) + suffixes[i]


static func fmt_rate(value: float) -> String:
	if value < 100.0:
		return "%.1f" % value
	return fmt(value)


static func fmt_time(seconds: float) -> String:
	var s := int(seconds)
	if s < 60:
		return "%ds" % s
	if s < 3600:
		return "%dm %ds" % [s / 60, s % 60]
	return "%dh %dm" % [s / 3600, (s % 3600) / 60]


# ---------------------------------------------------------------- achievements

static func _tiered(list: Array, id_prefix: String, cat: String, stat: String, goals: Array,
		names: Array, desc_fmt: String, hidden := false) -> void:
	for i in goals.size():
		list.append({
			"id": "%s_%d" % [id_prefix, i],
			"name": names[i],
			"desc": desc_fmt % fmt(goals[i]),
			"cat": cat,
			"stat": stat,
			"goal": float(goals[i]),
			"hidden": hidden,
		})


static func _single(list: Array, id: String, cat: String, stat: String, goal: float,
		name: String, desc: String, hidden := true) -> void:
	list.append({"id": id, "name": name, "desc": desc, "cat": cat, "stat": stat,
		"goal": goal, "hidden": hidden})


static func build_achievements() -> Array:
	var a: Array = []

	_tiered(a, "stars", "Stars", "stars_total",
		[1, 10, 50, 100, 250, 500, 1000, 2500, 5000, 10000],
		["First Twinkle", "Pocketful of Light", "Starcatcher", "Century of Sparks", "Glimmer Hoarder",
		"Constellation Keeper", "Thousand Suns", "Galaxy Brain", "Nebula Nest", "Celestial Tycoon"],
		"Collect %s stars.")

	var star_names := {"star_common": "Common", "star_blue": "Blue", "star_gold": "Gold",
		"star_violet": "Violet", "star_rose": "Rose"}
	for sid in STAR_IDS:
		var n: String = star_names[sid]
		_tiered(a, sid, "Stars", "got_" + sid, [1, 25, 100, 500],
			["%s Spotted" % n, "%s Collector" % n, "%s Expert" % n, "%s Master" % n],
			"Collect %s " + n + " Stars.", sid == "star_violet" or sid == "star_rose")

	_tiered(a, "fiber", "Stars", "vines_harvested", [1, 50, 250, 1000],
		["Green Thumb", "Vine Whisperer", "Jungle Weaver", "Overgrown"],
		"Harvest %s glowvines.")

	_tiered(a, "craft", "Craft", "nightlights_crafted", [1, 10, 50, 100, 500, 1000, 5000],
		["Tinkerer", "Night Shift", "Lamplighter", "Glow Factory", "Dream Foundry",
		"Luminous Legend", "Light of the World"],
		"Craft %s nightlights.")

	for r in RECIPES:
		var secret: bool = r.id in ["geode", "moonlit", "rosedream", "comet"]
		_tiered(a, "craft_" + r.id, "Craft", "crafted_" + r.id, [1, 50],
			["%s Debut" % r.name, "%s Artisan" % r.name],
			"Craft %s " + r.name + ".", secret)

	_tiered(a, "sold", "Trade", "nightlights_sold", [1, 10, 100, 1000, 10000],
		["First Sale", "Regular Customer", "Shipping Lane", "Bedtime Empire", "Every Dragon Sleeps"],
		"Ship %s nightlights to sleepy dragons.")

	_tiered(a, "dust", "Trade", "dreamdust_earned", [100, 1000, 10000, 100000, 1000000, 10000000],
		["Pinch of Dreams", "Sandman's Apprentice", "Dream Merchant", "Slumber Baron",
		"Reverie Royalty", "Dreamdust Dynasty"],
		"Earn %s Dreamdust in total.")

	_tiered(a, "engines", "Trade", "engines_owned", [1, 10, 50, 100, 250],
		["Bedtime Story", "Lullaby Chorus", "Dream Machine", "Industrial Snoozing", "Perpetual Dreaming"],
		"Own %s dream engines.")

	_tiered(a, "trips", "Explore", "trips", [1, 10, 50, 100, 500],
		["Into the Dark", "Cave Regular", "Spelunker", "Deep Diver", "Lives Underground"],
		"Venture into the caves %s times.")

	_tiered(a, "haul", "Explore", "trip_stars_max", [15, 30, 60],
		["Good Haul", "Great Haul", "Legendary Haul"],
		"Collect %s stars in a single trip.")

	_tiered(a, "jumps", "Explore", "jumps", [100, 1000, 10000],
		["Hop", "Skip", "Leap of Faith"], "Jump %s times.")

	_tiered(a, "glide", "Explore", "glide_time", [10, 120, 1200],
		["Featherfall", "Drifter", "Sky Sailor"], "Glide for %s seconds in total.", true)

	_tiered(a, "walls", "Explore", "walls_broken", [1, 100, 1000, 5000],
		["Crack in the Wall", "Tunneler", "Mountain Mover", "Living Pickaxe"],
		"Break %s cave walls.", true)

	_tiered(a, "geodes", "Explore", "geodes_opened", [1, 10, 50],
		["Geode Geologist", "Crystal Hunter", "Hollow Heart"],
		"Break into %s sealed geodes.", true)

	_single(a, "cave_2", "Explore", "deepest_cave", 2, "Crystal Depths", "Enter the Crystal Depths.")
	_single(a, "cave_3", "Explore", "deepest_cave", 3, "Ember Abyss", "Enter the Ember Abyss.")

	_tiered(a, "sleeps", "Rest", "sleeps", [1, 10, 50, 200],
		["Power Nap", "Well Rested", "Professional Napper", "Hibernation Champion"],
		"Sleep in your nest %s times.")

	_tiered(a, "playtime", "Rest", "play_time", [600, 3600, 36000],
		["Getting Cozy", "Night Owl", "Eternal Night"], "Play for %s seconds.")

	_tiered(a, "hoard", "Rest", "max_held", [50, 200, 1000],
		["Hoarder", "Dragon's Hoard", "Mountain of Light"], "Hold %s stars at once.")

	_tiered(a, "upgrades", "Growth", "upgrades_bought", [1, 10, 25, 40],
		["Self Improvement", "Growing Wings", "Ascended Dragon", "Fully Fledged"],
		"Buy %s upgrades at the statue.")

	_tiered(a, "meta", "Growth", "achievements", [10, 25, 50, 100],
		["Show-off", "Trophy Nest", "Legendary Dragon", "Star of Stars"],
		"Unlock %s achievements.")

	_single(a, "close_call", "Secret", "close_call", 1, "Close Call",
		"Return to the nest with less than 10% light left.")
	_single(a, "lights_out", "Secret", "burnouts", 1, "Lights Out", "Let your light burn out.")
	_single(a, "moth", "Secret", "burnouts", 10, "Moth to the Flame", "Burn out 10 times.")
	_single(a, "painful", "Secret", "big_burnout", 1, "Painful Lesson",
		"Burn out while carrying 30 or more stars.")
	_single(a, "insomniac", "Secret", "trips_since_sleep_max", 10, "Insomniac",
		"Make 10 trips into the caves without sleeping.")
	_single(a, "window", "Secret", "statue_visits", 25, "Window Shopper", "Visit the statue 25 times.")
	_single(a, "bookworm", "Secret", "journal_opens", 50, "Bookworm", "Open your journal 50 times.")
	_single(a, "bulk", "Secret", "sold_batch_max", 50, "Bulk Order", "Ship 50 nightlights at once.")
	_single(a, "big_spender", "Secret", "biggest_purchase", 1000, "Big Spender",
		"Spend 1,000 Dreamdust on a single purchase.")
	_single(a, "smash", "Secret", "smash_and_grab", 1, "Smash and Grab",
		"Return home with 10+ stars less than 60 seconds after entering a cave.")
	_single(a, "completionist", "Secret", "all_upgrades", 1, "Completionist",
		"Max out every statue upgrade.")
	_single(a, "comet", "Secret", "got_comet_shard", 1, "Wish Upon a Comet", "Find a Comet Shard.")

	return a
