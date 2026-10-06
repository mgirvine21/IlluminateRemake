extends Node2D

const MAP_SIZE := Vector2i(90, 60)
const OFFSET := Vector2i(45, 30)

@export var player: Node2D
@export var reveal_radius: int = 6

var _fog_image: Image
var _fog_texture: ImageTexture
var _last_cell := Vector2i(-9999, -9999)

func _generate_minimap() -> void:
	var map := Image.create(MAP_SIZE.x, MAP_SIZE.y, false, Image.FORMAT_RGB8)
	map.fill(Color.WHITE)
	for cell in %Cave.get_used_cells():
		var p: Vector2i = cell + OFFSET
		if p.x >= 0 and p.x < MAP_SIZE.x and p.y >= 0 and p.y < MAP_SIZE.y:
			map.set_pixelv(p, Color.BLACK)
	%MiniMap.texture = ImageTexture.create_from_image(map)
	
	_fog_image = Image.create(MAP_SIZE.x, MAP_SIZE.y, false, Image.FORMAT_RGBA8)
	_fog_image.fill(Color(0.05, 0.05, 0.08, 1.0))
	_fog_texture = ImageTexture.create_from_image(_fog_image)
	%Fog.texture = _fog_texture
	_last_cell = Vector2i(-9999, -9999)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%CaveGenerator.cave_generated.connect(func(_spawn): _generate_minimap())
	_generate_minimap()

func reveal_around(cell: Vector2i) -> void:
	if cell == _last_cell:
		return  # only touch the texture when the player changes cells
	_last_cell = cell

	var center := cell + OFFSET
	var r := reveal_radius
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r:
				continue
			var p := center + Vector2i(dx, dy)
			if p.x < 0 or p.x >= MAP_SIZE.x or p.y < 0 or p.y >= MAP_SIZE.y:
				continue
			_fog_image.set_pixelv(p, Color(0, 0, 0, 0))  # fully transparent = revealed
	_fog_texture.update(_fog_image)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	if player == null or _fog_image == null:
		return
	var cave: TileMapLayer = %Cave
	var cell: Vector2i = cave.local_to_map(cave.to_local(player.global_position))
	reveal_around(cell)
