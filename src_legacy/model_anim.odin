package game

import "base:intrinsics"
import rl "vendor:raylib"

Model_Anim :: struct($T: typeid) where intrinsics.type_is_enum(T) {
	model:                   rl.Model,
	animations:              []rl.ModelAnimation,
	current_animation:       T,
	current_animation_frame: i32,
	animation_indices:       map[T]i32,
}

model_anim_make :: proc(
	model: rl.Model,
	anim_path: cstring,
	anim_names: [$T]string,
) -> Model_Anim(T) where intrinsics.type_is_enum(T) {
	anim_count: i32
	raw_anims := rl.LoadModelAnimations(anim_path, &anim_count)
	assert(anim_count > 0, "Model has no animations")

	animation_indices := make(map[T]i32, len(anim_names))
	// Figure out the animation index
	for &anim, anim_index in raw_anims[:anim_count] {
		anim_name := string(cstring(&anim.name[0]))
		for name, enum_code in anim_names {
			if anim_name == name {
				_, existed := animation_indices[enum_code]
				assert(!existed, "Animation already existed")
				animation_indices[enum_code] = i32(anim_index)
				break
			}
		}
	}
	assert(
		len(animation_indices) == len(anim_names),
		"Mismatch animation counts",
	)

	return {
		model = model,
		animations = raw_anims[:anim_count],
		current_animation = min(T),
		current_animation_frame = 0,
		animation_indices = animation_indices,
	}
}

m_model_anim_delete :: proc(mod: ^Model_Anim($T)) {
	delete(mod.animation_indices)
	rl.UnloadModelAnimations(
		raw_data(mod.animations),
		i32(len(mod.animations)),
	)
}

m_model_anim_play :: proc(mod: ^Model_Anim($T), anim: T) {
	mod.current_animation = anim
	mod.current_animation_frame = 0
}

m_model_anim_update :: proc(mod: ^Model_Anim($T)) {
	cur_anim := mod.animations[mod.animation_indices[mod.current_animation]]

	if mod.current_animation_frame < cur_anim.keyframeCount {
		rl.UpdateModelAnimation(
			mod.model,
			cur_anim,
			f32(mod.current_animation_frame),
		)
		mod.current_animation_frame += 1
	}
}
