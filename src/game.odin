package game
import rl "vendor:raylib"

BASE_WINDOW_SIZE :: rl.Vector2{960, 540}
TARGET_WINDOW_SIZE :: rl.Vector2{1024, 576}


Scene_Main_Menu :: struct {}


Scene :: union {
	Scene_Main_Menu,
	Scene_Gameplay,
}

Game_State :: struct {
	viewport:      Viewport,
	current_scene: ^Scene,
	running:       bool,
}

@(private)
g_game_state: Game_State

get_viewport :: proc "contextless" () -> ^Viewport {
	return &g_game_state.viewport
}

get_camera :: proc "contextless" () -> (camera: ^rl.Camera, has_camera: bool) {
	switch &scene in g_game_state.current_scene {
	case Scene_Gameplay:
		return &scene.follow_camera, true
	case Scene_Main_Menu:
		return nil, false
	}
	return nil, false
}

game_make :: proc() {
	g_game_state = {}

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(i32(TARGET_WINDOW_SIZE.x), i32(TARGET_WINDOW_SIZE.y), "Game")
	rl.SetTargetFPS(60)

	g_game_state.viewport = viewport_make(BASE_WINDOW_SIZE)
}

game_delete :: proc() {
	rl.CloseWindow()
}
