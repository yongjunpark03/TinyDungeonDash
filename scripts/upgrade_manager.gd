class_name UpgradeManager
extends RefCounted

const UPGRADE_POOL: Array[Dictionary] = [
	{
		"id": "power_slash",
		"title": "강화 검기 (+1 공격력)",
		"description": "검기 데미지가 1 증가합니다.",
	},
	{
		"id": "rapid_slash",
		"title": "신속 검기 (+20% 공격속도)",
		"description": "검기 발사 간격이 20% 짧아집니다.",
	},
	{
		"id": "twin_slash",
		"title": "거대 관통 검기 (+1 관통)",
		"description": "검기 관통 수가 1 늘고 크기가 커집니다.",
	},
	{
		"id": "swift_boots",
		"title": "질풍 장화 (+15% 기동력)",
		"description": "이동속도 +15% 및 대시 쿨타임 15% 감소.",
	},
	{
		"id": "vital_heart",
		"title": "생명의 성배 (+1 최대체력)",
		"description": "최대 HP +1 증가 및 체력 1 즉시 회복.",
	},
]

var level: int = 1
var current_xp: int = 0
var xp_to_next: int = 3
var bonus_damage: int = 0
var attack_interval_scale: float = 1.0
var bonus_pierce: int = 0
var slash_scale_bonus: float = 1.0
var move_speed_scale: float = 1.0
var dash_cooldown_scale: float = 1.0
var upgrade_counts: Dictionary = {}


func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	current_xp += amount
	var gained_levels: int = 0
	while current_xp >= xp_to_next:
		current_xp -= xp_to_next
		level += 1
		xp_to_next = 3 + (level - 1) * 2
		gained_levels += 1
	return gained_levels


func roll_choices(count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = UPGRADE_POOL.duplicate()
	pool.shuffle()
	var picked: Array[Dictionary] = []
	var take_count: int = mini(count, pool.size())
	for i in range(take_count):
		picked.append(pool[i])
	return picked


func apply_upgrade(upgrade_id: String, player: Player = null) -> bool:
	var matched: bool = true
	match upgrade_id:
		"power_slash":
			bonus_damage += 1
		"rapid_slash":
			attack_interval_scale = maxf(0.35, attack_interval_scale * 0.8)
		"twin_slash":
			bonus_pierce += 1
			slash_scale_bonus = minf(2.2, slash_scale_bonus + 0.25)
		"swift_boots":
			move_speed_scale = minf(2.0, move_speed_scale * 1.15)
			dash_cooldown_scale = maxf(0.4, dash_cooldown_scale * 0.85)
		"vital_heart":
			if player != null:
				player.grant_max_hp(1)
		_:
			matched = false

	if not matched:
		return false
	upgrade_counts[upgrade_id] = int(upgrade_counts.get(upgrade_id, 0)) + 1
	if player != null:
		player.damage_bonus = bonus_damage
		player.attack_interval_multiplier = attack_interval_scale
		player.move_speed_multiplier = move_speed_scale
		player.dash_cooldown_multiplier = dash_cooldown_scale
	return true
