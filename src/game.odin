package game
import "base:intrinsics"
import b3 "vendor:box3d"
import rl "vendor:raylib"

Scene_Kind :: enum {
	Title,
	Main_Menu,
	Gameplay,
}


Scene_Main_Menu :: struct {}

Scene_Gameplay :: struct {
	world:      b3.WorldId,
	camera:     Follow_Camera,
	player:     Entity_Player,
	debug_draw: b3.DebugDraw,
}

Scene :: union {
	Scene_Main_Menu,
	Scene_Gameplay,
}

Game_State :: struct {
	viewport:      ^Viewport,
	current_scene: ^Scene,
}

@(private)
g_game_state: Game_State

get_viewport :: proc "contextless" () -> ^Viewport {
	return g_game_state.viewport
}

get_scene :: proc "contextless" () -> ^Scene {
	return g_game_state.current_scene
}
