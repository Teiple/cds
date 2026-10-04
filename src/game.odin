package game

import "core:os"
import "base:runtime"
import "core:math"
import linalg "core:math/linalg"
import sapp "sokol/app"
import sg "sokol/gfx"
import sglue "sokol/glue"
import slog "sokol/log"
import ui "ui"

g_odin_ctx := runtime.default_context()

Game_State :: struct {
	entry_point      : runtime.Source_Code_Location,
	entry_dir        : string,
	primitive_meshes : [dynamic]Mesh,
	models           : [dynamic]Model,
	renderer         : Renderer,
	frame_time       : Frame_Time,
	camera           : Camera,
	freecam          : Free_Camera,
	follow_cam       : Follow_Camera,
	viewport         : Viewport,
	audio            : Audio,
	ui               : Game_UI,
	console          : Console,
	debug_drawer     : Debug_Drawer,
	mouse            : Mouse_Input,
	physics          : Physics,
	player           : Player,
	environment      : Environment,
}

g_state: Game_State

game_init :: proc(entry_point: runtime.Source_Code_Location) {
	g_state.entry_point = entry_point
	g_state.entry_dir   = os.dir(entry_point.file_path)

	sg.setup({
		environment = sglue.environment(),
		logger = {func = slog.func},
	})

	viewport_init(base_size = {SCREEN_BASE_WIDTH, SCREEN_BASE_HEIGHT})
	freecam_init()
	follow_camera_init(offset = {0, 0.2, 3.5})

	ui_init()
	audio_init()
	physics_init()

	g_state.camera = {
		fovy_degrees = 60,
		position     = {0, 1.0, 3.5},
		target       = {0, 1.0, 0},
		up           = {0, 1, 0},
	}

	renderer_init(&g_state.renderer)
	debug_drawer_init(&g_state.debug_drawer)

	g_state.environment = environment_init()
	player_init({0, 1.5, 0})

	mouse_set_locked(true)
}

game_destroy :: proc() {
	viewport_destroy()

	player_destroy()
	environment_destroy(&g_state.environment)
	physics_destroy()

	for &mesh in g_state.primitive_meshes {
		mesh_destroy(&mesh)
	}
	delete(g_state.primitive_meshes)

	for &model in g_state.models {
		model_destroy(&model)
	}
	delete(g_state.models)

	ui_destroy()
	console_destroy()
	debug_drawer_destroy(&g_state.debug_drawer)
	audio_destroy()

	sg.shutdown()
}

game_frame :: proc() {
	dt := cast(f32)sapp.frame_duration_unfiltered()

	viewport_begin()
	{
		defer viewport_end()

		game_update(dt)
		game_draw()
	}

	mouse_end_frame()
	free_all(context.temp_allocator)
}

game_update :: proc(dt: f32) {
	frame_time_update(dt)
	physics_update(dt)

	if g_state.freecam.enabled {
		freecam_update(dt)
	} else {
		player_update(dt)
		follow_camera_update(player_get_position(), dt)
	}

	viewport_update({sapp.widthf(), sapp.heightf()})
}

game_draw :: proc() {
	player_draw()

	debug_draw_grid(slices = 20, spacing = 1.0, color = {50, 50, 50, 255})
	physics_debug_render()
	debug_render(&g_state.debug_drawer)

	if ui_draw() {
		console_update_ui()
	}
}

game_update_input_event :: proc(ev: sapp.Event) {
	console_update_input_event(ev)
	ui_update_input_event(ev)
	
	// 3D only receives input if UI didn't consume it
	if ui_is_capturing_input() {
		mouse_reset_input()
		freecam_reset_input()
		return
	}

	mouse_update_input_event(ev)
	if g_state.freecam.enabled {
		freecam_update_input_event(ev)
	}
}

game_quit :: proc() {
	sapp.quit()
}