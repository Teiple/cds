package audio
import lg "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

Listener :: struct {
	forward:  [3]f32,
	up:       [3]f32,
	position: [3]f32,
}

play_sound_at_position :: proc(sound: rl.Sound, listener: Listener, position: [3]f32, maxDist: f32 = 20) {
	direction := position - listener.position
	distance := lg.length(direction)

	attenuation := 1.0 / (1.0 + (distance / maxDist))
	attenuation = clamp(attenuation, 0.0, 1.0)

	direction_normalized := lg.normalize0(direction)
	right := lg.cross(listener.forward, listener.up)

	// reduce volume for sounds behind the listener
	dot := lg.dot(listener.forward, direction_normalized)
	if dot < 0 {
		attenuation *= 1.0 - dot * 0.5
	}

	// set stereo panning based on sound position relative to listener
	pan := lg.dot(right, direction_normalized)

	rl.SetSoundVolume(sound, attenuation)
	rl.SetSoundPan(sound, pan)
	rl.PlaySound(sound)
}

play_sound_with_random_pitch_and_volume :: proc(
	sound: rl.Sound,
	volume_min: f32 = 0.8,
	volume_max: f32 = 1.0,
	pitch_min: f32 = 0.8,
	pitch_max: f32 = 1.2,
) {
	rl.SetSoundVolume(sound, rand.float32_range(volume_min, volume_max))
	rl.SetSoundPitch(sound, rand.float32_range(pitch_min, pitch_max))
	rl.PlaySound(sound)
}
