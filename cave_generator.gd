extends Node

@export var map_width: int = 20
@export var map_height: int = 20
@export var redraw: bool = false:
	set(value):
		_do_redraw()

@export var world_seed: String = "Hello Godot!"
@export var noise_octaves: int = 2
@export var noise_period: float = 3.0
@export var noise_persistence: float = 0.5
@export var noise_lacunarity: float = 0.4
@export var noise_threshold: float = 0.5

@export var cave_layer: TileMapLayer
@export var vine_layer: TileMapLayer
@export var vine_source_id: int = 0
@export var vine_top_atlas: Vector2i = Vector2i(10,0)
@export var vine_mid_atlas: Vector2i = Vector2i(10,1)
@export var vine_end_atlas: Vector2i = Vector2i(10,2)

@export var vine_spawn_chance: float = 0.25
@export var vine_min_spacing: int = 2
@export var vine_max_length: int = 9

@export var star_scene: PackedScene
@export var star_types: Array[ItemData]
@export var stars_parent: Node2D
@export var spawn_maker: Marker2D
@export var star_count: int = 12
@export var star_min_separation: float = 4.0

var vine_length_weights := {1: 40, 3: 30, 5: 15, 7: 10, 9: 5}

# Set these to match the Terrain Set / Terrain you configure on the
# TileMapLayer's TileSet resource (TileSet > Terrains tab).
@export var terrain_set: int = 0
@export var terrain: int = 0

var tile_map: TileMapLayer
var simplex_noise: FastNoiseLite = FastNoiseLite.new()

func _ready() -> void:
	tile_map = cave_layer
	_do_redraw()

func _do_redraw() -> void:
	if tile_map == null:
		return
	clear()
	generate()

func clear() -> void:
	tile_map.clear()

func generate() -> void:
	simplex_noise.seed = world_seed.hash()
	simplex_noise.fractal_octaves = noise_octaves
	simplex_noise.frequency = 1.0 / max(noise_period, 0.001)
	simplex_noise.fractal_gain = noise_persistence
	simplex_noise.fractal_lacunarity = noise_lacunarity

	var wall_cells: Array[Vector2i] = []
	var wall_set: Dictionary = {}
	for x in range(-map_width / 2, map_width / 2):
		for y in range(-map_height / 2, map_height / 2):
			if simplex_noise.get_noise_2d(x, y) < noise_threshold:
				var cell = (Vector2i(x, y))
				wall_cells.append(cell)
				wall_set[cell] = true
	# set_cells_terrain_connect looks at each cell's neighbors and picks the
	# matching tile automatically -- this replaces the old manual
	# get_cell_autotile_coord()/update_bitmask_area() calls entirely.
	tile_map.set_cells_terrain_connect(wall_cells, terrain_set, terrain, false)
	generate_vines(wall_set)
	var start := _get_start_cell(wall_set)
	var reachable := find_reachable(start, wall_set)
	print("reachable cells: ", reachable.size())
	spawn_stars(wall_set, reachable)

func _get_start_cell(wall_set: Dictionary) -> Vector2i:
	var target := tile_map.local_to_map(tile_map.to_local(spawn_maker.global_position))
	if not wall_set.has(target):
		return target
	for radius in range(1, max(map_width, map_height)):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var c := target + Vector2i(dx, dy)
				if _in_bounds(c) and not wall_set.has(c):
					return c
	return target

func _in_bounds(c: Vector2i) -> bool :
	return c.x >= -map_width / 2 and c.x < map_width / 2 and c.y >= -map_height / 2 and c.y < map_height / 2

func find_reachable(start: Vector2i, wall_set: Dictionary) -> Dictionary:
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if _in_bounds(n) and not wall_set.has(n) and not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist

func spawn_stars(wall_set: Dictionary, reachable: Dictionary) -> void:
	for child in stars_parent.get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed.hash() ^ 0x57A25

	# candidates: reachable open cells standing on a floor, not on a vine
	var candidates: Array[Vector2i] = []
	for cell in reachable.keys():
		if wall_set.has(cell + Vector2i.DOWN) and vine_layer.get_cell_source_id(cell) == -1:
			candidates.append(cell)

	# seeded shuffle (Array.shuffle() would break your same-level-every-time seed)
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var placed: Array[Vector2i] = []
	for cell in candidates:
		if placed.size() >= star_count:
			break
		var too_close := false
		for p in placed:
			if (cell - p).length() < star_min_separation:
				too_close = true
				break
		if too_close:
			continue
		var data := _pick_star_type(rng, reachable[cell])
		if data == null:
			continue
		placed.append(cell)
		_spawn_star(cell, data)
	print("stars placed: ", placed.size(), " / candidates: ", candidates.size())

func _pick_star_type(rng: RandomNumberGenerator, distance: int) -> ItemData:
	var total := 0
	for t in star_types:
		if distance >= t.min_distance:
			total += t.spawn_weight
	if total <= 0:
		return null
	var roll := rng.randi_range(1, total)
	for t in star_types:
		if distance >= t.min_distance:
			roll -= t.spawn_weight
			if roll <= 0:
				return t
	return null

func _spawn_star(cell: Vector2i, data: ItemData) -> void:
	var star := star_scene.instantiate()
	star.data = data
	stars_parent.add_child(star)
	star.global_position = tile_map.to_global(tile_map.map_to_local(cell))

func generate_vines(wall_set: Dictionary) -> void:
	vine_layer.clear()
	print("vine_layer tileset: ", vine_layer.tile_set)
	print("source count: ", vine_layer.tile_set.get_source_count() if vine_layer.tile_set else "NO TILESET")
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed.hash() ^ 0x5EED
	var last_vine_x: int = -9999

	var count_ceiling := 0
	var count_spacing_fail := 0
	var count_chance_fail := 0
	var count_placed := 0

	for cell in wall_set.keys():
		var below = cell + Vector2i(0, 1)
		if wall_set.has(below):
			continue
		count_ceiling += 1

		if abs(cell.x - last_vine_x) < vine_min_spacing:
			count_spacing_fail += 1
			continue
		if rng.randf() > vine_spawn_chance:
			count_chance_fail += 1
			continue

		var depth = _measure_open_depth(cell, wall_set)
		var length = _pick_vine_length(rng, depth)
		if length <= 0:
			continue

		_place_vine(cell, length)
		count_placed += 1
		last_vine_x = cell.x

	print("ceiling candidates: ", count_ceiling)
	print("spacing failed: ", count_spacing_fail)
	print("chance failed: ", count_chance_fail)
	print("vines placed: ", count_placed)

func _measure_open_depth(ceiling_cell: Vector2i, wall_set: Dictionary) -> int:
	var depth := 0
	var check := ceiling_cell + Vector2i(0, 1)
	while not wall_set.has(check) and depth < vine_max_length:
		depth += 1
		check += Vector2i(0, 1)
	return depth

func _pick_vine_length(rng: RandomNumberGenerator, max_depth: int) -> int:
	var candidates: Array = []
	for length in vine_length_weights.keys():
		if length <= max_depth:
			for i in range(vine_length_weights[length]):
				candidates.append(length)
	if candidates.is_empty():
		return 0
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _place_vine(ceiling_cell: Vector2i, length: int) -> void:
	if length == 1:
		vine_layer.set_cell(ceiling_cell + Vector2i(0, 1), vine_source_id, vine_end_atlas)
		return
	for i in range(length):
		var pos = ceiling_cell + Vector2i(0, 1 + i)
		var atlas: Vector2i
		if i == 0:
			atlas = vine_top_atlas
		elif i == length - 1:
			atlas = vine_end_atlas
		else:
			atlas = vine_mid_atlas
		vine_layer.set_cell(pos, vine_source_id, atlas)
