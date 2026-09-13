package modules

import rl "vendor:raylib"

Model_Animation :: struct {
	model:                   rl.Model,
	animations:              []rl.ModelAnimation,
	current_animation_index: i32,
	current_animation_frame: i32,
	animation_indices:       map[Player_Animation]i32,
}
