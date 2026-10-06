extends Node

## Generates a Terraria-style cave in a grid of cells, then guarantees that
## the area the player spawns in is the area that gets stars and vines.
##
## Pipeline:
##   1. noise        -> raw open / wall grid
##   2. worm tunnels -> long winding passages that link blobs together
##   3. smoothing    -> cellular automata rounds off jagged noise
##   4. border       -> solid frame so the player can't leave the map
##   5. spawn room   -> a guaranteed chamber (and future nest exit) at the marker
##   6. cleanup      -> remove tiny floating rocks, add climbable ledges
##   7. pockets      -> every sealed air pocket is filled, tunneled to, or kept as a geode
##   8. paint        -> one set_cells_terrain_connect call draws the tiles
##   9. populate     -> vines + stars ONLY in cells the player can reach

signal cave_generated(spawn_position: Vector2)
signal wall_broken(cell: Vector2i)

enum PocketMode {
	FILL,    ## sealed pockets become solid rock
	CONNECT, ## a tunnel is carved from each pocket to the main cave
	GEODE,   ## pockets stay sealed (stars inside) for a future wall-breaking ability
}

const DIRS4 := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const WALL := 1
const OPEN := 0

@export_group("Map")
@export var map_width: int = 90
@export var map_height: int = 60
@export var border_thickness: int = 2
@export var world_seed: String = "Hello Godot!"
## When true a new cave is rolled every run instead of using world_seed.
@export var randomize_seed: bool = false
@export var redraw: bool = false:
	set(value):
		_do_redraw()

@export_group("Noise")
@export var noise_octaves: int = 3
## Size of the cave blobs in cells. Bigger = larger rooms.
@export var noise_period: float = 14.0
@export var noise_persistence: float = 0.5
@export var noise_lacunarity: float = 2.0
## Cells whose noise is ABOVE this become open air. Lower = more open space.
@export_range(-1.0, 1.0) var open_threshold: float = 0.05
## >1 stretches caves sideways, which reads more like Terraria.
@export var horizontal_stretch: float = 1.6
@export var smoothing_passes: int = 3

@export_group("Tunnels")
@export var tunnel_count: int = 8
@export var tunnel_length: int = 70
@export var tunnel_radius: int = 1

@export_group("Cleanup")
@export var pocket_mode: PocketMode = PocketMode.CONNECT
## Pockets smaller than this are always filled, regardless of pocket_mode.
@export var min_pocket_size: int = 12
## Floating rocks smaller than this are removed.
@export var min_wall_cluster: int = 4
@export var add_climb_ledges: bool = true
## How many cells high the dragon can jump. Taller shafts get ledges on their walls.
@export var max_climb_height: int = 3

@export_group("Spawn")
@export var spawn_maker: Marker2D
@export var player: Node2D
@export var spawn_room_size: Vector2i = Vector2i(7, 4)

@export_group("Tiles")
@export var cave_layer: TileMapLayer
## Set these to match the Terrain Set / Terrain on the cave TileSet.
@export var terrain_set: int = 0
@export var terrain: int = 0

@export_group("Vines")
@export var vine_layer: TileMapLayer
@export var vine_source_id: int = 0
@export var vine_top_atlas: Vector2i = Vector2i(10, 0)
@export var vine_mid_atlas: Vector2i = Vector2i(10, 1)
@export var vine_end_atlas: Vector2i = Vector2i(10, 2)
@export var vine_spawn_chance: float = 0.25
@export var vine_min_spacing: int = 2
@export var vine_max_length: int = 9

@export_group("Stars")
@export var star_scene: PackedScene
@export var star_types: Array[ItemData]
@export var stars_parent: Node2D
@export var star_count: int = 20
@export var star_min_separation: float = 4.0
## Stars won't spawn this close (in cells) to the spawn room.
@export var star_spawn_clearance: int = 6
@export var geode_star_count: int = 2

var vine_length_weights := {1: 40, 3: 30, 5: 15, 7: 10, 9: 5}

var tile_map: TileMapLayer
var simplex_noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var star_rng := RandomNumberGenerator.new()
var night: int = 1

var spawn_cell: Vector2i
## Every open cell the player can reach, mapped to its BFS distance from spawn.
var main_region: Dictionary = {}
## Sealed pockets (only populated in GEODE mode). Array of Array[Vector2i].
var geode_pockets: Array = []

var _grid := PackedByteArray()
var _min := Vector2i.ZERO


func _ready() -> void:
	tile_map = cave_layer
	_do_redraw()


func _do_redraw() -> void:
	if tile_map == null:
		return
	generate()


func generate() -> void:
	var seed_value: int = randi() if randomize_seed else world_seed.hash()
	rng.seed = seed_value
	_setup_noise(seed_value)

	_min = Vector2i(-map_width / 2, -map_height / 2)
	_grid = PackedByteArray()
	_grid.resize(map_width * map_height)

	_fill_from_noise()
	_carve_tunnels()
	for i in smoothing_passes:
		_smooth()
	_apply_border()

	spawn_cell = _pick_spawn_cell()
	_carve_spawn_room()
	_remove_small_wall_clusters()
	if add_climb_ledges:
		_add_climb_ledges()
	_carve_spawn_room()
	_resolve_pockets()

	_paint_tiles()
	main_region = find_reachable(spawn_cell)
	_collect_geodes()
	print("cave: reachable cells=", main_region.size(), " geodes=", geode_pockets.size())

	generate_vines()
	spawn_stars()
	_place_player()
	cave_generated.emit(cell_to_world(spawn_cell))


# ---------------------------------------------------------------- grid helpers

func _index(c: Vector2i) -> int:
	return (c.x - _min.x) + (c.y - _min.y) * map_width


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= _min.x and c.x < _min.x + map_width and c.y >= _min.y and c.y < _min.y + map_height


func _is_border(c: Vector2i) -> bool:
	return c.x < _min.x + border_thickness or c.x >= _min.x + map_width - border_thickness \
		or c.y < _min.y + border_thickness or c.y >= _min.y + map_height - border_thickness


func is_wall(c: Vector2i) -> bool:
	if not _in_bounds(c):
		return true
	return _grid[_index(c)] == WALL


func _set_wall(c: Vector2i, wall: bool) -> void:
	if _in_bounds(c):
		_grid[_index(c)] = WALL if wall else OPEN


func _cell_at(x: int, y: int) -> Vector2i:
	return _min + Vector2i(x, y)


func cell_to_world(c: Vector2i) -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(c))


func world_to_cell(p: Vector2) -> Vector2i:
	return tile_map.local_to_map(tile_map.to_local(p))


# ---------------------------------------------------------------- generation

func _setup_noise(seed_value: int) -> void:
	simplex_noise.seed = seed_value
	simplex_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	simplex_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	simplex_noise.fractal_octaves = noise_octaves
	simplex_noise.frequency = 1.0 / max(noise_period, 0.001)
	simplex_noise.fractal_gain = noise_persistence
	simplex_noise.fractal_lacunarity = noise_lacunarity


func _fill_from_noise() -> void:
	var stretch: float = max(horizontal_stretch, 0.01)
	for y in map_height:
		for x in map_width:
			var c := _cell_at(x, y)
			var n := simplex_noise.get_noise_2d(c.x / stretch, c.y)
			_grid[x + y * map_width] = OPEN if n > open_threshold else WALL


func _carve_tunnels() -> void:
	for i in tunnel_count:
		var pos := Vector2(
			rng.randi_range(_min.x, _min.x + map_width - 1),
			rng.randi_range(_min.y, _min.y + map_height - 1))
		var angle := rng.randf() * TAU
		for step in tunnel_length:
			_carve_circle(Vector2i(pos.round()), tunnel_radius)
			angle += rng.randf_range(-0.5, 0.5)
			# Flatten vertical movement so tunnels wander sideways more than up/down.
			pos += Vector2(cos(angle), sin(angle) * 0.5).normalized()


func _carve_circle(center: Vector2i, radius: int) -> void:
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius + radius:
				_set_wall(center + Vector2i(dx, dy), false)


func _count_wall_neighbors(c: Vector2i) -> int:
	var count := 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if (dx != 0 or dy != 0) and is_wall(c + Vector2i(dx, dy)):
				count += 1
	return count


func _smooth() -> void:
	var next := _grid.duplicate()
	for y in map_height:
		for x in map_width:
			var walls := _count_wall_neighbors(_cell_at(x, y))
			if walls > 4:
				next[x + y * map_width] = WALL
			elif walls < 4:
				next[x + y * map_width] = OPEN
	_grid = next


func _apply_border() -> void:
	for y in map_height:
		for x in map_width:
			var c := _cell_at(x, y)
			if _is_border(c):
				_set_wall(c, true)


func _pick_spawn_cell() -> Vector2i:
	var target: Vector2i = world_to_cell(spawn_maker.global_position) if spawn_maker else Vector2i.ZERO
	var half_w := spawn_room_size.x / 2 + 1
	target.x = clampi(target.x, _min.x + border_thickness + half_w, _min.x + map_width - border_thickness - half_w - 1)
	target.y = clampi(target.y, _min.y + border_thickness + spawn_room_size.y, _min.y + map_height - border_thickness - 2)
	return target


## The spawn cell sits on the bottom row of the room with a solid floor under it.
## This chamber is also where a "return to nest" exit should be placed.
func _carve_spawn_room() -> void:
	var half := spawn_room_size.x / 2
	for dx in range(-half, half + 1):
		for dy in range(-(spawn_room_size.y - 1), 1):
			_set_wall(spawn_cell + Vector2i(dx, dy), false)
		_set_wall(spawn_cell + Vector2i(dx, 1), true)


## Flood fills every connected group of cells of one type (4-directional).
func _find_regions(want_wall: bool) -> Array:
	var visited := PackedByteArray()
	visited.resize(map_width * map_height)
	var regions: Array = []
	for y in map_height:
		for x in map_width:
			var start := _cell_at(x, y)
			if visited[_index(start)] == 1 or is_wall(start) != want_wall:
				continue
			var region: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start]
			visited[_index(start)] = 1
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				region.append(cur)
				for d in DIRS4:
					var n: Vector2i = cur + d
					if _in_bounds(n) and visited[_index(n)] == 0 and is_wall(n) == want_wall:
						visited[_index(n)] = 1
						stack.append(n)
			regions.append(region)
	return regions


func _remove_small_wall_clusters() -> void:
	for region in _find_regions(true):
		if region.size() >= min_wall_cluster:
			continue
		for c in region:
			if not _is_border(c):
				_set_wall(c, false)


## Scans each column bottom-up. Once an open shaft gets taller than the dragon
## can jump, a one-cell ledge is stuck onto the side wall as a stepping stone.
func _add_climb_ledges() -> void:
	for x in range(border_thickness, map_width - border_thickness):
		var run := 0
		for y in range(map_height - border_thickness - 1, border_thickness - 1, -1):
			var c := _cell_at(x, y)
			if is_wall(c):
				run = 0
				continue
			run += 1
			if run < max_climb_height:
				continue
			var shaft_continues := not is_wall(c + Vector2i.UP) and not is_wall(c + Vector2i.UP * 2)
			if not shaft_continues:
				continue
			var wall_left := is_wall(c + Vector2i.LEFT)
			var wall_right := is_wall(c + Vector2i.RIGHT)
			# Attach to exactly one side so the ledge never plugs the whole shaft.
			if wall_left != wall_right:
				_set_wall(c, true)
				run = 0


func _resolve_pockets() -> void:
	geode_pockets.clear()
	var regions := _find_regions(false)
	if regions.is_empty():
		return

	var main_index := 0
	var spawn_index := -1
	for i in regions.size():
		if regions[i].size() > regions[main_index].size():
			main_index = i
		if spawn_index == -1 and regions[i].has(spawn_cell):
			spawn_index = i

	var main_lookup := {}
	for c in regions[main_index]:
		main_lookup[c] = true

	# The spawn room must always join the main cave, whatever the pocket mode.
	if spawn_index != -1 and spawn_index != main_index:
		_connect_region(regions[spawn_index], main_lookup)

	for i in regions.size():
		if i == main_index or i == spawn_index:
			continue
		var region: Array = regions[i]
		if region.size() < min_pocket_size or pocket_mode == PocketMode.FILL:
			for c in region:
				_set_wall(c, true)
		elif pocket_mode == PocketMode.CONNECT:
			_connect_region(region, main_lookup)
		# GEODE: leave it sealed; _collect_geodes() picks it up after painting.


## Multi-source BFS from the pocket through rock until it touches the main cave,
## then carves that shortest path as a tunnel. Merges the pocket into main_lookup.
func _connect_region(region: Array, main_lookup: Dictionary) -> void:
	var parent := {}
	var queue: Array[Vector2i] = []
	for c in region:
		parent[c] = c
		queue.append(c)

	var head := 0
	var hit := Vector2i.ZERO
	var found := false
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if main_lookup.has(cur):
			hit = cur
			found = true
			break
		for d in DIRS4:
			var n: Vector2i = cur + d
			if parent.has(n) or not _in_bounds(n) or _is_border(n):
				continue
			parent[n] = cur
			queue.append(n)

	for c in region:
		main_lookup[c] = true
	if not found:
		return

	var step: Vector2i = hit
	while parent[step] != step:
		_carve_circle(step, tunnel_radius)
		main_lookup[step] = true
		step = parent[step]


func _paint_tiles() -> void:
	tile_map.clear()
	var wall_cells: Array[Vector2i] = []
	# One extra ring outside the map so the outer border draws as solid rock.
	for y in range(-1, map_height + 1):
		for x in range(-1, map_width + 1):
			var c := _cell_at(x, y)
			if is_wall(c):
				wall_cells.append(c)
	tile_map.set_cells_terrain_connect(wall_cells, terrain_set, terrain, false)


func find_reachable(start: Vector2i) -> Dictionary:
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if not is_wall(n) and not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist


func _collect_geodes() -> void:
	geode_pockets.clear()
	for region in _find_regions(false):
		if not main_region.has(region[0]):
			geode_pockets.append(region)


func _is_explorable(c: Vector2i) -> bool:
	if main_region.has(c):
		return true
	for pocket in geode_pockets:
		if pocket.has(c):
			return true
	return false


func _place_player() -> void:
	var pos := cell_to_world(spawn_cell)
	if spawn_maker:
		spawn_maker.global_position = pos
	if player:
		player.global_position = pos
		player.reset_physics_interpolation()
		if "original_position" in player:
			player.set("original_position", player.position)


# ---------------------------------------------------------------- mining

## Foundation for a wall-breaking ability (claws, tail smash, star pick...).
## Returns true if a wall was removed. Breaking into a geode merges it into the cave.
func break_wall(world_position: Vector2) -> bool:
	var c := world_to_cell(world_position)
	if not _in_bounds(c) or not is_wall(c) or _is_border(c):
		return false
	_set_wall(c, false)
	tile_map.set_cells_terrain_connect([c], terrain_set, -1, false)
	if vine_layer:
		vine_layer.erase_cell(c)
	main_region = find_reachable(spawn_cell)
	_collect_geodes()
	wall_broken.emit(c)
	return true


# ---------------------------------------------------------------- stars

func spawn_stars() -> void:
	star_rng.seed = (world_seed + str(night)).hash()
	for child in stars_parent.get_children():
		child.queue_free()

	var candidates: Array[Vector2i] = []
	for cell in main_region.keys():
		if main_region[cell] < star_spawn_clearance:
			continue
		if _is_star_spot(cell):
			candidates.append(cell)
	_seeded_shuffle(candidates, star_rng)

	var placed: Array[Vector2i] = []
	for cell in candidates:
		if placed.size() >= star_count:
			break
		if _too_close(cell, placed):
			continue
		var data := _pick_star_type(main_region[cell])
		if data == null:
			continue
		placed.append(cell)
		_spawn_star(cell, data)

	var rarest := _rarest_star_type()
	if rarest:
		for pocket in geode_pockets:
			var spots: Array[Vector2i] = []
			for cell in pocket:
				if _is_star_spot(cell):
					spots.append(cell)
			_seeded_shuffle(spots, star_rng)
			for i in mini(geode_star_count, spots.size()):
				_spawn_star(spots[i], rarest)

	print("stars placed: ", placed.size(), " / candidates: ", candidates.size())


func _is_star_spot(cell: Vector2i) -> bool:
	return not is_wall(cell) and is_wall(cell + Vector2i.DOWN) and vine_layer.get_cell_source_id(cell) == -1


func _too_close(cell: Vector2i, placed: Array[Vector2i]) -> bool:
	for p in placed:
		if Vector2(cell - p).length() < star_min_separation:
			return true
	return false


func _seeded_shuffle(arr: Array, range: RandomNumberGenerator) -> void:
	# Array.shuffle() uses the global RNG and would break same-cave-per-seed.
	for i in range(arr.size() - 1, 0, -1):
		var j := range.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _pick_star_type(distance: int) -> ItemData:
	var total := 0
	for t in star_types:
		if distance >= t.min_distance:
			total += t.spawn_weight
	if total <= 0:
		return null
	var roll := star_rng.randi_range(1, total)
	for t in star_types:
		if distance >= t.min_distance:
			roll -= t.spawn_weight
			if roll <= 0:
				return t
	return null


func _rarest_star_type() -> ItemData:
	var best: ItemData = null
	for t in star_types:
		if best == null or t.min_distance > best.min_distance:
			best = t
	return best


func _spawn_star(cell: Vector2i, data: ItemData) -> void:
	var star := star_scene.instantiate()
	star.data = data
	stars_parent.add_child(star)
	star.global_position = cell_to_world(cell)


# ---------------------------------------------------------------- vines

func generate_vines() -> void:
	vine_layer.clear()
	var placed: Array[Vector2i] = []
	for y in map_height:
		for x in map_width:
			var ceiling := _cell_at(x, y)
			var below := ceiling + Vector2i.DOWN
			if not is_wall(ceiling) or is_wall(below) or not _is_explorable(below):
				continue
			if _vine_too_close(ceiling, placed):
				continue
			if rng.randf() > vine_spawn_chance:
				continue
			var length := _pick_vine_length(_measure_open_depth(ceiling))
			if length <= 0:
				continue
			_place_vine(ceiling, length)
			placed.append(ceiling)
	print("vines placed: ", placed.size())


func _vine_too_close(cell: Vector2i, placed: Array[Vector2i]) -> bool:
	for p in placed:
		if absi(cell.x - p.x) < vine_min_spacing and absi(cell.y - p.y) < vine_max_length:
			return true
	return false


## Leaves one cell of headroom so a vine never touches the floor.
func _measure_open_depth(ceiling_cell: Vector2i) -> int:
	var depth := 0
	var check := ceiling_cell + Vector2i.DOWN
	while not is_wall(check) and depth < vine_max_length + 1:
		depth += 1
		check += Vector2i.DOWN
	return depth - 1


func _pick_vine_length(max_depth: int) -> int:
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
		vine_layer.set_cell(ceiling_cell + Vector2i.DOWN, vine_source_id, vine_end_atlas)
		return
	for i in range(length):
		var pos := ceiling_cell + Vector2i(0, 1 + i)
		var atlas: Vector2i
		if i == 0:
			atlas = vine_top_atlas
		elif i == length - 1:
			atlas = vine_end_atlas
		else:
			atlas = vine_mid_atlas
		vine_layer.set_cell(pos, vine_source_id, atlas)
