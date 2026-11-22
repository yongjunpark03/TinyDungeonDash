extends GutTest

const DUNGEON_MAP_SCENE: PackedScene = preload("res://scenes/dungeon_map.tscn")


func test_border_and_pillars_are_walls() -> void:
	var dungeon: DungeonMap = DUNGEON_MAP_SCENE.instantiate() as DungeonMap
	add_child_autofree(dungeon)
	assert_true(dungeon.is_wall_at_world(Vector2(24.0, 24.0)), "Top-left border must be a wall")
	assert_true(dungeon.is_wall_at_world(Vector2(1128.0, 24.0)), "Top-right border must be a wall")
	assert_true(dungeon.is_wall_at_world(Vector2(312.0, 216.0)), "Pillar at (6, 4) must be a wall")


func test_center_player_spawn_is_walkable_floor() -> void:
	var dungeon: DungeonMap = DUNGEON_MAP_SCENE.instantiate() as DungeonMap
	add_child_autofree(dungeon)
	assert_false(dungeon.is_wall_at_world(Vector2(576.0, 324.0)), "Center spawn must be walkable")


func test_random_floor_position_avoids_walls_and_respects_distance() -> void:
	var dungeon: DungeonMap = DUNGEON_MAP_SCENE.instantiate() as DungeonMap
	add_child_autofree(dungeon)
	var player_pos: Vector2 = Vector2(576.0, 324.0)
	for _i in range(20):
		var spawn_pos: Vector2 = dungeon.get_random_floor_position(player_pos, 180.0)
		assert_false(dungeon.is_wall_at_world(spawn_pos), "Spawn position must not be inside a wall")
		assert_gte(spawn_pos.distance_to(player_pos), 180.0, "Spawn must stay >= 180px from player")
