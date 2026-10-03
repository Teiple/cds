package game
import sapp "sokol/app"
import "core:strings"
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

console_init :: proc() {
   g_state.console = {
      input_buffer = make([dynamic]u8, 0, 20),
      history      = make([dynamic]string, 0, 20),
   }
}

console_update_input_event :: proc(ev : sapp.Event) {
   console := &g_state.console

   if ev.type == .KEY_DOWN && ev.key_code == .GRAVE_ACCENT {
      console.open = !console.open 
   }  
}


console_update_ui :: proc() {   
   console := &g_state.console
   
   if !console.open do return
   
   // command panel
   if ui.layout(
      width      = ui.grow(),
      height     = ui.fixed(200), 
      float_mode = ui.Float_At_Root{
         attach_points = {
            element = .LeftTop,
            parent  = .LeftTop,
         },
      },
   ) {
      // command text box
      if _, commited := uie.text_box(
         &console.input_buffer,
         &console.open,
         width       = ui.grow(),
         font_index  = 1,
      ); commited {
         console_match_and_run_cmd(string(console.input_buffer[:]))
         clear(&console.input_buffer)
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

console_destroy :: proc() {
   delete(g_state.console.input_buffer)
}

@(private = "file")
console_match_and_run_cmd :: proc(raw_cmd : string){
   tokens := strings.split(raw_cmd, " ")
   defer delete(tokens)

   if len(tokens) == 0 do return

   cmd := tokens[0]

   switch cmd {
      case "quit":
         game_quit()
   }
}