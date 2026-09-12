package audio
import lg "core:math/linalg"
import rl "vendor:raylib"

Listener :: struct {
	forward:  rl.Vector3,
	up:       rl.Vector3,
	position: rl.Vector3,
}

play_sound_at_position :: proc(sound: rl.Sound, listener: Listener, position: rl.Vector3, maxDist: f32 = 20) {
	direction := position - listener.position
	distance := lg.length(direction)

	attenuation := 1.0 / (1.0 + (distance / maxDist))
	attenuation = clamp(attenuation, 0.0, 1.0)

	direction_normalized := lg.normalize0(direction)
	right := lg.cross(listener.forward, listener.up)

	dot := lg.dot(right, direction_normalized)

	if dot < 0 {
		attenuation *= 1.0 - dot * 0.5
	}

	pan := lg.dot(right, direction_normalized)

	rl.SetSoundVolume(sound, attenuation)
	rl.SetSoundPan(sound, pan)
}
