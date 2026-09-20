package ui

import "base:runtime"
import "core:hash"
import "core:math"
import "core:os"
import "core:unicode/utf8"

Rect :: struct {
	x:      f32,
	y:      f32,
	width:  f32,
	height: f32,
}

UI_Texture_Id :: distinct u64
UI_Font_Id :: distinct u32

UI_NPatch_Layout :: enum {
	NINE_PATCH,
	THREE_PATCH_VERTICAL,
	THREE_PATCH_HORIZONTAL,
}

back :: proc(array: $D/[dynamic]$T) -> T {
	return array[len(array) - 1]
}
@(private = "file")
WORD_SEPARATION_CHARS :: [?]rune{' ', '\t', '\v', '\f'}

@(private = "file")
g_ui_builder: UI_Builder

UI_Axis :: enum {
	X,
	Y,
}

UI_Layout_Mouse_State :: enum {
	Away,
	Pressed,
	Down,
	Released,
	Hovered,
}

UI_Mouse_State :: enum {
	None,
	Pressed,
	Down,
	Released,
}

UI_Layout_Mouse_Mode :: enum {
	Capture,
	Passthrough,
	Ignore,
}

UI_Input :: struct {
	mouse_position: [2]f32,
	mouse_delta:    [2]f32,
	mouse_state:    UI_Mouse_State,
	mouse_scroll:   [2]f32,
}

UI_Input_Event :: struct {
	mouse_captured:    bool,
	scroll_captured:   bool,
	selected_once:     bool,
	hovered_elements:  [dynamic]u32,
	selected_elements: [dynamic]u32,
	held_elements:     [dynamic]u32,
	clicked_elements:  [dynamic]u32,
	scrolls:           map[u32]UI_Scroll_Data,
}

UI_Scroll_Data :: struct #all_or_none {
	offset:         [2]f32,
	content_size:   [2]f32,
	min_offset:     [2]f32,
	pending_offset: Maybe([2]f32),
}

UI_ClipData :: struct {
	open_clip_stack: [dynamic]Rect,
}

UI_Measure_Text :: proc(
	ui_draw_text: UI_Text_Config,
	font_info: UI_Font,
) -> (
	width: f32,
)

UI_Nine_Patch_Config :: struct {
	source: Rect,
	left:   i32,
	top:    i32,
	right:  i32,
	bottom: i32,
	layout: UI_NPatch_Layout,
}

UI_Image_Fit :: enum {
	Stretch,
	Contain,
	Cover,
	Center,
}

UI_Image :: struct {
	texture: UI_Texture_Id,
	source:  Rect,
	tint:    [4]u8,
	fit:     UI_Image_Fit,
	npatch:  Maybe(UI_Nine_Patch_Config),
}

UI_Image_Command :: struct #all_or_none {
	texture: UI_Texture_Id,
	source:  Rect,
	dest:    Rect,
	npatch:  Maybe(UI_Nine_Patch_Config),
	tint:    [4]u8,
	fit:     UI_Image_Fit,
}

UI_Render_Command :: union {
	UI_Rect_Command,
	UI_Image_Command,
	UI_Text_Command,
	UI_Push_Clip_Command,
	UI_Pop_Clip_Command,
}

UI_Rect_Command :: struct #all_or_none {
	rect:          Rect,
	corner_radius: UI_Corner_Radius,
	border:        UI_Border_Config,
	color:         [4]u8,
}

UI_Text_Command :: struct #all_or_none {
	font:          UI_Font_Id,
	rect:          Rect,
	wrapped_lines: []string,
	content:       string,
	font_size:     f32,
	spacing:       f32,
	line_spacing:  f32,
	color:         [4]u8,
}

UI_Push_Clip_Command :: struct {
	rect: Rect,
}

UI_Pop_Clip_Command :: struct {}

UI_Pointer_Config :: struct {
	texture_id: UI_Texture_Id,
	size:       f32,
	offset:     [2]f32,
}

UI_Pointer_Attributes :: struct {
	config: UI_Pointer_Config,
}


UI_Font :: struct {
	id:        UI_Font_Id,
	base_size: f32,
	spacing:   f32,
}

UI_Font_Config :: struct {
	font_path: cstring,
	base_size: f32,
	spacing:   f32,
}

UI_Builder :: struct {
	current_context: ^UI_Context,
	last_id:         u32,
	context_events:  UI_Context_Events,
}

UI_CTX_MAX_EVENT_LISTENERS :: 3
UI_Context_Events :: struct {
	on_make:   [dynamic; UI_CTX_MAX_EVENT_LISTENERS]proc(),
	on_delete: [dynamic; UI_CTX_MAX_EVENT_LISTENERS]proc(),
	on_begin:  [dynamic; UI_CTX_MAX_EVENT_LISTENERS]proc(),
	on_end:    [dynamic; UI_CTX_MAX_EVENT_LISTENERS]proc(),
}

UI_Context :: struct {
	canvas_size:        [2]f32,
	elements:           [dynamic]UI_Element,
	open_layout_stack:  [dynamic]UI_Index,
	growable_buffer:    [dynamic]UI_Index,
	wrapped_text_lines: [dynamic]string,
	render_commands:    [dynamic]UI_Render_Command,
	pointer:            UI_Pointer_Attributes,
	measure_text:       UI_Measure_Text,
	fonts:              []UI_Font,
	input:              UI_Input,
	input_event:        UI_Input_Event,
	clip:               UI_ClipData,
	ids:                map[u32]UI_Id_Info,
	floats:             [dynamic]UI_Index,
	bounds:             map[u32]Rect,
}


UI_Id_Info :: struct {
	base:       u32,
	index:      UI_Index,
	loop_count: i32,
}

UI_Sizing_Axis :: struct {
	mode: UI_Size_Mode,
	min:  Maybe(f32),
	max:  Maybe(f32),
}

UI_Size_Mode :: union #no_nil {
	UI_Fit_Size,
	UI_Grow_Size,
	UI_Percent_Size,
	UI_Fixed_Size,
}

UI_Grow_Size :: struct {}
UI_Fit_Size :: struct {}
UI_Fixed_Size :: struct {
	value: f32,
}
UI_Percent_Size :: struct {
	value: f32,
}

UI_Layout_Direction :: enum {
	Left_To_Right,
	Top_To_Bottom,
}

UI_Layout_Padding :: struct {
	top:    f32,
	bottom: f32,
	right:  f32,
	left:   f32,
}

UI_Corner_Radius :: struct {
	top_left:     f32,
	top_right:    f32,
	bottom_right: f32,
	bottom_left:  f32,
}

UI_Alignment :: struct {
	x: union {
		f32,
		UI_Alignment_X,
	},
	y: union {
		f32,
		UI_Alignment_Y,
	},
}


UI_Alignment_X :: enum {
	Left,
	Center,
	Right,
}

UI_Alignment_Y :: enum {
	Top,
	Center,
	Bottom,
}

UI_Index :: i32
UI_Font_Index :: i32

UI_Border_Config :: struct #all_or_none {
	thickness: f32,
	color:     [4]u8,
}

UI_Normalized_End :: enum {
	Start,
	End,
}

UI_Element_Link :: struct {
	parent: UI_Index,
	next:   Maybe(UI_Index),
	prev:   Maybe(UI_Index),
	last:   Maybe(UI_Index),
}

UI_Layout_Config :: struct {
	width:            UI_Size_Mode,
	height:           UI_Size_Mode,
	padding:          UI_Layout_Padding,
	child_gap:        f32,
	layout_direction: UI_Layout_Direction,
	child_alignment:  [2]f32,
	background_color: [4]u8,
	background_image: Maybe(UI_Image),
	corner_radius:    UI_Corner_Radius,
	border:           UI_Border_Config,
	mouse_mode:       UI_Layout_Mouse_Mode,
	clip:             bool,
	scroll:           bool,
	ignore_scroll:    bool,
	float_mode:       UI_Float_Mode,
	offset:           [2]f32,
}


UI_Float_Mode :: union {
	UI_Float_None,
	UI_Float_At_Parent,
	UI_Float_At_Id,
	UI_Float_At_Root,
}

UI_Float_None :: struct {}
UI_Float_At_Id :: struct {
	attach_id: u32,
	using _:   UI_Float_Config,
}
UI_Float_At_Parent :: struct {
	using _: UI_Float_Config,
}
UI_Float_At_Root :: struct {
	using _: UI_Float_Config,
}

UI_Float_Attach_Points :: struct {
	element: UI_Anchor_Point,
	parent:  UI_Anchor_Point,
}

UI_Float_Config :: struct {
	attach_points: UI_Float_Attach_Points,
	offset:        [2]f32,
	z_index:       i32,
}

UI_Anchor_Point :: enum {
	LeftTop,
	LeftCenter,
	LeftBottom,
	CenterTop,
	CenterCenter,
	CenterBottom,
	RightTop,
	RightCenter,
	RightBottom,
}

UI_Text_Config :: struct {
	content:      string,
	font_index:   UI_Font_Index,
	font_size:    f32,
	color:        [4]u8,
	line_spacing: f32,
	alignment:    [2]f32,
}

UI_Element :: struct {
	position:   [2]f32,
	size:       [2]f32,
	limits:     UI_Limits,
	link:       UI_Element_Link,
	id:         u32,
	attributes: union {
		UI_Layout_Attributes,
		UI_Text_Attributes,
	},
}

UI_Element_Bound :: struct {
	position: [2]f32,
	size:     [2]f32,
}

UI_Axis_Limits :: struct {
	min: Maybe(f32),
	max: Maybe(f32),
}

UI_Limits :: struct {
	x: UI_Axis_Limits,
	y: UI_Axis_Limits,
}

UI_Layout_Attributes :: struct {
	config: UI_Layout_Config,
}

UI_Text_Attributes :: struct {
	config:                   UI_Text_Config,
	preferred_size:           [2]f32,
	bound_size:               [2]f32,
	wrapped_text_lines_start: i32,
	wrapped_text_lines_count: i32,
}

UI_Child_Iter :: struct {
	ctx:  ^UI_Context,
	next: Maybe(UI_Index),
}

@(require_results)
ui_push_and_dedupe_id :: proc(
	ctx: ^UI_Context,
	index: UI_Index,
	id: u32,
) -> u32 {
	if id_entry, ok := ctx.ids[id]; ok {
		id_entry.loop_count += 1

		ctx.ids[id] = id_entry

		loop_tail := transmute([4]u8)id_entry.loop_count
		new_id := hash.adler32(loop_tail[:], id)

		ctx.ids[new_id] = {
			base       = id,
			index      = index,
			loop_count = 1,
		}

		return new_id
	} else {
		ctx.ids[id] = {
			base       = id,
			index      = index,
			loop_count = 1,
		}
		return id
	}
}

ui_push_id :: proc(ctx: ^UI_Context, index: UI_Index, id: u32) {
	_, existed := ctx.ids[id]
	if existed {
		panic("Duplicate ids without manualy using dedupe")
	}
	ctx.ids[id] = {
		base       = id,
		index      = index,
		loop_count = 1,
	}
}

ui_is_floating_element :: proc(ctx: ^UI_Context, index: UI_Index) -> bool {
	ele := &ctx.elements[index]
	if attr, ok := ele.attributes.(UI_Layout_Attributes); ok {
		return attr.config.float_mode != UI_Float_None{}
	}
	return false
}

ui_open_layout :: proc(
	ctx: ^UI_Context,
	id: u32,
	config: UI_Layout_Config,
	limits: UI_Limits,
) -> bool {
	parent := back(ctx.open_layout_stack)
	index := UI_Index(len(ctx.elements))

	ui_ele := UI_Element {
		id = id,
		attributes = UI_Layout_Attributes{config = config},
		limits = limits,
	}

	ui_ele.link = {
		parent = parent,
		last   = nil,
		next   = nil,
		prev   = ctx.elements[parent].link.last,
	}
	if last, ok := ctx.elements[parent].link.last.?; ok {
		ctx.elements[last].link.next = index
	}
	ctx.elements[parent].link.last = index

	append(&ctx.elements, ui_ele)
	append(&ctx.open_layout_stack, index)
	if ui_is_floating_element(ctx, index) {
		append(&ctx.floats, index)
	}

	return true
}

ui_open_text :: proc(ctx: ^UI_Context, id: u32, config: UI_Text_Config) {
	parent_idx := back(ctx.open_layout_stack)
	index := UI_Index(len(ctx.elements))

	ui_ele := UI_Element {
		id = id,
		attributes = UI_Text_Attributes{config = config},
		limits = {},
	}

	ui_ele.link = {
		parent = parent_idx,
		last   = nil,
		next   = nil,
		prev   = ctx.elements[parent_idx].link.last,
	}
	if last, ok := ctx.elements[parent_idx].link.last.?; ok {
		ctx.elements[last].link.next = index
	}
	ctx.elements[parent_idx].link.last = index

	append(&ctx.elements, ui_ele)
	ui_calculate_text_width(ctx, index)
}

ui_close_layout :: proc(ctx: ^UI_Context, loc := #caller_location) {
	index := pop(&ctx.open_layout_stack)
	ele := &ctx.elements[index]
}

ui_calculate_text_width :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := &ctx.elements[index]
	text_attr, ok := &current.attributes.(UI_Text_Attributes)
	if !ok do return

	content := text_attr.config.content
	config := text_attr.config
	max_line_width := f32(0)
	largest_word_width := f32(0)

	line_start := 0
	for byte_index := 0; byte_index <= len(content); byte_index += 1 {
		is_newline := byte_index == len(content) || content[byte_index] == '\n'
		if is_newline {
			line_end := byte_index
			if line_end > line_start && content[line_end - 1] == '\r' {
				line_end -= 1
			}
			config.content = content[line_start:line_end]
			line_w := ctx.measure_text(config, ctx.fonts[config.font_index])
			if line_w > max_line_width {
				max_line_width = line_w
			}
			line_start = byte_index + 1
		}
	}

	text_attr.preferred_size.x = max_line_width
	text_attr.preferred_size.y = text_attr.config.font_size
	current.size.x = text_attr.preferred_size.x

	{
		word_start := 0
		byte_index := 0
		for byte_index < len(content) {
			whitespace_start := byte_index

			for byte_index < len(content) {
				r, size := utf8.decode_rune(content[byte_index:])
				if !ui_is_separator(r) && r != '\n' && r != '\r' {
					break
				}
				byte_index += size
			}

			word_start = byte_index

			for byte_index < len(content) {
				r, size := utf8.decode_rune(content[byte_index:])
				if ui_is_separator(r) || r == '\n' || r == '\r' {
					break
				}
				byte_index += size
			}

			word_end := byte_index

			if word_start == word_end {
				break
			}

			config.content = content[word_start:word_end]

			word_width := ctx.measure_text(
				config,
				ctx.fonts[config.font_index],
			)

			if word_width > largest_word_width {
				largest_word_width = word_width
			}
		}

		current.limits.x.min = largest_word_width
	}

	current.size.x = ui_clamp_element_size(current.size.x, current.limits.x)
}

ui_clamp_element_size :: proc(
	current_size: f32,
	limits: UI_Axis_Limits,
) -> f32 {
	res := current_size
	if min_size, ok := limits.min.(f32); ok && res <= min_size {
		res = min_size
	}
	if max_size, ok := limits.max.(f32); ok && res >= max_size {
		res = max_size
	}
	return res
}

ui_fit_sizing :: proc(ctx: ^UI_Context, index: UI_Index, axis: UI_Axis) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(UI_Layout_Attributes)
	if !ok do return

	if fixed, ok := layout_get_mode(layout, axis).(UI_Fixed_Size); ok {
		ele_set_min(current, fixed.value, axis)
		ele_set_max(current, fixed.value, axis)
		ele_set_size(current, fixed.value, axis)
		return
	}

	padding := layout_get_pad(layout, axis)

	children_size := f32(0)
	children_min_size := f32(0)
	child_count := 0

	for it := ui_child_iter_start(ctx, index); child in ui_child_iter_next(&it) {
		child_size := ele_get_size(child, axis)
		child_min := ele_get_min(child, axis)

		if layout_is_along(layout, axis) {
			children_size += child_size
			children_min_size += child_min
			child_count += 1
		} else {
			children_size = max(children_size, child_size)
			children_min_size = max(children_min_size, child_min)
		}
	}

	if layout_is_along(layout, axis) && child_count > 1 {
		gap := f32(child_count - 1) * layout.config.child_gap
		children_size += gap
		children_min_size += gap
	}

	children_size += padding
	children_min_size += padding

	if mode, ok := layout_get_mode(layout, axis).(UI_Fit_Size); ok {
		ele_set_min(
			current,
			max(ele_get_min(current, axis), children_min_size),
			axis,
		)
	}
	ele_set_size(
		current,
		ui_clamp_element_size(children_size, ele_get_lims(current, axis)),
		axis,
	)
}

ui_fit_sizing_tree :: proc(ctx: ^UI_Context, index: UI_Index, axis: UI_Axis) {
	for it := ui_child_iter_start(ctx, index); child, child_index in ui_child_iter_next(&it) {
		ui_fit_sizing_tree(ctx, child_index, axis)
	}
	ui_fit_sizing(ctx, index, axis)
}

ui_grow_and_percent_sizing :: proc(
	ctx: ^UI_Context,
	index: UI_Index,
	axis: UI_Axis,
) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(UI_Layout_Attributes)
	if !ok || current.link.last == nil do return

	available := ele_get_size(current, axis) - layout_get_pad(layout, axis)
	percent_basis := available

	if layout_is_across(layout, axis) {
		for it := ui_child_iter_start(ctx, index); child in ui_child_iter_next(&it) {
			if ui_is_grow_layout_or_text(child^, axis) {
				ele_set_size(
					child,
					ui_clamp_element_size(
						available,
						ele_get_lims(child, axis),
					),
					axis,
				)
			} else if percent_size, ok := layout_get_mode(
				   child^,
				   axis,
			   ).(UI_Percent_Size); ok {
				ele_set_size(
					child,
					ui_clamp_element_size(
						percent_size.value * percent_basis,
						ele_get_lims(child, axis),
					),
					axis,
				)
			}
		}
		return
	}

	growables := &ctx.growable_buffer
	clear(growables)
	defer clear(growables)

	child_count := 0
	for it := ui_child_iter_start(ctx, index); child in ui_child_iter_next(&it) do child_count += 1
	if child_count == 0 do return

	gap_total := f32(child_count - 1) * layout.config.child_gap

	remaining := available - gap_total
	percent_basis -= gap_total

	for it := ui_child_iter_start(ctx, index); child, child_index in ui_child_iter_next(&it) {
		if ui_is_grow_layout_or_text(child^, axis) {
			append(growables, child_index)
		} else if percent_size, ok := layout_get_mode(
			   child^,
			   axis,
		   ).(UI_Percent_Size); ok {
			ele_set_size(
				child,
				ui_clamp_element_size(
					percent_size.value * percent_basis,
					ele_get_lims(child, axis),
				),
				axis,
			)
		}
		remaining -= ele_get_size(child, axis)
	}

	if len(growables) == 0 do return

	growable_count := len(growables)

	for remaining > math.F32_EPSILON && len(growables) > 0 {
		smallest := ele_get_size(&ctx.elements[growables[0]], axis)
		second_smallest := smallest
		size_to_add := remaining

		for i in 1 ..< len(growables) {
			child := &ctx.elements[growables[i]]
			child_size := ele_get_size(child, axis)

			if child_size < smallest {
				second_smallest = smallest
				smallest = child_size
			} else if child_size < second_smallest {
				second_smallest = child_size
			}
		}

		if second_smallest > smallest {
			size_to_add = min(
				second_smallest - smallest,
				remaining / f32(len(growables)),
			)
		} else {
			size_to_add = remaining / f32(len(growables))
		}

		for i := 0; i < len(growables); {
			child_index := growables[i]
			child := &ctx.elements[child_index]

			if ele_get_size(child, axis) == smallest {
				previous := ele_get_size(child, axis)
				new_size := previous + size_to_add

				if max_size, ok := ele_get_max(child, axis).(f32);
				   ok && new_size >= max_size {
					new_size = max_size
					ele_set_size(child, new_size, axis)

					remaining -= new_size - previous
					unordered_remove(growables, i)
					continue
				}

				ele_set_size(child, new_size, axis)
				remaining -= size_to_add
			}

			i += 1
		}
	}

	non_zero_resize(growables, growable_count)

	shrinkables := growables
	overshoot := -remaining

	for overshoot > math.F32_EPSILON && len(shrinkables) > 0 {
		largest := ele_get_size(&ctx.elements[shrinkables[0]], axis)
		second_largest := largest
		size_to_subtract := overshoot

		for i in 1 ..< len(shrinkables) {
			child := &ctx.elements[shrinkables[i]]
			child_size := ele_get_size(child, axis)

			if child_size > largest {
				second_largest = largest
				largest = child_size
			} else if child_size > second_largest {
				second_largest = child_size
			}
		}

		if second_largest < largest {
			size_to_subtract = min(
				largest - second_largest,
				overshoot / f32(len(shrinkables)),
			)
		} else {
			size_to_subtract = overshoot / f32(len(shrinkables))
		}

		for i := 0; i < len(shrinkables); {
			child_index := shrinkables[i]
			child := &ctx.elements[child_index]

			if ele_get_size(child, axis) == largest {
				previous := ele_get_size(child, axis)
				new_size := previous - size_to_subtract

				min_size := ele_get_min(child, axis)

				if new_size <= min_size {
					new_size = min_size
					ele_set_size(child, new_size, axis)

					overshoot -= previous - new_size
					unordered_remove(shrinkables, i)
					continue
				}

				ele_set_size(child, new_size, axis)
				overshoot -= size_to_subtract
			}

			i += 1
		}
	}
}

ui_grow_and_percent_sizing_tree :: proc(
	ctx: ^UI_Context,
	index: UI_Index,
	axis: UI_Axis,
) {
	ui_grow_and_percent_sizing(ctx, index, axis)
	for it := ui_child_iter_start(ctx, index); child, child_index in ui_child_iter_next(&it) {
		ui_grow_and_percent_sizing_tree(ctx, child_index, axis)
	}
}

ui_is_separator :: #force_inline proc(r: rune) -> bool {
	for sep in WORD_SEPARATION_CHARS {
		if r == sep {
			return true
		}
	}
	return false
}

ui_wrap_texts :: proc(ctx: ^UI_Context, index: UI_Index = 0) {
	for it := ui_child_iter_start(ctx, index); ele, child_index in ui_child_iter_next(&it) {
		text_attr, ok := (&ele.attributes.(UI_Text_Attributes))
		if !ok { 	// layout
			ui_wrap_texts(ctx, child_index)
			continue
		}

		content := text_attr.config.content
		config := text_attr.config

		line_start := 0
		line_width := f32(0)

		wrapped_start := len(ctx.wrapped_text_lines)
		wrapped_count := 0

		defer {
			text_attr.wrapped_text_lines_start = i32(wrapped_start)
			text_attr.wrapped_text_lines_count = i32(wrapped_count)

			if wrapped_count > 0 {
				ele.size.y =
					config.font_size * f32(wrapped_count) +
					f32(wrapped_count - 1) * config.line_spacing
				text_attr.bound_size.x = ele.size.x
			} else {
				ele.size.y = config.font_size
				text_attr.bound_size.x = text_attr.preferred_size.x
			}
			ele.limits.y.min = ele.size.y
			text_attr.bound_size.y = ele.size.y
		}

		has_newlines := false
		for ch in content {
			if ch == '\n' {
				has_newlines = true
				break
			}
		}

		raw_line_start := 0
		for raw_index := 0; raw_index <= len(content); raw_index += 1 {
			is_end := raw_index == len(content)
			if !is_end && content[raw_index] != '\n' do continue

			raw_line_end := raw_index
			if raw_line_end > raw_line_start &&
			   content[raw_line_end - 1] == '\r' {
				raw_line_end -= 1
			}

			raw_line := content[raw_line_start:raw_line_end]
			raw_line_start = raw_index + 1

			config.content = raw_line
			line_w := ctx.measure_text(config, ctx.fonts[config.font_index])

			if line_w <= ele.size.x && !has_newlines {
				continue
			}

			if line_w <= ele.size.x {
				append(&ctx.wrapped_text_lines, raw_line)
				wrapped_count += 1
				continue
			}

			line_start := 0
			line_width := f32(0)
			byte_index := 0

			for byte_index < len(raw_line) {
				whitespace_start := byte_index

				for byte_index < len(raw_line) {
					r, size := utf8.decode_rune(raw_line[byte_index:])
					if !ui_is_separator(r) {
						break
					}
					byte_index += size
				}

				word_start := byte_index

				for byte_index < len(raw_line) {
					r, size := utf8.decode_rune(raw_line[byte_index:])
					if ui_is_separator(r) {
						break
					}
					byte_index += size
				}

				word_end := byte_index

				if word_start == word_end {
					break
				}

				config.content = raw_line[whitespace_start:word_start]
				whitespace_width := ctx.measure_text(
					config,
					ctx.fonts[config.font_index],
				)

				config.content = raw_line[word_start:word_end]
				word_width := ctx.measure_text(
					config,
					ctx.fonts[config.font_index],
				)

				candidate_width := whitespace_width + word_width

				if line_width > 0 &&
				   line_width + candidate_width > ele.size.x {
					append(
						&ctx.wrapped_text_lines,
						raw_line[line_start:whitespace_start],
					)
					wrapped_count += 1

					line_start = word_start
					line_width = word_width
				} else {
					line_width += candidate_width
				}
			}

			append(&ctx.wrapped_text_lines, raw_line[line_start:])
			wrapped_count += 1
		}
	}
}


ui_get_anchor_point :: proc(
	ele: UI_Element,
	anchor: UI_Anchor_Point,
) -> [2]f32 {
	return ele.position + ele.size * ui_get_anchor_offset(anchor)
}

ui_get_anchor_offset :: proc(anchor: UI_Anchor_Point) -> [2]f32 {
	switch anchor {
	case .LeftTop:
		return {0, 0}
	case .LeftCenter:
		return {0, 0.5}
	case .LeftBottom:
		return {0, 1.0}
	case .CenterTop:
		return {0.5, 0}
	case .CenterCenter:
		return {0.5, 0.5}
	case .CenterBottom:
		return {0.5, 1.0}
	case .RightTop:
		return {1.0, 0.0}
	case .RightCenter:
		return {1.0, 0.5}
	case .RightBottom:
		return {1.0, 1.0}
	}
	return {0, 0}
}

ui_calculate_position :: proc(
	ctx: ^UI_Context,
	index: UI_Index,
	axis: UI_Axis,
) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(UI_Layout_Attributes)
	if !ok {
		text_attr := current.attributes.(UI_Text_Attributes)

		if ele_get_size(current, axis) > text_get_preferred(text_attr, axis) {
			remaining :=
				ele_get_size(current, axis) -
				text_get_preferred(text_attr, axis)

			align_offset :=
				remaining * align_get_offset(text_attr.config.alignment, axis)
			ele_set_pos(
				current,
				ele_get_pos(current, axis) + align_offset,
				axis,
			)
		}

		ele_set_size(current, text_get_bound_size(text_attr, axis), axis)

		return
	}

	scroll_data := ctx.input_event.scrolls[current.id]
	scroll_offset := axis == .X ? scroll_data.offset.x : scroll_data.offset.y
	offset :=
		ele_get_pos(current, axis) +
		layout_get_pad_at(layout, axis, .Start) +
		scroll_offset

	if layout_is_along(layout, axis) {
		remaining := ele_get_size(current, axis) - layout_get_pad(layout, axis)

		child_count := 0
		for it := ui_child_iter_start(ctx, index); child in ui_child_iter_next(&it) {
			remaining -= ele_get_size(child, axis)
			child_count += 1
		}

		if child_count > 0 {
			remaining -= f32(child_count - 1) * layout.config.child_gap
		}

		offset +=
			remaining * align_get_offset(layout.config.child_alignment, axis)
	}

	for it := ui_child_iter_start(ctx, index); child, child_index in ui_child_iter_next(&it) {
		child_layout, is_child_layout := child.attributes.(UI_Layout_Attributes)
		child_offset :=
			offset +
			(is_child_layout ? ((child_layout.config.ignore_scroll ? -scroll_offset : 0) + layout_get_final_offset(child_layout, axis)) : 0)

		ele_set_pos(child, child_offset, axis)

		if layout_is_across(layout, axis) {
			remaining :=
				ele_get_size(current, axis) -
				layout_get_pad(layout, axis) -
				ele_get_size(child, axis)

			align_offset :=
				remaining *
				align_get_offset(layout.config.child_alignment, axis)

			ele_set_pos(child, ele_get_pos(child, axis) + align_offset, axis)
		} else {
			offset += ele_get_size(child, axis) + layout.config.child_gap
		}

		ui_calculate_position(ctx, child_index, axis)
	}
}

ui_context_make :: proc(
	fonts: []UI_Font,
	measure_text: UI_Measure_Text,
	pointer: UI_Pointer_Config = {},
) -> UI_Context {
	for event in g_ui_builder.context_events.on_make {
		event()
	}

	fonts_copy := make([]UI_Font, len(fonts))
	copy(fonts_copy, fonts)

	return UI_Context {
		elements = make([dynamic]UI_Element, 0, 5),
		open_layout_stack = make([dynamic]UI_Index, 0, 5),
		render_commands = make([dynamic]UI_Render_Command, 0, 5),
		growable_buffer = make([dynamic]UI_Index, 0, 5),
		wrapped_text_lines = make([dynamic]string, 0, 5),
		pointer = {config = pointer},
		measure_text = measure_text,
		fonts = fonts_copy,
		input_event = {
			mouse_captured = false,
			hovered_elements = make([dynamic]u32, 0, 4),
			selected_elements = make([dynamic]u32, 0, 4),
			held_elements = make([dynamic]u32, 0, 4),
			clicked_elements = make([dynamic]u32, 0, 4),
			scrolls = make(map[u32]UI_Scroll_Data, 4),
		},
		clip = {open_clip_stack = make([dynamic]Rect, 0, 2)},
		ids = make(map[u32]UI_Id_Info, 50),
		floats = make([dynamic]UI_Index, 0, 4),
		bounds = make(map[u32]Rect, 50),
	}
}

ui_context_delete :: proc(ctx: UI_Context) {
	for event in g_ui_builder.context_events.on_delete {
		event()
	}

	delete(ctx.elements)
	delete(ctx.open_layout_stack)
	delete(ctx.render_commands)
	delete(ctx.growable_buffer)
	delete(ctx.wrapped_text_lines)
	delete(ctx.fonts)

	delete(ctx.input_event.hovered_elements)
	delete(ctx.input_event.selected_elements)
	delete(ctx.input_event.held_elements)
	delete(ctx.input_event.clicked_elements)
	delete(ctx.input_event.scrolls)
	delete(ctx.clip.open_clip_stack)
	delete(ctx.ids)
	delete(ctx.floats)
	delete(ctx.bounds)
}

@(require_results, deferred_in_out = ui_end)
ui_begin :: proc(
	ctx: ^UI_Context,
	canvas_size: [2]f32,
	input: UI_Input,
) -> bool {
	g_ui_builder.current_context = ctx
	for p in g_ui_builder.context_events.on_begin do p()

	ctx.canvas_size = canvas_size
	ctx.input = input

	clear(&ctx.ids)
	clear(&ctx.elements)
	clear(&ctx.open_layout_stack)
	clear(&ctx.floats)

	append(&ctx.elements, ui_root_layout(canvas_size))
	append(&ctx.open_layout_stack, 0)

	clear(&ctx.render_commands)
	clear(&ctx.growable_buffer)
	clear(&ctx.wrapped_text_lines)

	return true
}

ui_end :: proc(ctx: ^UI_Context, _: [2]f32, _: UI_Input, ok: bool) {
	if !ok do return

	// close root
	ui_close_layout(ctx)

	ui_fit_sizing_tree(ctx, 0, .X)
	ui_grow_and_percent_sizing_tree(ctx, 0, .X)
	ui_wrap_texts(ctx, 0)

	ui_fit_sizing_tree(ctx, 0, .Y)
	ui_grow_and_percent_sizing_tree(ctx, 0, .Y)

	ui_calculate_position(ctx, 0, .X)
	ui_calculate_position(ctx, 0, .Y)

	ui_handle_floats(ctx)

	// generate render commands
	clear(&ctx.render_commands)
	clear(&ctx.clip.open_clip_stack)

	ui_generate_commands(ctx, 0)

	// sort floats by z_index ascending for rendering
	ui_sort_floats_by_zindex(ctx, ctx.floats[:])
	for idx in ctx.floats {
		ui_generate_commands(ctx, idx)
	}

	// mouse input
	{
		ctx.input_event.mouse_captured = false
		ctx.input_event.scroll_captured = false
		ctx.input_event.selected_once = false

		clear(&ctx.input_event.hovered_elements)
		clear(&ctx.input_event.clicked_elements)
		clear(&ctx.clip.open_clip_stack)

		// detect mouse input on floats first, in reverse z index order
		#reverse for idx in ctx.floats {
			ui_detect_mouse(ctx, idx)
			if ctx.input_event.mouse_captured && ctx.input_event.scroll_captured do break
		}
		// then the normal layout layer
		ui_detect_mouse(ctx, 0)

		if ctx.input.mouse_state == .Released {
			clear(&ctx.input_event.held_elements)
		}
	}


	// write bounds, forward to later frame
	clear(&ctx.bounds)
	for ele in ctx.elements {
		ctx.bounds[ele.id] = ele_get_rect(ele)
	}

	for p in g_ui_builder.context_events.on_end do p()
}

ui_handle_floats :: proc(ctx: ^UI_Context) {
	grow_and_percent_float_root :: proc(
		ctx: ^UI_Context,
		index: UI_Index,
		axis: UI_Axis,
	) {
		current := &ctx.elements[index]
		layout := ctx.elements[index].attributes.(UI_Layout_Attributes)

		float_parent_index, _ := ui_get_float_target(
			ctx^,
			index,
			layout.config.float_mode,
		)

		float_parent := &ctx.elements[float_parent_index]

		#partial switch mode in layout_get_mode(layout, axis) {
		case UI_Grow_Size:
			size := ui_clamp_element_size(
				ele_get_size(float_parent, axis),
				ele_get_lims(current, axis),
			)
			ele_set_size(current, size, axis)
		case UI_Percent_Size:
			size := ui_clamp_element_size(
				mode.value * ele_get_size(float_parent, axis),
				ele_get_lims(current, axis),
			)
			ele_set_size(current, size, axis)
		}
	}

	calculate_float_root_position :: proc(ctx: ^UI_Context, index: UI_Index) {
		ele := &ctx.elements[index]
		layout := ele.attributes.(UI_Layout_Attributes)

		target_index, float_config := ui_get_float_target(
			ctx^,
			index,
			layout.config.float_mode,
		)

		element_offset :=
			ele.size * ui_get_anchor_offset(float_config.attach_points.element)
		target_anchor := ui_get_anchor_point(
			ctx.elements[target_index],
			float_config.attach_points.parent,
		)

		pos := target_anchor - element_offset + float_config.offset
		ele.position = pos
	}

	for float_index in ctx.floats {
		// only fit sizing includes direct sizing on current layout,
		// grow and percent sizing only calculate children sizing
		ui_fit_sizing_tree(ctx, float_index, .X)

		grow_and_percent_float_root(ctx, float_index, .X)
		ui_grow_and_percent_sizing_tree(ctx, float_index, .X)
		ui_wrap_texts(ctx, float_index)

		ui_fit_sizing_tree(ctx, float_index, .Y)

		grow_and_percent_float_root(ctx, float_index, .Y)
		ui_grow_and_percent_sizing_tree(ctx, float_index, .Y)

		calculate_float_root_position(ctx, float_index)
		ui_calculate_position(ctx, float_index, .X)
		ui_calculate_position(ctx, float_index, .Y)
	}
}


ui_generate_commands :: proc(ctx: ^UI_Context, index: UI_Index) {
	ele := &ctx.elements[index]

	switch attr in ele.attributes {
	case UI_Layout_Attributes:
		if attr.config.background_color.a > 0 ||
		   attr.config.border.thickness > 0 {
			append(
				&ctx.render_commands,
				UI_Rect_Command{
					rect = {
						ele.position.x,
						ele.position.y,
						ele.size.x,
						ele.size.y,
					},
					color = attr.config.background_color,
					corner_radius = attr.config.corner_radius,
					border = attr.config.border,
				},
			)
		}
		if bg_img, ok := attr.config.background_image.?; ok {
			append(
				&ctx.render_commands,
				UI_Image_Command{
					texture = bg_img.texture,
					source = bg_img.source,
					dest = {
						ele.position.x,
						ele.position.y,
						ele.size.x,
						ele.size.y,
					},
					tint = bg_img.tint.a == 0 && bg_img.tint.r == 0 && bg_img.tint.g == 0 && bg_img.tint.b == 0 ? [4]u8{255, 255, 255, 255} : bg_img.tint,
					fit = bg_img.fit,
					npatch = bg_img.npatch,
				},
			)
		}
		if attr.config.clip && !ui_is_floating_element(ctx, index) {
			append(
				&ctx.render_commands,
				UI_Push_Clip_Command{
					rect = {
						ele.position.x,
						ele.position.y,
						ele.size.x,
						ele.size.y,
					},
				},
			)
		}
	case UI_Text_Attributes:
		append(
			&ctx.render_commands,
			UI_Text_Command{
				content = attr.config.content,
				font = ctx.fonts[attr.config.font_index].id,
				font_size = attr.config.font_size,
				spacing = ctx.fonts[attr.config.font_index].spacing,
				line_spacing = attr.config.line_spacing,
				color = attr.config.color,
				wrapped_lines = ctx.wrapped_text_lines[attr.wrapped_text_lines_start:][:attr.wrapped_text_lines_count],
				rect = {
					ele.position.x,
					ele.position.y,
					attr.bound_size.x,
					attr.bound_size.y,
				},
			},
		)
	}

	for it := ui_child_iter_start(ctx, index); child, child_index in ui_child_iter_next(&it) {
		ui_generate_commands(ctx, child_index)
	}

	if layout_attr, ok := ele.attributes.(UI_Layout_Attributes);
	   ok && layout_attr.config.clip && !ui_is_floating_element(ctx, index) {
		append(&ctx.render_commands, UI_Pop_Clip_Command{})
	}
}

ui_detect_mouse :: proc(ctx: ^UI_Context, index: UI_Index) {
	detect_mouse_should_stop :: proc(input_event: UI_Input_Event) -> bool {
		return input_event.mouse_captured && input_event.scroll_captured
	}

	if detect_mouse_should_stop(ctx.input_event) {
		return
	}

	ui_travel_tree_reverse(ctx, index, on_down = proc(ctx: ^UI_Context, idx: i32) -> (stop: bool) {
			ele := ctx.elements[idx]

			layout := ele.attributes.(UI_Layout_Attributes) or_return
			ele_rect := ele_get_rect(ele)

			if layout.config.clip && !ui_is_floating_element(ctx, idx) {
				if len(ctx.clip.open_clip_stack) == 0 {
					append(&ctx.clip.open_clip_stack, ele_rect)
				} else {
					append(&ctx.clip.open_clip_stack, ui_intersect_rect(back(ctx.clip.open_clip_stack), ele_rect))
				}
			}

			return
		}, on_up = proc(ctx: ^UI_Context, idx: i32) -> (stop: bool) {
			ele := ctx.elements[idx]

			layout, ok := ele.attributes.(UI_Layout_Attributes)
			if !ok do return

			defer if layout.config.clip && !ui_is_floating_element(ctx, idx) {
				pop(&ctx.clip.open_clip_stack)
			}

			if layout.config.mouse_mode == .Ignore do return

			clipped_rect: Rect = {ele.position.x, ele.position.y, ele.size.x, ele.size.y}

			if !ctx.input_event.mouse_captured {
				if len(ctx.clip.open_clip_stack) > 0 {
					clipped_rect = ui_intersect_rect(clipped_rect, back(ctx.clip.open_clip_stack))
				}

				if ui_rect_contains(ctx.input.mouse_position, clipped_rect) {
					switch ctx.input.mouse_state {
					case .Pressed:
						if !ctx.input_event.selected_once {
							clear(&ctx.input_event.selected_elements)
							clear(&ctx.input_event.held_elements)
							ctx.input_event.selected_once = true
						}
						append(&ctx.input_event.selected_elements, ele.id)
						append(&ctx.input_event.held_elements, ele.id)
					case .Released:
						if ui_is_id_held(ele.id) {
							append(&ctx.input_event.clicked_elements, ele.id)
						}
					case .None, .Down:
					}

					append(&ctx.input_event.hovered_elements, ele.id)

					if layout.config.mouse_mode == .Capture {
						ctx.input_event.mouse_captured = true
					}
				}
			}

			if !ctx.input_event.scroll_captured && layout.config.scroll {
				mouse_position := ctx.input.mouse_position

				ele_rect := ele_get_rect(ele)

				clipped_rect := ele_rect

				if len(ctx.clip.open_clip_stack) > 0 {
					clipped_rect = ui_intersect_rect(back(ctx.clip.open_clip_stack), ele_rect)
				}

				if ui_rect_contains(ctx.input.mouse_position, clipped_rect) {
					content_size: [2]f32 = {layout_get_content_size(ctx, idx, layout, .X), layout_get_content_size(ctx, idx, layout, .Y)}
					min_offset: [2]f32 = {-(content_size.x - (ele.size.x - layout_get_pad(layout, .X))), -(content_size.y - (ele.size.y - layout_get_pad(layout, .Y)))}

					cur_scroll := ctx.input_event.scrolls[ele.id]
					pending_offset, is_pending := cur_scroll.pending_offset.?
					next_scroll_offset := is_pending ? pending_offset : cur_scroll.offset + ctx.input.mouse_scroll * 20.0

					next_scroll_offset = {clamp(next_scroll_offset.x, min_offset.x, 0), clamp(next_scroll_offset.y, min_offset.y, 0)}

					ctx.input_event.scrolls[ele.id] = {
						offset         = next_scroll_offset,
						pending_offset = nil,
						content_size   = content_size,
						min_offset     = min_offset,
					}

					ctx.input_event.scroll_captured = true
				}
			}

			stop = detect_mouse_should_stop(ctx.input_event)

			return
		})
}

ui_travel_tree_reverse :: proc(
	ctx: ^UI_Context,
	index: UI_Index = 0,
	on_up: proc(ctx: ^UI_Context, index: UI_Index) -> bool = nil,
	on_down: proc(ctx: ^UI_Context, index: UI_Index) -> bool = nil,
) -> bool {
	if on_down != nil && on_down(ctx, index) do return true
	it := ui_child_iter_reverse_start(ctx, index)
	for child, child_index in ui_child_iter_reverse_next(&it) {
		if ui_travel_tree_reverse(ctx, child_index, on_up, on_down) {
			return true
		}
	}
	if on_up != nil && on_up(ctx, index) do return true
	return false
}

ui_root_layout :: proc(screen_size: [2]f32) -> UI_Element {
	return UI_Element {
		id = 0,
		position = {0, 0},
		size = {screen_size.x, screen_size.y},
		limits = {},
		attributes = UI_Layout_Attributes {
			config = UI_Layout_Config {
				child_gap = 2,
				width = UI_Fixed_Size{screen_size.x},
				height = UI_Fixed_Size{screen_size.y},
				layout_direction = .Top_To_Bottom,
				padding = ui_pad_all(2),
				background_color = {},
			},
		},
	}
}

ui_child_iter_start :: proc(
	ctx: ^UI_Context,
	start_index: UI_Index,
	exclude_floats := true,
) -> UI_Child_Iter {
	start := ctx.elements[start_index]

	next_index: Maybe(UI_Index) =
		start.link.last != nil ? start_index + 1 : nil

	// Forwards until we find non float
	for next_index != nil && ui_is_floating_element(ctx, next_index.?) {
		next_index = ctx.elements[next_index.?].link.next
	}

	return {ctx = ctx, next = next_index}
}

ui_child_iter_next :: proc(
	it: ^UI_Child_Iter,
) -> (
	child: ^UI_Element,
	child_index: UI_Index,
	cond: bool,
) {
	if it.next == nil {
		return
	}

	child_index = it.next.?
	child = &it.ctx.elements[child_index]
	cond = true

	it.next = child.link.next

	for it.next != nil && ui_is_floating_element(it.ctx, it.next.?) {
		it.next = it.ctx.elements[it.next.?].link.next
	}

	return
}

ui_child_iter_reverse_start :: proc(
	ctx: ^UI_Context,
	start_index: UI_Index,
) -> UI_Child_Iter {
	start := ctx.elements[start_index]
	next_index := start.link.last

	// Backwards until we find non float
	for next_index != nil && ui_is_floating_element(ctx, next_index.?) {
		next_index = ctx.elements[next_index.?].link.prev
	}

	return {ctx = ctx, next = next_index}
}

ui_child_iter_reverse_next :: proc(
	it: ^UI_Child_Iter,
) -> (
	child: ^UI_Element,
	child_index: UI_Index,
	cond: bool,
) {
	if it.next == nil {
		return
	}

	child_index = it.next.?
	child = &it.ctx.elements[child_index]
	cond = true

	it.next = child.link.prev

	for it.next != nil && ui_is_floating_element(it.ctx, it.next.?) {
		it.next = it.ctx.elements[it.next.?].link.prev
	}

	return
}

ui_get_float_target :: proc(
	ctx: UI_Context,
	index: UI_Index,
	float_mode: UI_Float_Mode,
) -> (
	target_index: UI_Index,
	config: UI_Float_Config,
) {
	ele := ctx.elements[index]
	switch mode in float_mode {
	case UI_Float_At_Parent:
		{
			parent_idx := ele.link.parent
			target_index = parent_idx
			config = mode
		}
	case UI_Float_At_Id:
		{
			id_entry, existed := ctx.ids[mode.attach_id]
			assert(existed)
			target_index = id_entry.index
			config = mode
		}
	case UI_Float_At_Root:
		{
			target_index = 0
			config = mode
		}
	case UI_Float_None:
		panic("Element doesn't float")
	}
	return
}

ui_is_grow_layout_or_text :: proc(ele: UI_Element, axis: UI_Axis) -> bool {
	switch attr in ele.attributes {
	case UI_Text_Attributes:
		{
			return true
		}
	case UI_Layout_Attributes:
		{
			if axis == .X {
				_, ok := attr.config.width.(UI_Grow_Size)
				return ok
			} else {
				_, ok := attr.config.height.(UI_Grow_Size)
				return ok
			}
		}
	}
	return false
}

@(private = "file")
layout_get_pad :: proc(layout: UI_Layout_Attributes, axis: UI_Axis) -> f32 {
	return(
		axis == .X ? layout.config.padding.left + layout.config.padding.right : layout.config.padding.top + layout.config.padding.bottom \
	)
}

@(private = "file")
layout_get_content_size :: proc(
	ctx: ^UI_Context,
	index: UI_Index,
	layout: UI_Layout_Attributes,
	axis: UI_Axis,
) -> f32 {
	content_size: f32 = 0
	if layout_is_along(layout, axis) {
		child_count: i32 = 0
		for it := ui_child_iter_start(ctx, index); child in ui_child_iter_next(&it) {
			content_size += ele_get_size(child, axis)
			child_count += 1
		}
		content_size +=
			child_count > 0 ? f32(child_count - 1) * layout.config.child_gap : 0
	} else {
		max_size: f32 = 0
		for it := ui_child_iter_start(ctx, index); child in ui_child_iter_next(&it) {
			max_size = max(max_size, ele_get_size(child, axis))
		}
		content_size += max_size
	}
	return content_size
}

@(private = "file")
layout_get_pad_at :: proc(
	layout: UI_Layout_Attributes,
	axis: UI_Axis,
	end: UI_Normalized_End,
) -> f32 {
	return(
		axis == .X ? (end == .Start ? layout.config.padding.left : layout.config.padding.right) : (end == .Start ? layout.config.padding.top : layout.config.padding.bottom) \
	)
}

@(private = "file")
layout_get_mode :: proc {
	layout_get_mode_from_attr,
	layout_get_mode_from_ele,
}

@(private = "file")
layout_get_mode_from_attr :: proc(
	layout: UI_Layout_Attributes,
	axis: UI_Axis,
) -> UI_Size_Mode {
	return axis == .X ? layout.config.width : layout.config.height
}

@(private = "file")
layout_get_mode_from_ele :: proc(
	element: UI_Element,
	axis: UI_Axis,
) -> UI_Size_Mode {
	layout := element.attributes.(UI_Layout_Attributes)
	return axis == .X ? layout.config.width : layout.config.height
}

@(private = "file")
layout_is_along :: proc(layout: UI_Layout_Attributes, axis: UI_Axis) -> bool {
	return(
		axis == .X ? layout.config.layout_direction == .Left_To_Right : layout.config.layout_direction == .Top_To_Bottom \
	)
}

@(private = "file")
layout_is_across :: proc(layout: UI_Layout_Attributes, axis: UI_Axis) -> bool {
	return(
		axis == .X ? layout.config.layout_direction == .Top_To_Bottom : layout.config.layout_direction == .Left_To_Right \
	)
}

@(private = "file")
layout_get_final_offset :: proc(
	layout: UI_Layout_Attributes,
	axis: UI_Axis,
) -> f32 {
	return axis == .X ? layout.config.offset.x : layout.config.offset.y
}

@(private = "file")
ele_set_size :: proc(element: ^UI_Element, value: f32, axis: UI_Axis) {
	if axis == .X do element.size.x = value
	else do element.size.y = value
}

@(private = "file")
ele_set_min :: proc(element: ^UI_Element, value: f32, axis: UI_Axis) {
	if axis == .X do element.limits.x.min = value
	else do element.limits.y.min = value
}

@(private = "file")
ele_set_max :: proc(element: ^UI_Element, value: f32, axis: UI_Axis) {
	if axis == .X do element.limits.x.max = value
	else do element.limits.y.max = value
}

@(private = "file")
ele_get_size :: proc(element: ^UI_Element, axis: UI_Axis) -> f32 {
	return axis == .X ? element.size.x : element.size.y
}

@(private = "file")
ele_get_min :: proc(element: ^UI_Element, axis: UI_Axis) -> f32 {
	return(
		axis == .X ? element.limits.x.min.? or_else 0 : element.limits.y.min.? or_else 0 \
	)
}

@(private = "file")
ele_get_max :: proc(element: ^UI_Element, axis: UI_Axis) -> Maybe(f32) {
	return axis == .X ? element.limits.x.max : element.limits.y.max
}

@(private = "file")
ele_get_lims :: proc(element: ^UI_Element, axis: UI_Axis) -> UI_Axis_Limits {
	return axis == .X ? element.limits.x : element.limits.y
}

@(private = "file")
ele_set_pos :: proc(element: ^UI_Element, value: f32, axis: UI_Axis) {
	if axis == .X do element.position.x = value
	else do element.position.y = value
}

@(private = "file")
ele_get_pos :: proc(element: ^UI_Element, axis: UI_Axis) -> f32 {
	if axis == .X do return element.position.x
	else do return element.position.y
}

@(private = "file")
ele_get_rect :: #force_inline proc(element: UI_Element) -> Rect {
	return {
		x = element.position.x,
		y = element.position.y,
		width = element.size.x,
		height = element.size.y,
	}
}

@(private = "file")
text_get_preferred :: proc(
	text_attr: UI_Text_Attributes,
	axis: UI_Axis,
) -> f32 {
	return axis == .X ? text_attr.preferred_size.x : text_attr.preferred_size.y
}

@(private = "file")
text_get_bound_size :: proc(
	text_attr: UI_Text_Attributes,
	axis: UI_Axis,
) -> f32 {
	return axis == .X ? text_attr.bound_size.x : text_attr.bound_size.y
}

@(private = "file")
align_get_offset :: proc(alignment: [2]f32, axis: UI_Axis) -> f32 {
	return axis == .X ? alignment.x : alignment.y
}

ui_sort_floats_by_zindex :: proc(ctx: ^UI_Context, indices: []UI_Index) {
	// ascending sort
	if len(indices) <= 1 do return
	// simple insertion sort
	for i in 1 ..< len(indices) {
		j := i
		for j > 0 {
			a := &ctx.elements[indices[j]]
			b := &ctx.elements[indices[j - 1]]
			a_float := a.attributes.(UI_Layout_Attributes).config.float_mode
			b_float := b.attributes.(UI_Layout_Attributes).config.float_mode
			a_z := ui_get_float_z_index(a_float)
			b_z := ui_get_float_z_index(b_float)
			swap := a_z < b_z
			if swap {
				indices[j], indices[j - 1] = indices[j - 1], indices[j]
				j -= 1
			} else {
				break
			}
		}
	}
}

ui_get_float_z_index :: proc(float: UI_Float_Mode) -> i32 {
	switch float_type in float {
	case UI_Float_None:
		panic("Element doesn't float")
	case UI_Float_At_Parent:
		return float_type.z_index
	case UI_Float_At_Id:
		return float_type.z_index
	case UI_Float_At_Root:
		return float_type.z_index
	}
	return 0
}

BORDER_DEFAULT: UI_Border_Config : {thickness = 0, color = {0, 0, 0, 255}}

@(require_results)
ui_draw_layout :: proc(
	width: UI_Sizing_Axis = {mode = UI_Fit_Size{}},
	height: UI_Sizing_Axis = {mode = UI_Fit_Size{}},
	padding: UI_Layout_Padding = {2, 2, 2, 2},
	child_gap: f32 = 2,
	layout_direction: UI_Layout_Direction = .Left_To_Right,
	child_alignment: UI_Alignment = {x = .Left, y = .Top},
	background_color: [4]u8 = {},
	background_image: Maybe(UI_Image) = nil,
	corner_radius: UI_Corner_Radius = {4, 4, 4, 4},
	border: UI_Border_Config = BORDER_DEFAULT,
	mouse_mode: UI_Layout_Mouse_Mode = .Capture,
	clip: bool = false,
	scroll: bool = false,
	ignore_scroll: bool = false,
	float_mode: UI_Float_Mode = UI_Float_None{},
	offset: [2]f32 = {},
) -> bool {
	return ui_open_layout(
		g_ui_builder.current_context,
		g_ui_builder.last_id,
		{
			width = width.mode,
			height = height.mode,
			padding = padding,
			child_gap = child_gap,
			layout_direction = layout_direction,
			child_alignment = get_alignment_offset(child_alignment),
			background_color = background_color,
			background_image = background_image,
			corner_radius = corner_radius,
			mouse_mode = mouse_mode,
			border = border,
			clip = clip,
			scroll = scroll,
			float_mode = float_mode,
			ignore_scroll = ignore_scroll,
			offset = offset,
		},
		{
			x = {min = width.min, max = width.max},
			y = {min = height.min, max = height.max},
		},
	)
}

ui_draw_text :: proc(
	content: string,
	font_index: UI_Font_Index = 0,
	font_size: f32 = 16,
	color: [4]u8 = {0, 0, 0, 255},
	line_spacing: f32 = 8,
	alignment: UI_Alignment = {x = .Left, y = .Top},
	loc := #caller_location,
) -> bool {
	ui_open_text(
		g_ui_builder.current_context,
		g_ui_builder.last_id,
		{
			content = content,
			font_index = font_index,
			font_size = font_size,
			color = color,
			line_spacing = line_spacing,
			alignment = get_alignment_offset(alignment),
		},
	)
	return true
}

ui_grow :: #force_inline proc(
	min: Maybe(f32) = nil,
	max: Maybe(f32) = nil,
) -> UI_Sizing_Axis {
	return {mode = UI_Grow_Size{}, min = min, max = max}
}

ui_fixed :: #force_inline proc(
	value: f32 = 0,
	min: Maybe(f32) = nil,
	max: Maybe(f32) = nil,
) -> UI_Sizing_Axis {
	return {mode = UI_Fixed_Size{value = value}, min = min, max = max}
}

ui_fit :: #force_inline proc(
	min: Maybe(f32) = nil,
	max: Maybe(f32) = nil,
) -> UI_Sizing_Axis {
	return {mode = UI_Fit_Size{}, min = min, max = max}
}

ui_percent :: #force_inline proc(
	value: f32,
	min: Maybe(f32) = nil,
	max: Maybe(f32) = nil,
) -> UI_Sizing_Axis {
	return {mode = UI_Percent_Size{value = value}, min = min, max = max}
}

ui_pad_all :: #force_inline proc(value: f32) -> UI_Layout_Padding {
	return UI_Layout_Padding{value, value, value, value}
}

ui_corner_radius_all :: #force_inline proc(value: f32) -> UI_Corner_Radius {
	return UI_Corner_Radius{value, value, value, value}
}


ui_mouse_state_on_this :: proc() -> UI_Layout_Mouse_State {
	return get_layout_mouse_state_by_id(
		g_ui_builder.current_context^,
		g_ui_builder.last_id,
	)
}

ui_mouse_state_on_id :: proc(id: u32) -> UI_Layout_Mouse_State {
	return get_layout_mouse_state_by_id(g_ui_builder.current_context^, id)
}

ui_mouse_state :: proc() -> UI_Mouse_State {
	return g_ui_builder.current_context.input.mouse_state
}

ui_mouse_delta :: proc() -> [2]f32 {
	return g_ui_builder.current_context.input.mouse_delta
}

ui_mouse_position :: proc() -> [2]f32 {
	return g_ui_builder.current_context.input.mouse_position
}

ui_rect_by_id :: proc(id: u32) -> Rect {
	rect, ok := g_ui_builder.current_context.bounds[id]
	assert(ok)
	return rect
}

ui_is_id_selected :: proc(id: u32) -> bool {
	for ele_id in g_ui_builder.current_context.input_event.selected_elements {
		if ele_id == id do return true
	}
	return false
}

ui_is_this_selected :: proc() -> bool {
	return ui_is_id_selected(g_ui_builder.last_id)
}

ui_is_id_held :: proc(id: u32) -> bool {
	for ele_id in g_ui_builder.current_context.input_event.held_elements {
		if ele_id == id do return true
	}
	return false
}

ui_is_this_held :: proc() -> bool {
	return ui_is_id_held(g_ui_builder.last_id)
}

ui_is_id_hovered :: proc(id: u32) -> bool {
	for ele_id in g_ui_builder.current_context.input_event.hovered_elements {
		if ele_id == id do return true
	}
	return false
}

ui_is_this_hovered :: proc() -> bool {
	return ui_is_id_hovered(g_ui_builder.last_id)
}

ui_is_id_clicked :: proc(id: u32) -> bool {
	for ele_id in g_ui_builder.current_context.input_event.clicked_elements {
		if ele_id == id do return true
	}
	return false
}

ui_is_this_clicked :: proc() -> bool {
	return ui_is_id_clicked(g_ui_builder.last_id)
}

ui_current_scroll_data :: proc() -> UI_Scroll_Data {
	return get_layout_scroll_data(g_ui_builder.current_context^)
}

ui_set_scroll_offset :: proc(scroll: [2]f32) {
	set_layout_scroll_offset(g_ui_builder.current_context, scroll)
}

// Internal ultilities
@(private = "file")
set_layout_scroll_offset :: proc(ctx: ^UI_Context, new_scroll: [2]f32) {
	open_ele := ctx.open_layout_stack[len(ctx.open_layout_stack) - 1]
	scroll := ctx.input_event.scrolls[ctx.elements[open_ele].id]
	scroll.pending_offset = new_scroll

	ctx.input_event.scrolls[ctx.elements[open_ele].id] = scroll
}

@(private = "file")
get_layout_scroll_data :: proc(ctx: UI_Context) -> UI_Scroll_Data {
	open_ele := ctx.open_layout_stack[len(ctx.open_layout_stack) - 1]
	return ctx.input_event.scrolls[ctx.elements[open_ele].id]
}


@(private = "file")
get_layout_mouse_state_by_id :: proc(
	ctx: UI_Context,
	id: u32,
) -> UI_Layout_Mouse_State {
	for ele_id in ctx.input_event.hovered_elements {
		if ele_id == id {
			switch ctx.input.mouse_state {
			case .None:
				return .Hovered
			case .Pressed:
				return .Pressed
			case .Down:
				return .Down
			case .Released:
				return .Released
			}
		}
	}
	return .Away
}

@(private = "file")
get_alignment_offset :: proc(alignment: UI_Alignment) -> [2]f32 {
	offset: [2]f32
	switch variant in alignment.x {
	case UI_Alignment_X:
		{
			switch variant {
			case .Left:
				offset.x = 0
			case .Center:
				offset.x = .5
			case .Right:
				offset.x = 1
			}
		}
	case f32:
		offset.x = variant
	}

	switch variant in alignment.y {
	case UI_Alignment_Y:
		{
			switch variant {
			case .Top:
				offset.y = 0
			case .Center:
				offset.y = .5
			case .Bottom:
				offset.y = 1
			}
		}
	case f32:
		offset.y = variant
	}

	return offset
}

@(require_results)
ui_intersect_rect :: proc(a, b: Rect) -> (Rect, bool) #optional_ok {
	left := max(a.x, b.x)
	top := max(a.y, b.y)
	right := min(a.x + a.width, b.x + b.width)
	bottom := min(a.y + a.height, b.y + b.height)

	width := right - left
	height := bottom - top

	return {x = left, y = top, width = max(width, 0), height = max(height, 0)},
		width > 0 && height > 0
}

@(require_results)
ui_rect_contains :: proc(p: [2]f32, rec: Rect) -> bool {
	return(
		p.x >= rec.x &&
		p.x <= rec.x + rec.width &&
		p.y >= rec.y &&
		p.y <= rec.y + rec.height \
	)
}


ui_auto_id_hash :: proc(
	parent_hash: u32,
	loc: runtime.Source_Code_Location,
) -> u32 {
	line := transmute([4]u8)loc.line
	column := transmute([4]u8)loc.column
	h: u32 = parent_hash
	h = hash.adler32(transmute([]u8)loc.file_path, h)
	h = hash.adler32(transmute([]u8)line[:], h)
	h = hash.adler32(transmute([]u8)column[:], h)
	return h
}

@(require_results)
ui_global_id :: proc(id: string) -> u32 {
	id := hash.adler32(transmute([]u8)id)

	return id
}

@(require_results)
ui_local_id :: proc(id: string) -> u32 {
	parent_hash :=
		g_ui_builder.current_context.elements[back(g_ui_builder.current_context.open_layout_stack)].id
	id := hash.adler32(transmute([]u8)id, parent_hash)

	return id
}

@(require_results)
ui_family_id :: proc(id: string, owner: string) -> u32 {
	parent_hash :=
		g_ui_builder.current_context.elements[back(g_ui_builder.current_context.open_layout_stack)].id
	id := hash.adler32(transmute([]u8)id, parent_hash)

	return id
}

@(private)
ui_declare_id :: proc(id: Maybe(u32), loc: runtime.Source_Code_Location) {
	index := i32(len(g_ui_builder.current_context.elements))

	new_id: u32
	if id == nil {
		parent_hash :=
			g_ui_builder.current_context.elements[back(g_ui_builder.current_context.open_layout_stack)].id
		new_id = ui_auto_id_hash(parent_hash, loc)
		new_id = ui_push_and_dedupe_id(
			g_ui_builder.current_context,
			index,
			new_id,
		)

	} else {
		new_id = id.?
		ui_push_id(g_ui_builder.current_context, index, new_id)
	}

	g_ui_builder.last_id = new_id
}

UI_Element_Config :: struct($T: typeid) {
	config: T,
}


@(deferred_none = ui_end_layout)
ui_layout :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
	reuse_id: bool = false,
) -> UI_Element_Config(type_of(ui_draw_layout)) {
	return ui_begin_layout(id, loc, reuse_id)
}

ui_begin_layout :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
	reuse_id: bool = false,
) -> UI_Element_Config(type_of(ui_draw_layout)) {
	if !reuse_id {
		ui_declare_id(id, loc)
	}
	return {ui_draw_layout}
}

@(private)
ui_end_layout :: proc() {
	ui_close_layout(g_ui_builder.current_context)
}

@(deferred_none = ui_end_layout)
ui_defer_end_layout :: proc() -> bool {
	return true
}

ui_text :: proc(
	id: Maybe(u32) = nil,
	loc := #caller_location,
) -> UI_Element_Config(type_of(ui_draw_text)) {
	ui_declare_id(id, loc)
	return {ui_draw_text}
}


ui_last_id :: proc() -> u32 {
	return g_ui_builder.last_id
}


ui_get_builder :: proc "contextless" () -> ^UI_Builder {
	return &g_ui_builder
}
