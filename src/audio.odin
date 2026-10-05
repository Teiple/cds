package game

import aud "audio"

Sound_Id :: enum {
	Fire_Primary,
	Fire_Secondary,
}

sound_files : [Sound_Id][]byte = {
	.Fire_Primary   = #load("../assets/sounds/fire_primary.mp3"),
	.Fire_Secondary = #load("../assets/sounds/fire_secondary.mp3"),
}

Music_Id :: enum {
	Arena,
}

Audio :: aud.Context(Sound_Id, Music_Id)

audio_init :: proc(audio: ^Audio) {
	aud.init(audio)

	for file, id in sound_files {
		aud.make_sound(audio, id, file)
	}
}

audio_destroy :: proc(audio: ^Audio) {
	aud.destroy(audio)
}

audio_play_sound :: proc(audio: ^Audio, id: Sound_Id) {
	aud.play_sound(audio, id)
}

audio_update_listener :: proc(audio: ^Audio, listener_position: [3]f32) {
	aud.update_listener(audio, listener_position)
}

