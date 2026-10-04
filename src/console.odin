package game
import sapp "sokol/app"
import "core:strings"
import "core:math"
import "core:fmt"
import "core:slice"
import ui "ui"
import uie "ui_extra"

Console_Command :: struct {
   name        : string,
	description : string,
	proc_call   : proc(args: []string),
}

Console :: struct {
	open                : bool,
	open_next_frame     : bool,
   edit_mode           : bool,
   scroll_to_bottom    : bool,
   history_index       : int,
   saved_input         : [dynamic]u8,
	input_buffer        : [dynamic]u8,
	history             : [dynamic]string,
   nav_history         : [dynamic]string,
   suggestions         : [dynamic]Console_Command,
	commands            : map[string]Console_Command,
	selected_suggestion : int,
}

CONSOLE_COMMANDS :: [?]Console_Command {
   {
      name        = "quit",
      description = "Exit program",
      proc_call   = proc(args : []string) {
         game_quit()
      }
   },
   {
      name        = "show_fps",
      description = "Show fps: 0 or 1",
      proc_call   = proc(args : []string) {
         if len(args) < 1 do return
         
         game_ui := &g_state.ui
         game_ui.show_fps = args[0] != "0"
      }
   },
   {
      name        = "freecam",
      description = "Override camera motion",
      proc_call   = proc(args : []string) {
         if len(args) < 1 do return

         freecam_set_enabled(args[0] != "0")
      }
   },
   {
      name        = "clear",
      description = "Clear console output",
      proc_call   = proc(args : []string) {
         for cmd in g_state.console.history {
            delete(cmd)
         }
         clear(&g_state.console.history)
      }
   },
}

console_init :: proc() {
   g_state.console = {
      history_index     = -1,
      saved_input       = make([dynamic]u8, 0, 20),
      input_buffer      = make([dynamic]u8, 0, 20),
      history           = make([dynamic]string, 0, 20),
      nav_history       = make([dynamic]string, 0, 20),
      suggestions       = make([dynamic]Console_Command, 0, 4),
   }
}

console_update_input_event :: proc(ev : sapp.Event) {
   console := &g_state.console
   
   if ev.type == .KEY_DOWN && ev.key_code == .GRAVE_ACCENT {
      if !console.open {
         console.open_next_frame   = true
      } else {
         console.open = false
      }
      
      console.edit_mode = console.open
   }
}

console_update_ui :: proc() {   
   console := &g_state.console
   
   if !console.open {
      if console.open_next_frame {
         console.open            = true
         console.edit_mode       = true
         console.open_next_frame = false
      }
      return
   }

   ui.push_focus_scope()
   defer ui.pop_focus_scope()

   if ui.layout(
      id     = ui.global_id("console_panel"),
      width  = ui.grow(),
      height = ui.grow(),
   )
   {
      // command panel
      if ui.layout(
         width      = ui.grow(),
         height     = ui.fixed(200), 
         float_mode = ui.Float_At_Root{},
         padding          = ui.pad_all(4), 
         background_color = uie.hsva_to_rgba({140, 0.5, 0.5, 0.5}),
         layout_direction = .Top_To_Bottom,
      ) {
         cmd_history_id := ui.local_id("command_history")
         
         // auto scroll to latest commands
         if console.scroll_to_bottom {
            scroll_data := ui.scroll_data_by_id(cmd_history_id)
            ui.set_scroll_offset_by_id(cmd_history_id, {0, math.inf_f32(-1)})
            
            console.scroll_to_bottom = false
         }
         
         // command history
         if ui.layout(
            id               = cmd_history_id,
            width            = ui.grow(),
            height           = ui.grow(),
            background_color = uie.hsva_to_rgba({0, 0, 0, 0.5}),
            corner_radius    = ui.corner_radius_all(2), 
            padding          = ui.pad_all(2),
            layout_direction = .Top_To_Bottom,
            child_alignment  = {.Left, .Bottom},
            clip             = true,
            scroll           = true,
         ) {
            for cmd_content in console.history {
               if ui.layout() {
                  ui.text(
                     cmd_content,
                     font_index = FONT_INDEX_MONO,
                     color = uie.hsv_to_rgb({0, 0, 1})
                  )
               }
            }
         }

         had_suggestions := len(console.suggestions) > 0
         
         if had_suggestions {
            if ui.is_key_pressed(.Escape) {
               clear(&console.suggestions)
            }
            if ui.is_key_pressed(.Down) {
               console.selected_suggestion = (console.selected_suggestion + 1) % len(console.suggestions)
            }
            if ui.is_key_pressed(.Up) {
               console.selected_suggestion = (console.selected_suggestion - 1 + len(console.suggestions)) % len(console.suggestions)
            }
            if ui.is_key_pressed(.Tab) || ui.is_key_pressed(.Enter) {
               assert(console.selected_suggestion >= 0 && console.selected_suggestion < len(console.suggestions))

               selected_cmd := console.suggestions[console.selected_suggestion]
               
               clear(&console.input_buffer)
               
               append(&console.input_buffer, ..transmute([]u8)selected_cmd.name)
               
               uie.text_box_set_text(string(console.input_buffer[:]))
               
               clear(&console.suggestions)
               
               console.selected_suggestion = 0
            }

            // command suggestion
            if ui.layout(
               width            = ui.grow(),
               height           = ui.grow(),
               corner_radius    = ui.corner_radius_all(2), 
               layout_direction = .Top_To_Bottom,
               child_alignment  = {.Left, .Bottom},
               float_mode       = ui.Float_At_Id{attach_id = cmd_history_id},
               clip             = true,
               scroll           = true,
               background_color = uie.hsva_to_rgba({0, 0, 0, 0.5}),
            ) {
               for cmd, i in console.suggestions {
                  is_selected := i == console.selected_suggestion
                  bg_color := is_selected ? uie.hsva_to_rgba({140, 0.5, 0.5, 1.0}) : {}
                  if ui.layout(
                     width            = ui.grow(),
                     height           = ui.fit(),
                     background_color = bg_color,
                     corner_radius    = ui.corner_radius_all(2),
                     padding          = ui.pad_all(2),
                  ) {
                     ui.text(
                        fmt.tprintf("%s - %s", cmd.name, cmd.description),
                        font_index = FONT_INDEX_MONO,
                        color = uie.hsv_to_rgb({0, 0, 1}),
                     )
                  }
               }
            }
         }

         if !had_suggestions && len(console.nav_history) > 0 {
            if ui.is_key_pressed(.Up) {
               current_text := uie.text_box_get_text()
               if console.history_index == -1 {
                  clear(&console.saved_input)
                  append(&console.saved_input, ..transmute([]u8)current_text)
                  console.history_index = len(console.nav_history) - 1
               } else if console.history_index > 0 {
                  delete(console.nav_history[console.history_index])
                  console.nav_history[console.history_index] = strings.clone(current_text)
                  console.history_index -= 1
               } else if console.history_index == 0 {
                  delete(console.nav_history[0])
                  console.nav_history[0] = strings.clone(current_text)
               }
               uie.text_box_set_text(console.nav_history[console.history_index])
            }
            if ui.is_key_pressed(.Down) && console.history_index != -1 {
               current_text := uie.text_box_get_text()
               delete(console.nav_history[console.history_index])
               console.nav_history[console.history_index] = strings.clone(current_text)
               console.history_index += 1
               if console.history_index >= len(console.nav_history) {
                  console.history_index = -1
                  uie.text_box_set_text(string(console.saved_input[:]))
               } else {
                  uie.text_box_set_text(console.nav_history[console.history_index])
               }
            }
         }
         
         // command text box 
         // note: as long as console is open the cmd box is always in edit mode
         edit_mode := true
         typing_cmd : string

         changed, commited := uie.text_box(
            &console.input_buffer,
            &edit_mode,
            width          = ui.grow(),
            font_index     = FONT_INDEX_MONO,
            typing_content = &typing_cmd,
            use_tab        = true,
            use_enter      = had_suggestions,
         )

         if ui.has_modifier(.Ctrl) && ui.is_key_pressed(.Space) {
            console_fetch_suggestions(typing_cmd, show_all_when_empty = true)
         }

         cmd_content := string(console.input_buffer[:])
         if changed {
            console.history_index = -1
            if len(typing_cmd) > 0 {
               console_fetch_suggestions(typing_cmd)
            } else {
               clear(&console.suggestions)
            }
         }

         if commited && len(cmd_content) > 0 {
            append(&console.history, strings.clone(cmd_content))

            if len(console.nav_history) == 0 || console.nav_history[len(console.nav_history) - 1] != cmd_content {
               append(&console.nav_history, strings.clone(cmd_content))
            }

            console_match_and_run_cmd(cmd_content)
            
            clear(&console.input_buffer)
            clear(&console.suggestions)
            console.history_index = -1
            clear(&console.saved_input)

            console.scroll_to_bottom = true
         }
      }
   }
   
   
}

console_destroy :: proc() {
   delete(g_state.console.saved_input)
   delete(g_state.console.input_buffer)
   for cmd_content in g_state.console.history {
      delete(cmd_content)
   } 
   delete(g_state.console.history)
   for cmd_content in g_state.console.nav_history {
      delete(cmd_content)
   }
   delete(g_state.console.nav_history)
   delete(g_state.console.suggestions)
}

@(private = "file")
console_match_and_run_cmd :: proc(cmd_content : string) {
   assert(len(cmd_content) > 0)
   
   tokens := strings.fields(cmd_content)
   defer delete(tokens)

   if len(tokens) == 0 do return

   command := tokens[0]
   args    := tokens[1:]
         
   for cmd in CONSOLE_COMMANDS {
      if command == cmd.name {
         cmd.proc_call(args)
         return
      } 
   }
}

@(private = "file")
console_fetch_suggestions :: proc(prefix : string, show_all_when_empty : bool = false) {
   console := &g_state.console
   
   clear(&console.suggestions)
   console.selected_suggestion = 0

   show_all := len(prefix) == 0 && show_all_when_empty
   for cmd in CONSOLE_COMMANDS {
		if show_all || strings.has_prefix(cmd.name, prefix) {
			append(&console.suggestions, cmd)
		}
	}

   slice.sort_by(console.suggestions[:], proc(i, j: Console_Command) -> bool {
      return i.name < j.name
   })
}
