class_name SfxFactory
extends RefCounted

const MIX_RATE: int = 22050


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
