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
	proc_call   : proc(console: ^Console, args: []string),
}

Console :: struct {
	open                : bool,
	open_next_frame     : bool,
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

console_log :: proc(console: ^Console, msg: string) {
   append(&console.history, strings.clone(msg))
   console.scroll_to_bottom = true
}

console_logf :: proc(console: ^Console, format: string, args: ..any) {
   console_log(console, fmt.tprintf(format, ..args))
}

CONSOLE_COMMANDS :: [?]Console_Command {
   {
      name        = "exit",
      description = "Exit program",
      proc_call   = proc(console: ^Console, args: []string) {
         game_quit()
      }
   },
   {
      name        = "close",
      description = "Close console",
      proc_call   = proc(console: ^Console, args: []string) {
         console_close(console)
      }
   },
   {
      name        = "show_fps",
      description = "Show fps: 0 or 1",
      proc_call   = proc(console: ^Console, args: []string) {
         if len(args) < 1 {
            console_log(console, "Wrong usage!")
            return
         }
         
         game_ui := &g_state.ui
         game_ui.show_fps = args[0] != "0"
         
         console_logf(console, "FPS display %s.", game_ui.show_fps ? "enabled" : "disabled")
      }
   },
   {
      name        = "freecam",
      description = "Override camera motion: 0 or 1",
      proc_call   = proc(console: ^Console, args: []string) {
         if len(args) < 1 {
            console_log(console, "Wrong usage!")
            return
         }

         s, ok := scene_state(Scene_State_Gameplay)
         if !ok {
            console_log(console, "Only available in gameplay!")
            return
         }

         enabled := args[0] != "0"
         freecam_set_enabled(&s.freecam, &s.camera, &s.follow_cam, enabled)
         
         console_logf(console, "Freecam %s.", enabled ? "enabled" : "disabled")
      }
   },
   {
      name        = "clear",
      description = "Clear console output",
      proc_call   = proc(console: ^Console, args: []string) {
         for cmd in console.history {
            delete(cmd)
         }
         clear(&console.history)
      }
   },
}

console_init :: proc(console: ^Console) {
   console^ = {
      history_index     = -1,
      saved_input       = make([dynamic]u8, 0, 20),
      input_buffer      = make([dynamic]u8, 0, 20),
      history           = make([dynamic]string, 0, 20),
      nav_history       = make([dynamic]string, 0, 20),
      suggestions       = make([dynamic]Console_Command, 0, 4),
   }
}

console_update_input_event :: proc(console: ^Console, ev : sapp.Event) {
   if ev.type == .KEY_DOWN && ev.key_code == .GRAVE_ACCENT {
      if !console.open {
         console.open_next_frame   = true
      } else {
         console.open = false
      }
   }
}

console_update_ui :: proc(console: ^Console) {   
   if !console.open {
      if console.open_next_frame {
         console.open            = true
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
         background_color = uie.hsva_to_rgba({140, 0.5, 0.5, 0.8}),
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
            background_color = uie.hsva_to_rgba({0, 0, 0, 0.6}),
            corner_radius    = ui.corner_radius_all(2), 
            padding          = ui.pad_all(2),
            layout_direction = .Top_To_Bottom,
            child_alignment  = {.Left, .Bottom},
            clip             = true,
            scroll           = true,
         ) {
            for cmd_content in console.history {
               if ui.layout() {
                  is_cmd := strings.starts_with(cmd_content, "cmd:")
                  ui.text(
                     is_cmd ? cmd_content[4:] : cmd_content,
                     font_index = FONT_INDEX_MONO,
                     color = is_cmd ? uie.hsv_to_rgb({200, 0.5, 1}) : uie.hsv_to_rgb({0, 0, 1})
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
            console_fetch_suggestions(console, typing_cmd, show_all_when_empty = true)
         }

         cmd_content := string(console.input_buffer[:])
         if changed {
            console.history_index = -1
            if len(typing_cmd) > 0 {
               console_fetch_suggestions(console, typing_cmd)
            } else {
               clear(&console.suggestions)
            }
         }

         if commited && len(cmd_content) > 0 {
            if len(console.nav_history) == 0 || console.nav_history[len(console.nav_history) - 1] != cmd_content {
               append(&console.nav_history, strings.clone(cmd_content))
            }
            
            console_match_and_run_cmd(console, cmd_content)
            
            clear(&console.input_buffer)
            clear(&console.suggestions)
            console.history_index = -1
            clear(&console.saved_input)

            console.scroll_to_bottom = true
         }
      }
   }
   
   
}

console_destroy :: proc(console: ^Console) {
   delete(console.saved_input)
   delete(console.input_buffer)
   for cmd_content in console.history {
      delete(cmd_content)
   } 
   delete(console.history)
   for cmd_content in console.nav_history {
      delete(cmd_content)
   }
   delete(console.nav_history)
   delete(console.suggestions)
}

@(private = "file")
console_match_and_run_cmd :: proc(console: ^Console, cmd_content : string) {
   assert(len(cmd_content) > 0)
   
   tokens := strings.fields(cmd_content)
   defer delete(tokens)

   if len(tokens) == 0 do return

   command := tokens[0]
   args    := tokens[1:]
         
   for cmd in CONSOLE_COMMANDS {
      if command == cmd.name {
         append(&console.history, strings.concatenate({"cmd:", cmd_content}))
         cmd.proc_call(console, args)
         return
      } 
   }

   append(&console.history, strings.clone(cmd_content))
   console_log(console, "Unknown command!")
}

@(private = "file")
console_fetch_suggestions :: proc(console: ^Console, prefix : string, show_all_when_empty : bool = false) {
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

console_close :: proc(console : ^Console) {
   console.open = false
}