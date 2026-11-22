class_name WaveDirector
extends RefCounted

const COMBO_WINDOW: float = 3.5
const MAX_MULTIPLIER: int = 4
const COINS_PER_WAVE: int = 4
const SPEED_STEP_PER_WAVE: float = 0.12
const MAX_SPEED_SCALE: float = 1.8

var wave: int = 1
var coins_collected: int = 0
var combo_count: int = 0
var combo_time_left: float = 0.0


func get_multiplier() -> int:
	return mini(1 + (combo_count >> 1), MAX_MULTIPLIER)


func get_enemy_speed_scale() -> float:
	return minf(MAX_SPEED_SCALE, 1.0 + float(wave - 1) * SPEED_STEP_PER_WAVE)


func register_coin_pickup() -> Dictionary:
	coins_collected += 1
	combo_count += 1
	combo_time_left = COMBO_WINDOW
	var points: int = get_multiplier()
	var new_wave: int = 1 + floori(float(coins_collected) / float(COINS_PER_WAVE))
	var wave_advanced: bool = new_wave > wave
	wave = new_wave
	return {
		"points": points,
		"multiplier": points,
		"wave": wave,
		"wave_advanced": wave_advanced,
	}


func reset_combo() -> void:
	combo_count = 0
	combo_time_left = 0.0


func tick(delta: float) -> bool:
	if combo_time_left <= 0.0:
		return false
	combo_time_left = maxf(0.0, combo_time_left - delta)
	if combo_time_left <= 0.0:
		combo_count = 0
		return true
	return false
