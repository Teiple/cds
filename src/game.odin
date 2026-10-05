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

	viewport_init(&g_state.viewport, base_size = {GAME_SCREEN_BASE_WIDTH, GAME_SCREEN_BASE_HEIGHT})
	ui_init(&g_state.ui, g_state.entry_dir)
	audio_init(&g_state.audio)
	renderer_init(&g_state.renderer)
	debug_drawer_init(&g_state.debug_drawer)
	console_init(&g_state.console)

	scene_set(Scene_State_Gameplay{})
}

game_destroy :: proc() {
	if g_state.scene.callbacks.destroy != nil {
		g_state.scene.callbacks.destroy()
	}

	viewport_destroy(&g_state.viewport)

	for &mesh in g_state.primitive_meshes {
		mesh_destroy(&mesh)
	}
	delete(g_state.primitive_meshes)

	for &model in g_state.models {
		model_destroy(&model)
	}
	delete(g_state.models)

	ui_destroy(&g_state.ui)
	console_destroy(&g_state.console)
	debug_drawer_destroy(&g_state.debug_drawer)
	audio_destroy(&g_state.audio)

	sg.shutdown()
}

game_update :: proc(dt: f32) {
	viewport_begin(&g_state.viewport)
	{
		defer viewport_end(&g_state.viewport)
		
		frame_time_update(dt)
		viewport_update(&g_state.viewport, {sapp.widthf(), sapp.heightf()})

		if g_state.scene.callbacks.update != nil {
			g_state.scene.callbacks.update(dt)
		}

		game_draw()
	}

	mouse_end_frame(&g_state.mouse)
	free_all(context.temp_allocator)
}

game_draw :: proc() {
	// 3D
	if g_state.scene.callbacks.draw_3d != nil {
		g_state.scene.callbacks.draw_3d()
	}

	// UI
	if ui_begin(&g_state.ui, &g_state.viewport) {
		console_update_ui(&g_state.console)
		
		if g_state.scene.callbacks.draw_ui != nil {
			g_state.scene.callbacks.draw_ui()
		}

		ui_end(&g_state.ui, &g_state.viewport, g_state.frame_time.average_fps)
	}
	
}

game_update_input_event :: proc(ev: sapp.Event) {
	console_update_input_event(&g_state.console, ev)
	ui_update_input_event(&g_state.ui, &g_state.viewport, ev)
	
	// 3D only receives input if UI didn't consume it
	if ui_is_capturing_input() {
		mouse_reset_input(&g_state.mouse)

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