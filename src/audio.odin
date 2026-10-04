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

audio_init :: proc() {
	aud.init(&g_state.audio)

	for file, id in sound_files {
		aud.make_sound(&g_state.audio, id, file)
	}
}

audio_destroy :: proc() {
	aud.destroy(&g_state.audio)
}

audio_play_sound :: proc(id: Sound_Id) {
	aud.play_sound(&g_state.audio, id)
}

audio_update_listener :: proc(listener_position: [3]f32) {
	aud.update_listener(&g_state.audio, listener_position)
}

