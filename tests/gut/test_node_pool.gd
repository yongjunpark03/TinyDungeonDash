extends GutTest


func test_node_pool_reuses_released_nodes_without_creating_duplicates() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var pool: NodePool = NodePool.new()
	var orb_scene: PackedScene = load("res://scenes/magic_orb.tscn") as PackedScene
	pool.setup(orb_scene, parent, 3)

	assert_eq(pool.total_created, 3)
	assert_eq(pool.get_available_count(), 3)
	assert_eq(pool.get_active_count(), 0)

	var a: Node = pool.acquire()
	var b: Node = pool.acquire()
	assert_not_null(a)
	assert_not_null(b)
	assert_eq(pool.get_active_count(), 2)
	assert_eq(pool.get_available_count(), 1)
	assert_eq(pool.total_reused, 2)
	assert_eq(pool.total_created, 3)

	assert_true(pool.release(a))
	var c: Node = pool.acquire()
	assert_eq(c, a, "Pool should reuse the exact released node instance")
	assert_eq(pool.total_created, 3)


func test_pooled_slash_and_xp_gem_return_to_pool_on_finish() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)

	var slash_pool: NodePool = NodePool.new()
	slash_pool.setup(load("res://scenes/slash_projectile.tscn") as PackedScene, parent, 1)
	var slash: SlashProjectile = slash_pool.acquire() as SlashProjectile
	slash.release_callback = slash_pool.release
	slash.activate(Vector2.ZERO, Vector2.RIGHT, 1, 1, 1.0)
	var enemy: Enemy = Enemy.new()
	enemy.max_hp = 2
	enemy.current_hp = 2
	add_child_autofree(enemy)

	assert_true(slash.try_hit_enemy(enemy))
	assert_eq(slash_pool.get_active_count(), 0)
	assert_eq(slash_pool.get_available_count(), 1)

	var xp_pool: NodePool = NodePool.new()
	xp_pool.setup(load("res://scenes/xp_gem.tscn") as PackedScene, parent, 1)
	var gem: XpGem = xp_pool.acquire() as XpGem
	gem.release_callback = xp_pool.release
	gem.activate(Vector2.ZERO, 2, enemy)
	assert_true(gem.collect())
	assert_eq(xp_pool.get_active_count(), 0)
	assert_eq(xp_pool.get_available_count(), 1)


func test_benchmark_arena_switches_between_naive_and_pooled_modes() -> void:
	var arena: BenchmarkArena = BenchmarkArena.new()
	add_child_autofree(arena)
	arena.set_target_count(15)
	assert_eq(arena.get_active_entity_count(), 15)
	arena.set_mode(BenchmarkArena.BenchMode.POOLED_BATCHED)
	assert_eq(arena.get_active_entity_count(), 15)
	arena.set_target_count(5)
	assert_eq(arena.get_active_entity_count(), 5)
	arena.set_target_count(12)
	assert_eq(arena.get_active_entity_count(), 12)
	assert_gte(arena.get_pool_reuse_count(), 7)
