package game

import ui "ui"
import uie "ui_extra"
import uis "ui_sokol"
import sapp "sokol/app"

FONT_INDEX_DEFAULT :: 0 
FONT_INDEX_MONO    :: 1 

Game_UI :: struct {
   ctx      : ui.Context,
   renderer : uis.Renderer,
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

@(require_results, deferred_none = ui_end_draw)
ui_draw :: proc() -> bool {
   game_ui  := &g_state.ui
   viewport := &g_state.viewport
   
   return ui.begin_no_defer(&game_ui.ctx, viewport.base_size)
}

@(private = "file")
ui_end_draw :: proc() {
   game_ui  := &g_state.ui
   viewport := &g_state.viewport
   
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