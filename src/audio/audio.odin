package audio

import "base:intrinsics"
import "core:c"
import "core:mem"
import "base:runtime"
import ma "vendor:miniaudio"

Context :: struct($Sound_Id : typeid, $Music_Id : typeid)
	where intrinsics.type_is_enum(Sound_Id) &&
		intrinsics.type_is_enum(Music_Id) &&
		Sound_Id != Music_Id {
	engine     : ma.engine,
	sound_map  : map[Sound_Id]^Sound,
	music_map  : map[Music_Id]^Music,
}

Audio_Data :: struct {
	ma_sound     : ma.sound,
	audio_buffer : ma.audio_buffer,
	pcm_data     : rawptr,
}

Sound :: struct {
	using audio_data : Audio_Data,
	pitch_range      : Maybe(struct {
		min : f32,
		max : f32,
	}),
}

Music :: struct {
	using audio_data : Audio_Data,
	is_looping       : bool,
}

init  :: proc(ctx : ^Context($Sound_Id, $Music_Id)) {
	res := ma.engine_init(nil, &ctx.engine)
	assert(res == .SUCCESS)

	ctx.sound_map  = make(map[Sound_Id]^Sound, 10)
	ctx.music_map  = make(map[Music_Id]^Music, 4)
}

@(private = "file")
make_audio_data  :: proc(
	ctx        : ^Context($Sound_Id, $Music_Id),
	audio_data : ^Audio_Data,
	file_data  : []byte,
) {
	frame_count: u64

	channels    := ma.engine_get_channels(&ctx.engine)
	sample_rate := ma.engine_get_sample_rate(&ctx.engine)

	decoder_cfg := ma.decoder_config_init(.f32, channels, sample_rate)

	res := ma.decode_memory(
		raw_data(file_data), 
		len(file_data), 
		&decoder_cfg, 
		&frame_count, 
		&audio_data.pcm_data
	)

	assert(res == .SUCCESS)

	aud_buf_cfg := ma.audio_buffer_config_init(
		.f32,
		channels, 
		frame_count, 
		audio_data.pcm_data,
		nil,
	)
	aud_buf_cfg.sampleRate = sample_rate
	
	ma.audio_buffer_init(&aud_buf_cfg, &audio_data.audio_buffer)

	ma.sound_init_from_data_source(
		&ctx.engine,
		cast(^ma.data_source)(&audio_data.audio_buffer),
		{.NO_SPATIALIZATION},
		nil,
		&audio_data.ma_sound,
	)
}

@(private = "file")
destroy_audio_data  :: proc(ctx : ^Context($Sound_Id, $Music_Id), audio_data : ^Audio_Data) {
	ma.sound_uninit(&audio_data.ma_sound)
	ma.audio_buffer_uninit(&audio_data.audio_buffer)
	ma.free(audio_data.pcm_data, nil)
}

make_sound  :: proc(
	ctx       : ^Context($Sound_Id, $Music_Id),
	sound_id  : Sound_Id,
	file_data : []byte,
) {
	assert(sound_id not_in ctx.sound_map)
	sound := new(Sound)
	make_audio_data(ctx, &sound.audio_data, file_data)
	ctx.sound_map[sound_id] = sound
}

make_music  :: proc(
	ctx       : ^Context($Sound_Id, $Music_Id),
	music_id  : Music_Id,
	file_data : []byte,
) {
	assert(music_id not_in ctx.music_map)
	music := new(Music)
	make_audio_data(ctx, &music.audio_data, file_data)
	ctx.music_map[music_id] = music
}

destroy_sound  :: proc(ctx : ^Context($Sound_Id, $Music_Id), sound_id : Sound_Id) {
	assert(sound_id in ctx.sound_map)
	sound := ctx.sound_map[sound_id]
	destroy_audio_data(ctx, &sound.audio_data)
	free(sound)
	delete_key(&ctx.sound_map, sound_id)
}

destroy_music  :: proc(ctx : ^Context($Sound_Id, $Music_Id), music_id : Music_Id) {
	assert(music_id in ctx.music_map)
	music := ctx.music_map[music_id]
	destroy_audio_data(ctx, &music.audio_data)
	free(music)
	delete_key(&ctx.music_map, music_id)
}

update_listener  :: proc(
	ctx               : ^Context($Sound_Id, $Music_Id), 
	listener_position : [3]f32,
) {
	ma.engine_listener_set_position(
		&ctx.engine,
		0,
		listener_position.x, listener_position.y, listener_position.z
	)
}

destroy  :: proc(ctx : ^Context($Sound_Id, $Music_Id)) {
	for id in ctx.sound_map {
		destroy_sound(ctx, id)
	}
	delete(ctx.sound_map)
	
	for id in ctx.music_map {
		destroy_music(ctx, id)
	}
	delete(ctx.music_map)

	ma.engine_uninit(&ctx.engine)
}

play_sound :: proc(ctx : ^Context($Sound_Id, $Music_Id), sound_id : Sound_Id){
	assert(sound_id in ctx.sound_map)
	sound := ctx.sound_map[sound_id]
	ma.sound_seek_to_pcm_frame(&sound.ma_sound, 0)
	ma.sound_start(&sound.ma_sound)
}