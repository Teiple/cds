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

ui_init :: proc(game_ui: ^Game_UI, entry_dir: string) {
   uis.init(&game_ui.renderer) 
   
   fonts := uis.make_fonts(
      &game_ui.renderer,
      {
         FONT_INDEX_DEFAULT = {
            ttf       = #load("../assets/fonts/NotoSans_SemiCondensed-SemiBold.ttf"),
            base_size = 16,
         },
         FONT_INDEX_MONO    = {
            ttf       = #load("../assets/fonts/NotoSans_Mono.ttf"),
            base_size = 16,
         },
      },
   )
   defer delete(fonts)

   ui.init(&game_ui.ctx, 
      fonts         = fonts,
      entry_dir     = entry_dir,
      get_clipboard = uis.sokol_get_clipboard,
      set_clipboard = uis.sokol_set_clipboard,
   )
}

ui_update_input_event :: proc(game_ui: ^Game_UI, vp: ^Viewport, ev: sapp.Event) {
   uis.handle_event(&game_ui.ctx.input, ev,
		screen_to_ui = proc(pos: [2]f32) -> [2]f32 {
			return viewport_screen_to_virtual(&g_state.viewport, pos)
		},
	)
}

ui_is_capturing_input :: proc() -> bool {
   return ui.is_keyboard_captured() || ui.is_pointer_captured()
}

ui_begin :: proc(game_ui: ^Game_UI, vp: ^Viewport) -> bool {
   return ui.begin_no_defer(&game_ui.ctx, vp.base_size)
}

ui_end :: proc(game_ui: ^Game_UI, vp: ^Viewport, avg_fps: f32) {
   if game_ui.show_fps {
      if ui.layout(
         id         = ui.global_id("fps_counter"),
         width      = ui.fixed(100),
         height     = ui.fixed(32),
         float_mode = ui.Float_At_Root{
            attach_points = {
               element    = .RightTop,
               parent     = .RightTop,
            },
            z_index       = 100,
         },
         padding          = ui.pad_all(8),
         background_color = uie.hsva_to_rgba({140, 0, 0.5, 0.5}),
      ) {
         ui.text(
            fmt.tprintf("FPS:% 4.f", avg_fps),
            font_index = 1,
            alignment  = {.Center, .Center},
         )
      }
   }

   vmouse := viewport_get_mouse_position(vp)

   ui.end(&game_ui.ctx, {})

   uis.render(
      &game_ui.renderer,
      &game_ui.ctx,
      vp.base_size,
      cast(ui.Rect)vp.dest_rect,
      vp.scale,
   )
}

ui_destroy :: proc(game_ui: ^Game_UI) {
   uis.destroy(&game_ui.renderer)
   uie.destroy()
   ui.destroy(game_ui.ctx)
}

ui_clear_input :: proc(game_ui: ^Game_UI) {
   clear(&game_ui.ctx.input.keyboard.characters)
}