package game

import "core:os"
import "base:runtime"
import sapp "sokol/app"
import sg "sokol/gfx"
import sglue "sokol/glue"
import slog "sokol/log"
import ui "ui"


GAME_SCREEN_BASE_WIDTH  :: 800
GAME_SCREEN_BASE_HEIGHT :: 480

g_odin_ctx := runtime.default_context()

Game_State :: struct {
	entry_point      : runtime.Source_Code_Location,
	entry_dir        : string,
	primitive_meshes : [dynamic]Mesh,
	models           : [dynamic]Model,
	renderer         : Renderer,
	frame_time       : Frame_Time,
	viewport         : Viewport,
	audio            : Audio,
	ui               : Game_UI,
	console          : Console,
	debug_drawer     : Debug_Drawer,
	mouse            : Mouse_Input,
	scene            : struct {
		state         : Scene_State,
		callbacks     : Scene_Callbacks,
	},
}

g_state: Game_State

game_init :: proc(entry_point: runtime.Source_Code_Location) {
	g_state.entry_point = entry_point
	g_state.entry_dir   = os.dir(entry_point.file_path)

	sg.setup({
		environment = sglue.environment(),
		logger = {func = slog.func},
	})

	viewport_init(base_size = {GAME_SCREEN_BASE_WIDTH, GAME_SCREEN_BASE_HEIGHT})
	ui_init()
	audio_init()
	renderer_init(&g_state.renderer)
	debug_drawer_init(&g_state.debug_drawer)
	console_init()

	scene_set(Scene_State_Gameplay{})
}

game_destroy :: proc() {
	if g_state.scene.callbacks.destroy != nil {
		g_state.scene.callbacks.destroy()
	}

	viewport_destroy()

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
	viewport_update({sapp.widthf(), sapp.heightf()})

	if g_state.scene.callbacks.update != nil {
		g_state.scene.callbacks.update(dt)
	}
}

game_draw :: proc() {
	if g_state.scene.callbacks.draw_3d != nil {
		g_state.scene.callbacks.draw_3d()
	}

	if ui_draw() {
		console_update_ui()
	}

	if g_state.scene.callbacks.draw_ui != nil {
		g_state.scene.callbacks.draw_ui()
	}
}

game_update_input_event :: proc(ev: sapp.Event) {
	console_update_input_event(ev)
	ui_update_input_event(ev)
	
	// 3D only receives input if UI didn't consume it
	if ui_is_capturing_input() {
		mouse_reset_input()
		if g_state.scene.callbacks.handle_input_ui != nil {
			g_state.scene.callbacks.handle_input_ui(ev)
		}
		return
	}

	if g_state.scene.callbacks.handle_input_3d != nil {
		g_state.scene.callbacks.handle_input_3d(ev)
	}
}

game_quit :: proc() {
	sapp.quit()
}