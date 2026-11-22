class_name SfxFactory
extends RefCounted

const MIX_RATE: int = 22050
const MELODY_HZ: Array[float] = [
	293.66, 349.23, 440.0, 349.23,
	329.63, 392.0, 523.25, 392.0,
	293.66, 349.23, 440.0, 587.33,
	523.25, 440.0, 392.0, 329.63,
]
const BASS_HZ: Array[float] = [
	146.83, 146.83, 146.83, 146.83,
	130.81, 130.81, 130.81, 130.81,
	116.54, 116.54, 116.54, 116.54,
	130.81, 130.81, 164.81, 164.81,
]


static func create_tone(
	start_hz: float,
	end_hz: float,
	duration: float,
	volume: float = 0.25
) -> AudioStreamWAV:
	var sample_count: int = maxi(1, int(MIX_RATE * duration))
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(sample_count * 2)
	var phase: float = 0.0
	for i in range(sample_count):
		var progress: float = float(i) / float(sample_count)
		var freq: float = lerpf(start_hz, end_hz, progress)
		var envelope: float = 1.0 - progress
		phase += TAU * freq / float(MIX_RATE)
		var sample_val: float = sin(phase) * volume * envelope
		bytes.encode_s16(i * 2, int(clampf(sample_val, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


static func create_keepalive(duration: float = 0.5) -> AudioStreamWAV:
	var sample_count: int = maxi(1, int(MIX_RATE * duration))
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in range(sample_count):
		var dither: int = 1 if (i % 2) == 0 else -1
		bytes.encode_s16(i * 2, dither)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = sample_count
	wav.data = bytes
	return wav


static func create_dungeon_bgm(step_duration: float = 0.18, volume: float = 0.16) -> AudioStreamWAV:
	var step_samples: int = maxi(1, int(MIX_RATE * step_duration))
	var step_count: int = MELODY_HZ.size()
	var total_samples: int = step_samples * step_count
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(total_samples * 2)
	var lead_phase: float = 0.0
	var bass_phase: float = 0.0
	for step_idx in range(step_count):
		var lead_freq: float = MELODY_HZ[step_idx]
		var bass_freq: float = BASS_HZ[step_idx]
		var base_offset: int = step_idx * step_samples
		for i in range(step_samples):
			var note_progress: float = float(i) / float(step_samples)
			var lead_env: float = 1.0 - 0.65 * note_progress
			var bass_env: float = 1.0 - 0.35 * note_progress
			lead_phase += TAU * lead_freq / float(MIX_RATE)
			bass_phase += TAU * bass_freq / float(MIX_RATE)
			var pulse: float = 1.0 if sin(lead_phase) >= 0.0 else -1.0
			var lead_wave: float = (0.45 * pulse + 0.55 * sin(lead_phase)) * lead_env
			var bass_wave: float = sin(bass_phase) * 0.55 * bass_env
			var sample_val: float = (lead_wave * 0.6 + bass_wave * 0.4) * volume
			var sample_index: int = base_offset + i
			bytes.encode_s16(sample_index * 2, int(clampf(sample_val, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total_samples
	wav.data = bytes
	return wav
