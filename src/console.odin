package game
import sapp "sokol/app"
import "core:fmt"
import ui "ui"
import uie "ui_extra"

Console_Command :: struct {
	description: string,
	proc_call:   proc(args: []string),
}

Console :: struct {
	open                : bool,
	input_buffer        : [dynamic]u8,
	history             : [dynamic]string,
	commands            : map[string]Console_Command,
	selected_suggestion : int,
}

console_init :: proc(console : ^Console) {
   console^ = {
      input_buffer = make([dynamic]u8, 0, 20),
      history      = make([dynamic]string, 0, 20),
   }
}

console_update_event :: proc(console : ^Console, ev : sapp.Event) {
   if ev.type == .KEY_DOWN && ev.key_code == .GRAVE_ACCENT {
      console.open = !console.open 
   }  
}

console_update_ui :: proc(console : ^Console, dt : f32) {
   BASE_Z_INDEX :: 100
   
   if ui.layout(
      width      = ui.grow(),
      height     = ui.fixed(200), 
      float_mode = ui.Float_At_Root{
         attach_points = {
            element = .LeftTop,
            parent  = .LeftTop,
         },
         z_index = BASE_Z_INDEX+0,
      },
   ) {
      if _, commited := uie.text_box(
         &console.input_buffer,
         &console.open,
         width       = ui.grow(),
         font_index  = 1,
      ); commited {
         console_match_and_run_cmd(string(console.input_buffer[:]))
      }

   }

   // fps counter
   if ui.layout(
      width      = ui.fixed(100),
      height     = ui.fixed(32),
      float_mode = ui.Float_At_Root{
         attach_points = {
            element    = .RightTop,
            parent     = .RightTop
         },
         z_index       = BASE_Z_INDEX+1,
      },
      padding          = ui.pad_all(8),
      background_color = uie.hsva_to_rgba({0, 0, 0.5, 0.5})
   ) {
      ui.text(
         fmt.tprintf("FPS:% 4.f", g_state.frame_time.average_fps),
         font_index = 1,
         alignment  = {.Center, .Center},
      )
   }
}

console_destroy :: proc(console : ^Console) {
   delete(console.input_buffer)
}


@(private = "file")
console_match_and_run_cmd :: proc(raw_cmd : string){
   
}