package game

import "core:fmt"
import ui "ui"
import uie "ui_extra"
import uis "ui_sokol"
import sapp "sokol/app"

FONT_INDEX_DEFAULT :: 0 
FONT_INDEX_MONO    :: 1 

Game_UI :: struct {
   ctx      : ui.Context,
   renderer : uis.Renderer,
   show_fps : bool,
}

ui_init :: proc() {
   game_ui := &g_state.ui
   
   uis.init(&game_ui.renderer) 
   
   fonts := uis.make_fonts(
      &g_state.ui.renderer,
      {
         FONT_INDEX_DEFAULT = {
            ttf       = #load("../assets/fonts/NotoSans_SemiCondensed-SemiBold.ttf"),
            base_size = 16,
         },
         FONT_INDEX_MONO    = {
            ttf       = #load("../assets/fonts/NotoSans_Mono.ttf"),
            base_size = 16,
         }
      },
   )
   defer delete(fonts)

   ui.init(&game_ui.ctx, 
      fonts         = fonts,
      entry_dir     = g_state.entry_dir,
      get_clipboard = uis.sokol_get_clipboard,
      set_clipboard = uis.sokol_set_clipboard,
   )
}

ui_update_input_event :: proc(ev : sapp.Event) {
   game_ui := &g_state.ui

   uis.handle_event(&g_state.ui.ctx.input, ev,
		screen_to_ui = proc(pos: [2]f32) -> [2]f32 {
			return viewport_screen_to_virtual(pos)
		},
	)
}

ui_is_capturing_input :: proc() -> bool {
   return ui.is_keyboard_captured() || ui.is_pointer_captured()
}

@(require_results, deferred_none = ui_end_draw)
ui_draw :: proc() -> bool {
   game_ui  := &g_state.ui
   viewport := &g_state.viewport
   
   if ui.begin_no_defer(&game_ui.ctx, viewport.base_size) && game_ui.show_fps {
      
   }

   return true
}

@(private = "file")
ui_end_draw :: proc() {
   game_ui  := &g_state.ui
   viewport := &g_state.viewport
   
   // draw fps counter
   if game_ui.show_fps {
      if ui.layout(
         id         = ui.global_id("fps_counter"),
         width      = ui.fixed(100),
         height     = ui.fixed(32),
         float_mode = ui.Float_At_Root{
            attach_points = {
               element    = .RightTop,
               parent     = .RightTop
            },
            z_index       = 100,
         },
         padding          = ui.pad_all(8),
         background_color = uie.hsva_to_rgba({140, 0, 0.5, 0.5})
      ) {
         ui.text(
            fmt.tprintf("FPS:% 4.f", g_state.frame_time.average_fps),
            font_index = 1,
            alignment  = {.Center, .Center},
         )
      }
   }

   vmouse := viewport_get_mouse_position()
   if ui.layout(
      id         = ui.global_id("virtual_cursor"),
      width      = ui.fixed(8),
      height     = ui.fixed(8),
      float_mode = ui.Float_At_Root{
         attach_points = {.CenterCenter, .LeftTop},
         offset        = vmouse,
         z_index       = 1000,
      },
      background_color = {255, 255, 255, 255},
      corner_radius    = ui.corner_radius_all(4),
      border           = {thickness = 1, color = {0, 0, 0, 255}},
      pointer_mode     = .Ignore,
   ) {}

   ui.end(&game_ui.ctx, {})

   uis.render(
      &game_ui.renderer,
      &game_ui.ctx,
      viewport.base_size,
      cast(ui.Rect)viewport.dest_rect,
      viewport.scale,
   )
}

ui_destroy :: proc() {
   game_ui  := &g_state.ui

   uis.destroy(&game_ui.renderer)
   uie.destroy()
   ui .destroy(game_ui.ctx)
}

ui_clear_input :: proc() {
   clear(&g_state.ui.ctx.input.keyboard.characters)
}