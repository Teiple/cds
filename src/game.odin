package game

import "core:fmt"
import "core:os"
import "base:runtime"
import "core:math"
import linalg "core:math/linalg"
import sapp "sokol/app"
import sg "sokol/gfx"
import sglue "sokol/glue"
import slog "sokol/log"
import ui "ui"
import uis "ui_sokol"

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
	viewport         : Viewport,
	audio            : Audio,
	ui               : Game_UI,
	console          : Console,
	debug_drawer     : Debug_Drawer,
	mouse            : Mouse_Input,
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

	ui_init()
	audio_init()

	g_state.camera = {
		fovy_degrees = 60,
		position     = {0, 0.5, 2.0},
		target       = {0, 0, 0},
		up           = {0, 1, 0},
	}

	renderer_init(&g_state.renderer)
	debug_drawer_init(&g_state.debug_drawer)

	append(&g_state.models, mesh_make_model(#load("../assets/models/pistol.glb")))
}

game_destroy :: proc() {
	viewport_destroy()

	for &mesh in g_state.primitive_meshes {
		mesh_destroy(&mesh)
	}
	delete(g_state.primitive_meshes)

	for &model in g_state.models {
		mesh_destroy_model(&model)
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
	freecam_update(dt)

	if is_mouse_pressed(.Left) {
		fmt.println("Mouse Left Pressed at virtual pos:", mouse_position(), "screen pos:", g_state.mouse.screen_pos)
	}
	if is_mouse_pressed(.Right) {
		fmt.println("Mouse Right Pressed at virtual pos:", mouse_position())
	}

	viewport_update({sapp.widthf(), sapp.heightf()})
}

game_draw :: proc() {
	for model in g_state.models {
		draw_model(model)
	}

	debug_draw_grid(slices = 10, spacing = 0.5, color = {80, 80, 80, 255})
	debug_draw_box(center = {-0.6, 0.2, 0}, size = {0.3, 0.3, 0.3}, color = {255, 100, 100, 255})
	debug_draw_sphere(center = {0.6, 0.2, 0}, radius = 0.2, color = {100, 255, 100, 255})
	debug_draw_ray(origin = {0, 0, 0}, dir = {0, 1, 0}, length = 0.5, color = {100, 100, 255, 255})

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
		mouse_set_locked(false)

		mouse_reset_input()
		freecam_reset_input()
		return
	}

	mouse_set_locked(true)
	
	mouse_update_input_event(ev)
	freecam_update_input_event(ev)
}

compute_mvp :: proc(
	fovy_degrees: f32,
) -> matrix[4, 4]f32 {
	proj := linalg.matrix4_perspective_f32(
		fovy = math.to_radians_f32(fovy_degrees),
		aspect = viewport_get_aspect(),
		near = 0.01,
		far = 100,
	)

	view := linalg.matrix4_look_at_f32(
		eye = {0.0, 1.5, 6.0},
		centre = {0, 0, 0},
		up = {0.0, 1.0, 0.0},
	)

	view_proj := proj * view

	return view_proj
}

game_quit :: proc() {
	sapp.quit()
}