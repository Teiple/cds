package game

import "core:fmt"
import "core:math"
import "core:strings"
import "ui"
import uie "ui_extra"

Demo_Tab :: enum {
	Controls,
	Containers,
	Pickers,
	Dialogs,
	Inspector,
	Stress_Test,
}

Difficulty :: enum {
	Easy,
	Normal,
	Hard,
}

Combo_Option :: enum {
	Option_A,
	Option_B,
	Option_C,
}

Quality_Level :: enum {
	High   = 200,
	Medium = -50,
	Low    = 0,
}

Transform_Mode :: enum {
	Translate,
	Rotate,
	Scale,
}

Ui_Demo_State :: struct {
	active_tab:              Demo_Tab,
	btn_click_count:         int,
	toggle_val:              bool,
	group_val:               Difficulty,
	slider_toggle:           int,
	check_val:               bool,
	slider_val:              f32,
	slider_bar_val:          f32,
	active_list_item:        i32,
	win_closed:              bool,
	text_buf:                [dynamic]u8,
	text_edit:               bool,
	pass_buf:                [dynamic]u8,
	pass_edit:               bool,
	multi_buf:               [dynamic]u8,
	multi_edit:              bool,
	spin_val:                i32,
	spin_edit:               bool,
	spin_fval:               f32,
	spin_fedit:              bool,
	val_box:                 int,
	val_box_edit:            bool,
	active_combo:            Combo_Option,
	drop_idx:                Quality_Level,
	drop_edit:               bool,
	picked_col:              [4]u8,
	show_msg_box:            bool,
	msg_result_text:         string,
	show_input_box:          bool,
	input_result_buf:        [128]u8,
	input_result_len:        int,
	dialog_buf:              [dynamic]u8,
	dialog_edit:             bool,
	grid_cell:               [2]int,
	inspector_name:          [dynamic]u8,
	inspector_name_edit:     bool,
	inspector_pos:           [3]f32,
	inspector_pos_edit:      [3]bool,
	inspector_rot:           f32,
	inspector_rot_edit:      bool,
	inspector_col:           [4]u8,
	inspector_mode:          Transform_Mode,
	inspector_wire:          bool,
	inspector_mesh:          Combo_Option,
	inspector_hierarchy_idx: i32,
	stress_item_count:       int,
	stress_grid_cell:        [2]int,
}

ui_demo_init :: proc(state: ^Ui_Demo_State) {
	state.active_tab = .Controls
	state.group_val = .Easy
	state.slider_toggle = 0
	state.check_val = true
	state.slider_val = 45.0
	state.slider_bar_val = 60.0
	state.active_list_item = 0
	state.spin_val = 5
	state.spin_fval = 1.5
	state.val_box = 42
	state.active_combo = .Option_A
	state.drop_idx = .Low
	state.picked_col = {200, 80, 50, 255}
	state.msg_result_text = "None"
	state.grid_cell = {-1, -1}
	state.inspector_pos = {0.0, 1.0, 0.0}
	state.inspector_rot = 45.0
	state.inspector_col = {60, 160, 240, 255}
	state.inspector_mode = .Translate
	state.inspector_mesh = .Option_A
	state.stress_item_count = 100
	state.stress_grid_cell = {-1, -1}

	state.text_buf = make([dynamic]u8, 0, 64)
	init_str := "Hello Sokol UI"
	append(&state.text_buf, ..transmute([]u8)init_str)

	state.pass_buf = make([dynamic]u8, 0, 64)
	init_pass := "secret123"
	append(&state.pass_buf, ..transmute([]u8)init_pass)

	state.multi_buf = make([dynamic]u8, 0, 256)
	init_multi := "Line 1: Multi-line text box\nLine 2: Supports editing\nLine 3: Scrollable content\nLine 4: Up/Down arrow nav\nLine 5: Multiple lines demo"
	append(&state.multi_buf, ..transmute([]u8)init_multi)

	state.dialog_buf = make([dynamic]u8, 0, 64)
	init_d := "secretpass"
	append(&state.dialog_buf, ..transmute([]u8)init_d)

	state.inspector_name = make([dynamic]u8, 0, 64)
	init_obj_name := "Main Character Mesh"
	append(&state.inspector_name, ..transmute([]u8)init_obj_name)
}

ui_demo_destroy :: proc(state: ^Ui_Demo_State) {
	delete(state.text_buf)
	delete(state.pass_buf)
	delete(state.multi_buf)
	delete(state.dialog_buf)
	delete(state.inspector_name)
}

ui_demo_update :: proc(state: ^Ui_Demo_State, dt: f32) {
	if ui.layout(
		width = ui.fit(),
		height = ui.fit(),
		padding = {8, 8, 4, 4},
		background_color = {20, 20, 25, 200},
		border = {thickness = 1, color = {60, 60, 70, 255}},
		corner_radius = ui.corner_radius_all(4),
		float_mode = ui.Float_At_Root {
			offset = {-12, 12},
			attach_points = {element = .RightTop, parent = .RightTop},
			z_index = 1000,
		},
	) {
		fps_text := fmt.tprintf(
			"FPS: %.0f (%.2f ms)",
			g_state.frame_time.average_fps,
			dt * 1000.0,
		)
		ui.text(
			fps_text,
			color = {100, 240, 120, 255},
			font_size = 14,
			font_index = 0,
		)
	}

	if uie.panel(
		width = ui.grow(),
		height = ui.grow(),
		padding = ui.pad_all(12),
		gap = 10,
	) {
		tabs := [Demo_Tab]string {
			.Controls    = "Controls",
			.Containers  = "Containers",
			.Pickers     = "Pickers",
			.Dialogs     = "Dialogs & Grid",
			.Inspector   = "Game Inspector",
			.Stress_Test = "Stress Test",
		}

		uie.tab_bar(
			tabs = tabs,
			active_tab = &state.active_tab,
			width = ui.grow(),
			height = ui.fixed(30),
		)

		switch state.active_tab {
		case .Controls:
			if uie.vbox(gap = 8) {
				btn_id := ui.local_id("demo_btn")
				btn_text := fmt.tprintf(
					"Clicked %d times",
					state.btn_click_count,
				)
				if uie.button(btn_text, id = btn_id, width = ui.fixed(160)) {
					state.btn_click_count += 1
				}
				uie.tooltip(btn_id, "Click me to increment counter")

				if uie.label_button("Label Button (Reset)") {
					state.btn_click_count = 0
				}

				uie.toggle(
					"Toggle Button",
					&state.toggle_val,
					width = ui.fixed(140),
				)

				uie.toggle_group(
					options = [Difficulty]string {
						.Easy = "Easy",
						.Normal = "Normal",
						.Hard = "Hard",
					},
					active_option = &state.group_val,
					width = ui.fixed(240),
				)

				uie.toggle_slider(
					options = []string{"Low", "Mid", "High"},
					active = &state.slider_toggle,
					width = ui.fixed(240),
				)

				uie.checkbox("Enable Shadows", &state.check_val)

				uie.slider_h(
					value = &state.slider_val,
					min_val = 0,
					max_val = 100,
					step = 0.01,
					width = ui.fixed(240),
				)

				uie.progress_bar(
					state.slider_val,
					0,
					100,
					width = ui.fixed(240),
				)

				uie.list_view(
					items = {
						"Item 01: Character Controller",
						"Item 02: Physics Rigidbody",
						"Item 03: Box Collider",
						"Item 04: Mesh Renderer",
						"Item 05: Audio Source",
						"Item 06: Particle Emitter",
						"Item 07: Animation Player",
						"Item 08: Script Component",
					},
					active = &state.active_list_item,
					width = ui.fixed(240),
					height = ui.fixed(110),
				)
			}

		case .Containers:
			if uie.vbox(gap = 8) {
				if uie.group_box(
					"Audio Settings Group",
					width = ui.fixed(320),
				) {
					uie.label("Master Volume")
					uie.line()
					uie.label("Sound Effects Volume")
				}

				if !state.win_closed {
					if uie.window_box(
						"Window Dialog Box",
						&state.win_closed,
						width = ui.fixed(320),
					) {
						uie.label("Window content container")
						uie.line("Section Header")
						uie.label("Additional inner content")
					}
				}

				uie.dummy_rec(
					"Placeholder Dummy Rectangle",
					width = ui.fixed(320),
					height = ui.fixed(40),
				)

				uie.status_bar("Ready - Sokol Odin UI Showcase Engine")
			}

		case .Pickers:
			if uie.vbox(gap = 8) {
				uie.label("Single Line Text Input:")
				uie.text_box(
					&state.text_buf,
					&state.text_edit,
					width = ui.fixed(220),
				)

				uie.label("Password Masked Input:")
				uie.text_box(
					&state.pass_buf,
					&state.pass_edit,
					password = true,
					width = ui.fixed(220),
				)

				uie.label("Multi-Line Text Area:")
				uie.text_box_multi(
					&state.multi_buf,
					&state.multi_edit,
					width = ui.fixed(240),
					height = ui.fixed(70),
				)

				if uie.hbox(gap = 8) {
					uie.spinner(
						value = &state.spin_val,
						min_val = 0,
						max_val = 20,
						step = 1,
						drag_speed = 1,
						edit_mode = &state.spin_edit,
						width = ui.fixed(110),
					)

					uie.spinner(
						value = &state.spin_fval,
						min_val = 0,
						max_val = 10,
						edit_mode = &state.spin_fedit,
						step = 0.01,
						drag_speed = 0.05,
						precision = 2,
						width = ui.fixed(110),
					)
				}

				uie.value_box(
					&state.val_box,
					0,
					100,
					&state.val_box_edit,
					width = ui.fixed(120),
				)

				uie.combo_box(
					options = [Combo_Option]string {
						.Option_A = "Option Alpha",
						.Option_B = "Option Beta",
						.Option_C = "Option Gamma",
					},
					active_option = &state.active_combo,
					width = ui.fixed(180),
				)

				uie.dropdown_box(
					#sparse[Quality_Level]string{
						.High = "High Quality",
						.Medium = "Medium Quality",
						.Low = "Low Quality",
					},
					&state.drop_idx,
					&state.drop_edit,
					width = ui.fixed(180),
				)

				uie.color_picker(
					&state.picked_col,
					panel_size = 90,
					show_alpha = true,
				)
			}

		case .Dialogs:
			if uie.vbox(gap = 10) {
				if uie.button(
					"Open Confirmation Modal",
					width = ui.fixed(220),
				) {
					state.show_msg_box = true
				}

				res := uie.message_box(
					&state.show_msg_box,
					title = "Confirm Action",
					message = "Do you want to save project changes before exiting?",
					buttons = []string{"Save", "Discard", "Cancel"},
				)
				if res >= 0 {
					switch res {
					case 0:
						state.msg_result_text = "Closed / Dismissed"
					case 1:
						state.msg_result_text = "Clicked: Save"
					case 2:
						state.msg_result_text = "Clicked: Discard"
					case 3:
						state.msg_result_text = "Clicked: Cancel"
					}
				}

				uie.label(
					fmt.tprintf(
						"Message box result: %s",
						state.msg_result_text,
					),
				)

				uie.line()

				if uie.button(
					"Open Password Prompt Modal",
					width = ui.fixed(220),
				) {
					state.show_input_box = true
					state.dialog_edit = true
				}

				input_res := uie.text_input_box(
					&state.show_input_box,
					title = "Authentication Required",
					message = "Please enter your secret access key:",
					text_buffer = &state.dialog_buf,
					edit_mode = &state.dialog_edit,
					buttons = []string{"Authenticate", "Cancel"},
					password = true,
				)
				if input_res >= 0 {
					if input_res == 1 {
						str := fmt.bprintf(
							state.input_result_buf[:],
							"Authenticated with: %s",
							string(state.dialog_buf[:]),
						)
						state.input_result_len = len(str)
					} else {
						str := fmt.bprintf(
							state.input_result_buf[:],
							"Cancelled",
						)
						state.input_result_len = len(str)
					}
				}

				display_result :=
					state.input_result_len > 0 ? string(state.input_result_buf[:state.input_result_len]) : "None"
				uie.label(
					fmt.tprintf("Input dialog result: %s", display_result),
				)

				uie.line("Interactive Grid")

				_ = uie.grid(
					spacing = 24,
					subdivs = 2,
					mouse_cell = &state.grid_cell,
					width = ui.fixed(320),
					height = ui.fixed(90),
				)
				uie.label(
					fmt.tprintf(
						"Hovered Cell Coordinate: (%d, %d)",
						state.grid_cell.x,
						state.grid_cell.y,
					),
				)
			}

		case .Inspector:
			if uie.vbox(gap = 8) {
				if uie.group_box("Entity Inspector", width = ui.fixed(360)) {
					uie.label("Entity Name:")
					uie.text_box(
						&state.inspector_name,
						&state.inspector_name_edit,
						width = ui.grow(),
					)

					uie.line("Transform")

					if uie.hbox(gap = 6) {
						uie.label("Pos X:")
						uie.spinner(
							&state.inspector_pos.x,
							-100.0,
							100.0,
							&state.inspector_pos_edit[0],
							0.1,
							0.05,
							2,
							width = ui.fixed(70),
						)
						uie.label("Y:")
						uie.spinner(
							&state.inspector_pos.y,
							-100.0,
							100.0,
							&state.inspector_pos_edit[1],
							0.1,
							0.05,
							2,
							width = ui.fixed(70),
						)
						uie.label("Z:")
						uie.spinner(
							&state.inspector_pos.z,
							-100.0,
							100.0,
							&state.inspector_pos_edit[2],
							0.1,
							0.05,
							2,
							width = ui.fixed(70),
						)
					}

					if uie.hbox(gap = 6) {
						uie.label("Rotation:")
						uie.slider_h(
							&state.inspector_rot,
							0.0,
							360.0,
							step = 1.0,
							width = ui.fixed(160),
						)
						uie.spinner(
							&state.inspector_rot,
							0.0,
							360.0,
							&state.inspector_rot_edit,
							1.0,
							0.1,
							1,
							width = ui.fixed(80),
						)
					}

					uie.toggle_group(
						options = [Transform_Mode]string {
							.Translate = "Translate",
							.Rotate = "Rotate",
							.Scale = "Scale",
						},
						active_option = &state.inspector_mode,
						width = ui.grow(),
					)

					uie.line("Material & Shading")

					uie.checkbox("Wireframe Display", &state.inspector_wire)

					uie.combo_box(
						options = [Combo_Option]string {
							.Option_A = "Standard PBR",
							.Option_B = "Unlit Lambert",
							.Option_C = "Toon Outline",
						},
						active_option = &state.inspector_mesh,
						width = ui.grow(),
					)

					if uie.hbox(gap = 8) {
						uie.color_picker(
							&state.inspector_col,
							panel_size = 80,
							show_alpha = true,
						)
						if uie.vbox(gap = 4) {
							uie.label("Hierarchy:")
							uie.list_view(
								items = {
									"Root Node",
									"  -> Mesh_Body",
									"  -> Mesh_Head",
									"  -> Weapon_Attachment",
									"  -> Camera_Mount",
								},
								active = &state.inspector_hierarchy_idx,
								width = ui.fixed(160),
								height = ui.fixed(80),
							)
						}
					}
				}
			}

		case .Stress_Test:
			if uie.vbox(gap = 8) {
				if uie.hbox(gap = 8) {
					uie.label(
						fmt.tprintf(
							"Item Count (%d):",
							state.stress_item_count,
						),
					)
					fval := f32(state.stress_item_count)
					if uie.slider_h(
						&fval,
						10.0,
						500.0,
						step = 10.0,
						width = ui.fixed(200),
					) {
						state.stress_item_count = int(fval)
					}
				}

				if uie.scroll_panel(
					width = ui.grow(),
					height = ui.fixed(260),
				) {
					for i in 0 ..< state.stress_item_count {
						if uie.hbox(gap = 6) {
							btn_label := fmt.tprintf("Button #%03d", i + 1)
							_ = uie.button(
								btn_label,
								width = ui.fixed(100),
								height = ui.fixed(24),
							)

							check := (i % 2 == 0)
							uie.checkbox(
								fmt.tprintf("Option %d", i + 1),
								&check,
							)

							val := f32(i % 100)
							uie.progress_bar(
								val,
								0,
								100,
								width = ui.fixed(120),
								height = ui.fixed(16),
							)

							uie.label(
								fmt.tprintf("Status: OK (%d)", (i * 37) % 997),
							)
						}
					}
				}

				uie.status_bar(
					fmt.tprintf(
						"Stress Test Running: %d Elements Rendered | FPS: %.0f",
						state.stress_item_count * 4,
						g_state.frame_time.average_fps,
					),
				)
			}
		}
	}
}
