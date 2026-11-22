class_name DungeonMap
extends Node2D

const MAP_WIDTH: int = 24
const MAP_HEIGHT: int = 14
const TILE_SIZE: int = 16
const SOURCE_ID: int = 0
const TILEMAP_PATH: String = "res://assets/kenney_tiny_dungeon/Tilemap/tilemap_packed.png"

const FLOOR_PRIMARY: Vector2i = Vector2i(0, 4)
const FLOOR_PEBBLE: Vector2i = Vector2i(1, 4)
const FLOOR_CRACK: Vector2i = Vector2i(6, 3)
const WALL_BRICK: Vector2i = Vector2i(4, 3)
const WALL_PILLAR: Vector2i = Vector2i(7, 1)

const PILLAR_CELLS: Array[Vector2i] = [
	Vector2i(6, 4),
	Vector2i(17, 4),
	Vector2i(6, 9),
	Vector2i(17, 9),
]

@onready var floor_layer: TileMapLayer = $FloorLayer
@onready var wall_layer: TileMapLayer = $WallLayer


func _ready() -> void:
	var tile_set: TileSet = _build_tile_set()
	floor_layer.tile_set = tile_set
	wall_layer.tile_set = tile_set
	_paint_dungeon()
	wall_layer.update_internals()


func is_wall_at_world(world_pos: Vector2) -> bool:
	var cell: Vector2i = wall_layer.local_to_map(wall_layer.to_local(world_pos))
	if cell.x < 0 or cell.x >= MAP_WIDTH or cell.y < 0 or cell.y >= MAP_HEIGHT:
		return true
	return wall_layer.get_cell_source_id(cell) != -1


func get_floor_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(1, MAP_WIDTH - 1):
		for y in range(1, MAP_HEIGHT - 2):
			var coords: Vector2i = Vector2i(x, y)
			if wall_layer.get_cell_source_id(coords) == -1:
				cells.append(coords)
	return cells


func get_random_floor_position(
	avoid_pos: Vector2 = Vector2.ZERO,
	min_distance: float = 0.0
) -> Vector2:
	var floor_cells: Array[Vector2i] = get_floor_cells()
	if floor_cells.is_empty():
		return get_viewport_rect().size * 0.5
	var fallback: Vector2 = _cell_to_world_center(floor_cells[0])
	for _attempt in range(30):
		var chosen: Vector2i = floor_cells[randi_range(0, floor_cells.size() - 1)]
		var candidate: Vector2 = _cell_to_world_center(chosen)
		fallback = candidate
		if min_distance <= 0.0 or candidate.distance_to(avoid_pos) >= min_distance:
			return candidate
	return fallback


func _cell_to_world_center(coords: Vector2i) -> Vector2:
	return floor_layer.to_global(floor_layer.map_to_local(coords))


func _build_tile_set() -> TileSet:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()

	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = load(TILEMAP_PATH) as Texture2D
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for tile_coords in [FLOOR_PRIMARY, FLOOR_PEBBLE, FLOOR_CRACK, WALL_BRICK, WALL_PILLAR]:
		atlas.create_tile(tile_coords)

	tile_set.add_source(atlas, SOURCE_ID)

	var half: float = float(TILE_SIZE) * 0.5
	var wall_poly: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	])
	for wall_coords in [WALL_BRICK, WALL_PILLAR]:
		var data: TileData = atlas.get_tile_data(wall_coords, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, wall_poly)

	return tile_set


func _paint_dungeon() -> void:
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var coords: Vector2i = Vector2i(x, y)
			var floor_tile: Vector2i = _pick_floor_tile(coords)
			floor_layer.set_cell(coords, SOURCE_ID, floor_tile)
			if x == 0 or x == MAP_WIDTH - 1 or y == 0 or y == MAP_HEIGHT - 1:
				wall_layer.set_cell(coords, SOURCE_ID, WALL_BRICK)

	for pillar in PILLAR_CELLS:
		wall_layer.set_cell(pillar, SOURCE_ID, WALL_PILLAR)


func _pick_floor_tile(coords: Vector2i) -> Vector2i:
	var pattern_hash: int = (coords.x * 7 + coords.y * 13) % 11
	if pattern_hash == 0:
		return FLOOR_CRACK
	if pattern_hash <= 2:
		return FLOOR_PEBBLE
	return FLOOR_PRIMARY
