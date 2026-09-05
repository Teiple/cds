package ui

import "base:runtime"
import "core:fmt"
import "core:hash"
import "core:math"
import "core:os"
import "core:unicode/utf8"
import rl "vendor:raylib"

WORD_SEPARATION_CHARS :: [?]rune{' ', '\t', '\v', '\f'}

@(private = "file")
builder: UI_Builder

Axis :: enum {
	X,
	Y,
}

UI_Mouse_State :: enum {
	None,
	Pressed,
	Down,
	Released,
	Hover,
}

UI_Layout_Mouse_Mode :: enum {
	Capture,
	Passthrough,
	Ignore,
}

UI_Input :: struct {
	mouse_position: rl.Vector2,
	mouse_state:    UI_Mouse_State,
	scroll:         rl.Vector2,
}

UI_Input_Event :: struct {
	mouse_captured:   bool,
	scroll_captured:  bool,
	hovered_elements: [dynamic]u32,
	scrolls:          map[u32]UI_Scroll_Data,
}

UI_Scroll_Data :: struct #all_or_none {
	offset:         rl.Vector2,
	content_size:   rl.Vector2,
	min_offset:     rl.Vector2,
	view_size:      rl.Vector2,
	pending_offset: Maybe(rl.Vector2),
}

UI_ClipData :: struct {
	open_clip_stack: [dynamic]rl.Rectangle,
}

UI_Layout_Mouse_Event_Callbacks :: struct {
	on_pressed:  proc(),
	on_released: proc(),
	on_down:     proc(),
	on_hover:    proc(),
}

UI_Measure_Text :: proc(draw_text: UI_Text_Config, font_info: UI_Font) -> (width: f32)

Render_Command :: union {
	Rect_Command,
	Text_Command,
	Push_Clip_Command,
	Pop_Clip_Command,
}

Rect_Command :: struct #all_or_none {
	rect:          rl.Rectangle,
	color:         rl.Color,
	corner_radius: rl.Vector4,
	border:        Border_Config,
}

Text_Command :: struct #all_or_none {
	font_size:     f32,
	spacing:       f32,
	line_spacing:  f32,
	content:       string,
	font:          rl.Font,
	color:         rl.Color,
	rect:          rl.Rectangle,
	wrapped_lines: []string,
}

Push_Clip_Command :: struct {
	rect: rl.Rectangle,
}

Pop_Clip_Command :: struct {}

UI_Font :: struct {
	font:    rl.Font,
	spacing: f32,
}

UI_Font_Config :: struct {
	font_path: cstring,
	base_size: f32,
	spacing:   f32,
}

Mask_Shader :: struct {
	shader:         rl.Shader,
	mask_rectangle: i32,
}

UI_Builder :: struct {
	current_context: ^UI_Context,
	last_id:         u32,
}

UI_Context :: struct {
	elements:           [dynamic]UI_Element,
	open_layout_stack:  [dynamic]UI_Index,
	growable_buffer:    [dynamic]UI_Index,
	wrapped_text_lines: [dynamic]string,
	render_commands:    [dynamic]Render_Command,
	measure_text:       UI_Measure_Text,
	fonts:              []UI_Font,
	mask_shader:        Mask_Shader,
	input:              UI_Input,
	screen_size:        rl.Vector2,
	input_event:        UI_Input_Event,
	clip:               UI_ClipData,
	ids:                map[u32]UI_Id_Entry,
}

UI_Id_Entry :: struct {
	base:       u32,
	index:      UI_Index,
	loop_count: i32,
}

Sizing_Axis :: struct {
	mode: Size_Mode,
	min:  Maybe(f32),
	max:  Maybe(f32),
}

Size_Mode :: union #no_nil {
	Fit_Size,
	Grow_Size,
	Percent_Size,
	Fixed_Size,
}

Grow_Size :: struct {}
Fit_Size :: struct {}
Fixed_Size :: struct {
	value: f32,
}
Percent_Size :: struct {
	value: f32,
}

Layout_Direction :: enum {
	Left_To_Right,
	Top_To_Bottom,
}

Layout_Padding :: struct {
	top:    f32,
	bottom: f32,
	right:  f32,
	left:   f32,
}

Alignment :: struct {
	x: union {
		f32,
		Alignment_X,
	},
	y: union {
		f32,
		Alignment_Y,
	},
}


Alignment_X :: enum {
	Left,
	Center,
	Right,
}

Alignment_Y :: enum {
	Top,
	Center,
	Bottom,
}

UI_Index :: i32
Font_Index :: i32

Border_Config :: struct #all_or_none {
	thickness: f32,
	color:     rl.Color,
}

Shadow_Config :: struct #all_or_none {
	enabled: bool,
	color:   rl.Color,
	radius:  f32,
	offset:  rl.Vector2,
}

NormalizedEnd :: enum {
	Start,
	End,
}

UI_Link :: struct {
	parent: UI_Index,
	next:   Maybe(UI_Index),
	prev:   Maybe(UI_Index),
	last:   Maybe(UI_Index),
}

UI_Layout_Config :: struct {
	width:            Size_Mode,
	height:           Size_Mode,
	padding:          Layout_Padding,
	child_gap:        f32,
	layout_direction: Layout_Direction,
	child_alignment:  rl.Vector2,
	background_color: rl.Color,
	corner_radius:    f32,
	border:           Border_Config,
	mouse_mode:       UI_Layout_Mouse_Mode,
	callbacks:        UI_Layout_Mouse_Event_Callbacks,
	clip:             bool,
	scroll:           bool,
	ignore_scroll:    bool,
	float:            UI_Float,
	offset:           rl.Vector2,
}


UI_Float :: union {
	Float_None,
	Float_At_Parent,
	Float_At_Id,
	Float_At_Root,
}

Float_None :: struct {}
Float_At_Id :: struct {
	attach_id: u32,
	using _:   UI_Float_Config,
}
Float_At_Parent :: struct {
	using _: UI_Float_Config,
}
Float_At_Root :: struct {
	using _: UI_Float_Config,
}

UI_Float_Config :: struct {
	attach_points: struct {
		element: AnchorPoint,
		parent:  AnchorPoint,
	},
	offset:        rl.Vector2,
	z_index:       i32,
}

AnchorPoint :: enum {
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
	font_index:   Font_Index,
	font_size:    f32,
	color:        rl.Color,
	line_spacing: f32,
	alignment:    rl.Vector2,
}

UI_Element :: struct {
	position:   rl.Vector2,
	size:       rl.Vector2,
	limits:     UI_Limits,
	link:       UI_Link,
	id:         u32,
	attributes: union {
		Layout_Attributes,
		Text_Attributes,
	},
}

UI_Axis_Limits :: struct {
	min: Maybe(f32),
	max: Maybe(f32),
}

UI_Limits :: struct {
	x: UI_Axis_Limits,
	y: UI_Axis_Limits,
}

Layout_Attributes :: struct {
	element: UI_Index,
	config:  UI_Layout_Config,
}

Text_Attributes :: struct {
	element:                  UI_Index,
	config:                   UI_Text_Config,
	preferred_size:           rl.Vector2,
	size:                     rl.Vector2,
	wrapped_text_lines_start: i32,
	wrapped_text_lines_count: i32,
}

Child_Iter :: struct {
	ctx:  ^UI_Context,
	next: Maybe(UI_Index),
}

@(private = "file")
push_and_dedupe_id :: proc(ctx: ^UI_Context, index: UI_Index, id: u32) -> u32 {
	// collisions may due to for loops or procedure calls
	// procedure calls must set the loc manually, this only handle for loops

	if id_entry, ok := ctx.ids[id]; ok {
		id_entry.loop_count += 1

		// Update base id entry
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

@(private = "file")
push_id :: proc(ctx: ^UI_Context, index: UI_Index, id: u32) {
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

@(private = "file")
open_layout :: proc(ctx: ^UI_Context, id: u32, config: UI_Layout_Config, limits: UI_Limits) -> bool {
	parent := back(ctx.open_layout_stack)
	index := UI_Index(len(ctx.elements))

	ui_ele := UI_Element {
		id = id,
		attributes = Layout_Attributes{config = config, element = index},
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
	return true
}

@(private = "file")
open_text :: proc(ctx: ^UI_Context, id: u32, config: UI_Text_Config) {
	parent_idx := back(ctx.open_layout_stack)
	index := UI_Index(len(ctx.elements))

	ui_ele := UI_Element {
		id = id,
		attributes = Text_Attributes{config = config, element = index},
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
	calculate_text_width(ctx, index)
}

@(private = "file")
close_layout :: proc(ctx: ^UI_Context, loc := #caller_location) {
	index := pop(&ctx.open_layout_stack)
	ele := &ctx.elements[index]
	fit_sizing(ctx, index, .X)
}

@(private = "file")
calculate_text_width :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := &ctx.elements[index]
	text_attr, ok := &current.attributes.(Text_Attributes)
	if !ok do return

	text_attr.preferred_size.x = ctx.measure_text(text_attr.config, ctx.fonts[text_attr.config.font_index])
	text_attr.preferred_size.y = text_attr.config.font_size

	current.size.x = text_attr.preferred_size.x

	{
		content := text_attr.config.content
		config := text_attr.config
		word_start := 0
		largest_word_width := f32(0)

		byte_index := 0
		for byte_index < len(content) {
			whitespace_start := byte_index

			for byte_index < len(content) {
				r, size := utf8.decode_rune(content[byte_index:])
				if !is_separator(r) {
					break
				}
				byte_index += size
			}

			word_start = byte_index

			for byte_index < len(content) {
				r, size := utf8.decode_rune(content[byte_index:])
				if is_separator(r) {
					break
				}
				byte_index += size
			}

			word_end := byte_index

			if word_start == word_end {
				break
			}

			config.content = content[word_start:word_end]

			word_width := ctx.measure_text(config, ctx.fonts[config.font_index])

			if word_width > largest_word_width {
				largest_word_width = word_width
			}
		}

		current.limits.x.min = largest_word_width
	}

	current.size.x = clamp_element_size(current.size.x, current.limits.x)
}

@(private = "file")
clamp_element_size :: proc(current_size: f32, limits: UI_Axis_Limits) -> f32 {
	res := current_size
	if min_size, ok := limits.min.(f32); ok && res <= min_size {
		res = min_size
	}
	if max_size, ok := limits.max.(f32); ok && res >= max_size {
		res = max_size
	}
	return res
}

@(private = "file")
fit_sizing :: proc(ctx: ^UI_Context, index: UI_Index, axis: Axis) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(Layout_Attributes)
	if !ok do return

	if fixed, ok := layout_get_mode(layout, axis).(Fixed_Size); ok {
		ele_set_min(current, fixed.value, axis)
		ele_set_max(current, fixed.value, axis)
		ele_set_size(current, fixed.value, axis)
		return
	}

	padding := layout_get_pad(layout, axis)

	children_size := f32(0)
	children_min_size := f32(0)
	child_count := 0

	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
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

	if mode, ok := layout_get_mode(layout, axis).(Fit_Size); ok {
		ele_set_min(current, max(ele_get_min(current, axis), children_min_size), axis)
	}
	ele_set_size(current, clamp_element_size(children_size, ele_get_lims(current, axis)), axis)
}

@(private = "file")
fit_sizing_heights_tree :: proc(ctx: ^UI_Context, index: UI_Index) {
	for it := child_iter_start(ctx, index); child, child_index in child_iter_next(&it) {
		fit_sizing_heights_tree(ctx, child_index)
	}
	fit_sizing(ctx, index, .Y)
}

@(private = "file")
grow_and_percent_sizing :: proc(ctx: ^UI_Context, index: UI_Index, axis: Axis) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(Layout_Attributes)
	if !ok || current.link.last == nil do return

	available := ele_get_size(current, axis) - layout_get_pad(layout, axis)
	percent_basis := available

	if layout_is_across(layout, axis) {
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			if is_grow_layout_or_text(child^, axis) {
				ele_set_size(child, clamp_element_size(available, ele_get_lims(child, axis)), axis)
			} else if percent_size, ok := layout_get_mode(child^, axis).(Percent_Size); ok {
				ele_set_size(
					child,
					clamp_element_size(percent_size.value * percent_basis, ele_get_lims(child, axis)),
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
	for it := child_iter_start(ctx, index); child in child_iter_next(&it) do child_count += 1
	assert(child_count > 0)
	gap_total := f32(child_count - 1) * layout.config.child_gap

	remaining := available - gap_total
	percent_basis -= gap_total

	for it := child_iter_start(ctx, index); child, child_index in child_iter_next(&it) {
		if is_grow_layout_or_text(child^, axis) {
			append(growables, child_index)
		} else if percent_size, ok := layout_get_mode(child^, axis).(Percent_Size); ok {
			ele_set_size(
				child,
				clamp_element_size(percent_size.value * percent_basis, ele_get_lims(child, axis)),
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
			size_to_add = min(second_smallest - smallest, remaining / f32(len(growables)))
		} else {
			size_to_add = remaining / f32(len(growables))
		}

		for i := 0; i < len(growables); {
			child_index := growables[i]
			child := &ctx.elements[child_index]

			if ele_get_size(child, axis) == smallest {
				previous := ele_get_size(child, axis)
				new_size := previous + size_to_add

				if max_size, ok := ele_get_max(child, axis).(f32); ok && new_size >= max_size {
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
			size_to_subtract = min(largest - second_largest, overshoot / f32(len(shrinkables)))
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

@(private = "file")
grow_and_percent_sizing_tree :: proc(ctx: ^UI_Context, index: UI_Index, axis: Axis) {
	grow_and_percent_sizing(ctx, index, axis)
	for it := child_iter_start(ctx, index); child, child_index in child_iter_next(&it) {
		grow_and_percent_sizing_tree(ctx, child_index, axis)
	}
}

@(private = "file")
is_separator :: #force_inline proc(r: rune) -> bool {
	for sep in WORD_SEPARATION_CHARS {
		if r == sep {
			return true
		}
	}
	return false
}

@(private = "file")
wrap_texts :: proc(ctx: ^UI_Context) {
	for &ele in ctx.elements {
		text_attr := (&ele.attributes.(Text_Attributes)) or_continue

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
				ele.size.y = config.font_size * f32(wrapped_count) + f32(wrapped_count - 1) * config.line_spacing
				text_attr.size.x = ele.size.x
			} else {
				ele.size.y = config.font_size
				text_attr.size.x = text_attr.preferred_size.x
			}
			ele.limits.y.min = ele.size.y
			text_attr.size.y = ele.size.y
		}

		byte_index := 0

		for byte_index < len(content) {
			whitespace_start := byte_index

			for byte_index < len(content) {
				r, size := utf8.decode_rune(content[byte_index:])
				if !is_separator(r) {
					break
				}
				byte_index += size
			}

			word_start := byte_index

			for byte_index < len(content) {
				r, size := utf8.decode_rune(content[byte_index:])
				if is_separator(r) {
					break
				}
				byte_index += size
			}

			word_end := byte_index

			if word_start == word_end {
				break
			}

			config.content = content[whitespace_start:word_start]
			whitespace_width := ctx.measure_text(config, ctx.fonts[config.font_index])

			config.content = content[word_start:word_end]
			word_width := ctx.measure_text(config, ctx.fonts[config.font_index])

			candidate_width := whitespace_width + word_width

			if line_width > 0 && line_width + candidate_width > ele.size.x {
				append(&ctx.wrapped_text_lines, content[line_start:whitespace_start])
				wrapped_count += 1

				line_start = word_start
				line_width = word_width
			} else {
				line_width += candidate_width
			}
		}

		if wrapped_count > 0 {
			append(&ctx.wrapped_text_lines, content[line_start:])
			wrapped_count += 1
		}
	}
}

@(private = "file")
calculate_floating_positions :: proc(ctx: ^UI_Context) {
	for &ele in ctx.elements {
		layout := ele.attributes.(Layout_Attributes) or_continue

		target_ele: UI_Element
		float_config: UI_Float_Config

		switch float in layout.config.float {
		case Float_At_Parent:
			{
				parent_idx := ele.link.parent
				target_ele = ctx.elements[parent_idx]
				float_config = float
			}
		case Float_At_Id:
			{
				id_entry, existed := ctx.ids[float.attach_id]
				assert(existed)
				target_ele = ctx.elements[id_entry.index]
				float_config = float
			}
		case Float_At_Root:
			{
				target_ele = ctx.elements[0] // Root element
				float_config = float
			}
		case Float_None:
			continue
		}

		// Get anchor points in screen coordinates
		element_anchor := get_anchor_point(ele, float_config.attach_points.element)
		target_anchor := get_anchor_point(target_ele, float_config.attach_points.parent)

		// Calculate final position
		pos := target_anchor - element_anchor + float_config.offset
		ele.position = pos
	}
}

@(private = "file")
get_anchor_point :: proc(ele: UI_Element, anchor: AnchorPoint) -> rl.Vector2 {
	pos := ele.position
	size := ele.size
	switch anchor {
	case .LeftTop:
		return {pos.x, pos.y}
	case .LeftCenter:
		return {pos.x, pos.y + size.y * 0.5}
	case .LeftBottom:
		return {pos.x, pos.y + size.y}
	case .CenterTop:
		return {pos.x + size.x * 0.5, pos.y}
	case .CenterCenter:
		return {pos.x + size.x * 0.5, pos.y + size.y * 0.5}
	case .CenterBottom:
		return {pos.x + size.x * 0.5, pos.y + size.y}
	case .RightTop:
		return {pos.x + size.x, pos.y}
	case .RightCenter:
		return {pos.x + size.x, pos.y + size.y * 0.5}
	case .RightBottom:
		return {pos.x + size.x, pos.y + size.y}
	}
	return pos
}

@(private = "file")
calculate_position :: proc(ctx: ^UI_Context, index: UI_Index, axis: Axis) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(Layout_Attributes)
	if !ok {
		text_attr := current.attributes.(Text_Attributes)

		if ele_get_size(current, axis) > text_get_preferred(text_attr, axis) {
			remaining := ele_get_size(current, axis) - text_get_preferred(text_attr, axis)

			align_offset := remaining * align_get_offset(text_attr.config.alignment, axis)
			ele_set_pos(current, ele_get_pos(current, axis) + align_offset, axis)
		}

		// We cheat here, reset text size to its instrinsic size, since aligment may move the excessive size
		// with it when the text is grown
		ele_set_size(current, text_attr.size.x, .X)
		ele_set_size(current, text_attr.size.y, .Y)

		return
	}

	scroll_data := ctx.input_event.scrolls[current.id]
	scroll_offset := axis == .X ? scroll_data.offset.x : scroll_data.offset.y
	offset := ele_get_pos(current, axis) + layout_get_pad_at(layout, axis, .Start) + scroll_offset

	if layout_is_along(layout, axis) {
		remaining := ele_get_size(current, axis) - layout_get_pad(layout, axis)

		child_count := 0
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			remaining -= ele_get_size(child, axis)
			child_count += 1
		}

		if child_count > 0 {
			remaining -= f32(child_count - 1) * layout.config.child_gap
		}

		offset += remaining * align_get_offset(layout.config.child_alignment, axis)
	}

	for it := child_iter_start(ctx, index); child, child_index in child_iter_next(&it) {
		child_layout, is_child_layout := child.attributes.(Layout_Attributes)
		child_offset :=
			offset +
			(is_child_layout ? ((child_layout.config.ignore_scroll ? -scroll_offset : 0) + layout_get_final_offset(child_layout, axis)) : 0)

		ele_set_pos(child, child_offset, axis)

		if layout_is_across(layout, axis) {
			remaining := ele_get_size(current, axis) - layout_get_pad(layout, axis) - ele_get_size(child, axis)

			align_offset := remaining * align_get_offset(layout.config.child_alignment, axis)

			ele_set_pos(child, ele_get_pos(child, axis) + align_offset, axis)
		} else {
			offset += ele_get_size(child, axis) + layout.config.child_gap
		}

		calculate_position(ctx, child_index, axis)
	}
}

@(private = "file")
load_font :: proc(base_size: f32, spacing: f32, font_path: cstring) -> UI_Font {
	assert(os.exists(string(font_path)))

	font_file_size: i32 = 0
	font_file_data := rl.LoadFileData(font_path, &font_file_size)

	font: rl.Font = {
		baseSize   = i32(base_size),
		glyphCount = 95,
	}

	font.glyphs = rl.LoadFontData(font_file_data, font_file_size, i32(base_size), nil, 0, .DEFAULT, &font.glyphCount)

	atlas := rl.GenImageFontAtlas(font.glyphs, &font.recs, font.glyphCount, font.baseSize, 0, 1)
	font.texture = rl.LoadTextureFromImage(atlas)
	rl.SetTextureFilter(font.texture, rl.TextureFilter.BILINEAR)

	rl.UnloadImage(atlas)
	rl.UnloadFileData(font_file_data)

	assert(rl.IsFontValid(font))

	return {font = font, spacing = spacing}
}

@(private = "file")
load_mask_shader :: proc() -> Mask_Shader {
	shader := rl.LoadShader("./shaders/mask.vs", "./shaders/mask.fs")
	return {shader = shader, mask_rectangle = rl.GetShaderLocation(shader, "maskRectangle")}
}

context_make :: proc(measure_text_proc: UI_Measure_Text, font_configs: []UI_Font_Config) -> UI_Context {
	fonts := make([dynamic]UI_Font, 0, 4)
	for config in font_configs {
		append(&fonts, load_font(config.base_size, config.spacing, config.font_path))
	}

	return UI_Context {
		elements = make([dynamic]UI_Element, 0, 5),
		open_layout_stack = make([dynamic]UI_Index, 0, 5),
		render_commands = make([dynamic]Render_Command, 0, 5),
		growable_buffer = make([dynamic]UI_Index, 0, 5),
		wrapped_text_lines = make([dynamic]string, 0, 5),
		measure_text = measure_text_proc,
		fonts = fonts[:],
		mask_shader = load_mask_shader(),
		input_event = {
			mouse_captured = false,
			hovered_elements = make([dynamic]u32, 0, 4),
			scrolls = make(map[u32]UI_Scroll_Data, 4),
		},
		clip = {open_clip_stack = make([dynamic]rl.Rectangle, 0, 2)},
		ids = make(map[u32]UI_Id_Entry, 50),
	}
}

context_delete :: proc(ctx: UI_Context) {
	delete(ctx.elements)
	delete(ctx.open_layout_stack)
	delete(ctx.render_commands)
	delete(ctx.growable_buffer)
	delete(ctx.wrapped_text_lines)

	for f in ctx.fonts {
		rl.UnloadFont(f.font)
	}
	delete(ctx.fonts)

	rl.UnloadShader(ctx.mask_shader.shader)

	delete(ctx.input_event.hovered_elements)
	delete(ctx.input_event.scrolls)
	delete(ctx.clip.open_clip_stack)
	delete(ctx.ids)
}

@(require_results, deferred_in_out = end_layout)
begin_layout :: proc(ctx: ^UI_Context, screen_width: f32, screen_height: f32) -> bool {
	builder.current_context = ctx

	ctx.screen_size = {screen_width, screen_height}

	clear(&ctx.ids)
	clear(&ctx.elements)
	clear(&ctx.open_layout_stack)

	append(&ctx.elements, root_layout(screen_width, screen_height))
	append(&ctx.open_layout_stack, 0)

	clear(&ctx.render_commands)
	clear(&ctx.growable_buffer)
	clear(&ctx.wrapped_text_lines)

	return true
}

@(private = "file")
end_layout :: proc(ctx: ^UI_Context, _: f32, _: f32, ok: bool) {
	if !ok do return

	close_layout(ctx)

	grow_and_percent_sizing_tree(ctx, 0, .X)
	wrap_texts(ctx)

	fit_sizing_heights_tree(ctx, 0)
	grow_and_percent_sizing_tree(ctx, 0, .Y)

	calculate_position(ctx, 0, .X)
	calculate_position(ctx, 0, .Y)

	detect_mouse(ctx)

	clear(&ctx.render_commands)
	clear(&ctx.clip.open_clip_stack)

	generate_commands(ctx, 0)

	clear(&ctx.elements)
	clear(&ctx.open_layout_stack)
}

@(private = "file")
generate_commands :: proc(ctx: ^UI_Context, index: UI_Index) {
	ele := &ctx.elements[index]

	switch attr in ele.attributes {
	case Layout_Attributes:
		append(
			&ctx.render_commands,
			Rect_Command{
				rect = {ele.position.x, ele.position.y, ele.size.x, ele.size.y},
				color = attr.config.background_color,
				corner_radius = attr.config.corner_radius,
				border = attr.config.border,
			},
		)
		if attr.config.clip {
			append(
				&ctx.render_commands,
				Push_Clip_Command{rect = {ele.position.x, ele.position.y, ele.size.x, ele.size.y}},
			)
		}
	case Text_Attributes:
		append(
			&ctx.render_commands,
			Text_Command{
				content = attr.config.content,
				font = ctx.fonts[attr.config.font_index].font,
				font_size = attr.config.font_size,
				spacing = ctx.fonts[attr.config.font_index].spacing,
				line_spacing = attr.config.line_spacing,
				color = attr.config.color,
				wrapped_lines = ctx.wrapped_text_lines[attr.wrapped_text_lines_start:][:attr.wrapped_text_lines_count],
				rect = {ele.position.x, ele.position.y, attr.size.x, attr.size.y},
			},
		)
	}

	for it := child_iter_start(ctx, index); child, child_index in child_iter_next(&it) {
		generate_commands(ctx, child_index)
	}

	if layout_attr, ok := ele.attributes.(Layout_Attributes); ok && layout_attr.config.clip {
		append(&ctx.render_commands, Pop_Clip_Command{})
	}
}

@(private = "file")
detect_mouse :: proc(ctx: ^UI_Context) {
	MOUSE_BTN :: rl.MouseButton.LEFT

	ctx.input.mouse_position = rl.GetMousePosition()
	ctx.input.mouse_state =
		rl.IsMouseButtonPressed(MOUSE_BTN) ? .Pressed : (rl.IsMouseButtonDown(MOUSE_BTN) ? .Down : (rl.IsMouseButtonReleased(MOUSE_BTN) ? .Released : .Hover))

	ctx.input_event.mouse_captured = false
	ctx.input_event.scroll_captured = false
	clear(&ctx.input_event.hovered_elements)
	clear(&ctx.clip.open_clip_stack)

	travel_tree_reverse(ctx, on_down = proc(ctx: ^UI_Context, index: i32) -> (stop: bool) {
			ele := ctx.elements[index]

			layout := ele.attributes.(Layout_Attributes) or_return
			ele_rect := ele_get_rect(ele)

			if layout.config.clip {
				if len(ctx.clip.open_clip_stack) == 0 {
					append(&ctx.clip.open_clip_stack, ele_rect)
				} else {
					append(&ctx.clip.open_clip_stack, intersect_rect(back(ctx.clip.open_clip_stack), ele_rect))
				}
			}

			return
		}, on_up = proc(ctx: ^UI_Context, index: i32) -> (stop: bool) {
			ele := ctx.elements[index]

			layout, ok := ele.attributes.(Layout_Attributes)
			if !ok do return

			defer if layout.config.clip {
				pop(&ctx.clip.open_clip_stack)
			}

			if layout.config.mouse_mode == .Ignore do return

			clipped_rect: rl.Rectangle = {ele.position.x, ele.position.y, ele.size.x, ele.size.y}

			if !ctx.input_event.mouse_captured {
				if len(ctx.clip.open_clip_stack) > 0 {
					clipped_rect = intersect_rect(clipped_rect, back(ctx.clip.open_clip_stack))
				}

				if rect_contains(ctx.input.mouse_position, clipped_rect) {
					switch callbacks := layout.config.callbacks; ctx.input.mouse_state {
					case .Hover:
						if callbacks.on_hover != nil do callbacks.on_hover()
					case .Pressed:
						if callbacks.on_pressed != nil do callbacks.on_pressed()
					case .Down:
						if callbacks.on_down != nil do callbacks.on_down()
					case .Released:
						if callbacks.on_released != nil do callbacks.on_released()
					case .None:
						break
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
					clipped_rect = intersect_rect(back(ctx.clip.open_clip_stack), ele_rect)
				}

				if rect_contains(ctx.input.mouse_position, clipped_rect) {
					content_size: rl.Vector2 = {layout_get_content_size(ctx, index, layout, .X), layout_get_content_size(ctx, index, layout, .Y)}
					min_offset: rl.Vector2 = {-(content_size.x - (ele.size.x - layout_get_pad(layout, .X))), -(content_size.y - (ele.size.y - layout_get_pad(layout, .Y)))}

					cur_scroll := ctx.input_event.scrolls[ele.id]
					pending_offset, is_pending := cur_scroll.pending_offset.?
					next_scroll_offset := is_pending ? pending_offset : cur_scroll.offset + rl.GetMouseWheelMoveV() * 20.0

					next_scroll_offset = {clamp(next_scroll_offset.x, min_offset.x, 0), clamp(next_scroll_offset.y, min_offset.y, 0)}

					ctx.input_event.scrolls[ele.id] = {
						offset         = next_scroll_offset,
						pending_offset = nil,
						content_size   = content_size,
						min_offset     = min_offset,
						view_size      = ele.size,
					}

					ctx.input_event.scroll_captured = true
				}
			}

			stop = ctx.input_event.mouse_captured && ctx.input_event.scroll_captured

			return
		})
}

travel_tree_reverse :: proc(
	ctx: ^UI_Context,
	index: UI_Index = 0,
	on_up: proc(ctx: ^UI_Context, index: UI_Index) -> bool = nil,
	on_down: proc(ctx: ^UI_Context, index: UI_Index) -> bool = nil,
) -> bool {
	if on_down != nil && on_down(ctx, index) do return true
	for node := ctx.elements[index].link.last; node != nil; node = ctx.elements[node.?].link.prev {
		if travel_tree_reverse(ctx, node.?, on_up, on_down) {
			return true
		}
	}
	if on_up != nil && on_up(ctx, index) do return true
	return false
}

@(private = "file")
root_layout :: proc(width: f32, height: f32) -> UI_Element {
	return UI_Element {
		id = 0,
		position = {0, 0},
		size = {width, height},
		limits = {},
		attributes = Layout_Attributes {
			config = UI_Layout_Config {
				child_gap = 8,
				width = Fixed_Size{width},
				height = Fixed_Size{height},
				layout_direction = .Top_To_Bottom,
				padding = pad_all(8),
				background_color = {},
			},
		},
	}
}

@(private = "file")
default_layout :: proc() -> UI_Layout_Config {
	return UI_Layout_Config {
		child_gap = 8,
		width = Fit_Size{},
		height = Fit_Size{},
		layout_direction = .Left_To_Right,
		padding = pad_all(8),
		background_color = {},
		corner_radius = 0,
		border = {thickness = 0, color = rl.BLACK},
	}
}

@(private = "file")
default_text :: proc(ctx: UI_Context) -> UI_Text_Config {
	return UI_Text_Config{font_index = 0, font_size = 16, line_spacing = 4, color = rl.BLACK}
}

@(private = "file")
set_if_set :: #force_inline proc(dest: ^$T, src: Maybe(T)) {
	if v, ok := src.(T); ok {
		dest^ = v
	}
}

@(private = "file")
child_iter_start :: proc(ctx: ^UI_Context, start_index: UI_Index) -> Child_Iter {
	start := ctx.elements[start_index]
	return Child_Iter{ctx = ctx, next = start.link.last == nil ? nil : start_index + 1}
}

@(private = "file")
child_iter_next :: proc(it: ^Child_Iter) -> (child: ^UI_Element, child_index: UI_Index, cond: bool) {
	if it.next == nil {
		return
	}

	{
		child_index = it.next.?
		child = &it.ctx.elements[child_index]
		cond = true
	}

	it.next = child.link.next

	return
}

@(private = "file")
is_grow_layout_or_text :: proc(ele: UI_Element, axis: Axis) -> bool {
	switch attr in ele.attributes {
	case Text_Attributes:
		{
			return true
		}
	case Layout_Attributes:
		{
			if axis == .X {
				_, ok := attr.config.width.(Grow_Size)
				return ok
			} else {
				_, ok := attr.config.height.(Grow_Size)
				return ok
			}
		}
	}
	return false
}

@(private = "file")
layout_get_pad :: proc(layout: Layout_Attributes, axis: Axis) -> f32 {
	return(
		axis == .X ? layout.config.padding.left + layout.config.padding.right : layout.config.padding.top + layout.config.padding.bottom \
	)
}

@(private = "file")
layout_get_content_size :: proc(ctx: ^UI_Context, index: UI_Index, layout: Layout_Attributes, axis: Axis) -> f32 {
	content_size: f32 = 0
	if layout_is_along(layout, axis) {
		child_count: i32 = 0
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			content_size += ele_get_size(child, axis)
			child_count += 1
		}
		content_size += child_count > 0 ? f32(child_count - 1) * layout.config.child_gap : 0
	} else {
		max_size: f32 = 0
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			max_size = max(max_size, ele_get_size(child, axis))
		}
		content_size += max_size
	}
	return content_size
}

@(private = "file")
layout_get_pad_at :: proc(layout: Layout_Attributes, axis: Axis, end: NormalizedEnd) -> f32 {
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
layout_get_mode_from_attr :: proc(layout: Layout_Attributes, axis: Axis) -> Size_Mode {
	return axis == .X ? layout.config.width : layout.config.height
}

@(private = "file")
layout_get_mode_from_ele :: proc(element: UI_Element, axis: Axis) -> Size_Mode {
	layout := element.attributes.(Layout_Attributes)
	return axis == .X ? layout.config.width : layout.config.height
}

@(private = "file")
layout_is_along :: proc(layout: Layout_Attributes, axis: Axis) -> bool {
	return(
		axis == .X ? layout.config.layout_direction == .Left_To_Right : layout.config.layout_direction == .Top_To_Bottom \
	)
}

@(private = "file")
layout_is_across :: proc(layout: Layout_Attributes, axis: Axis) -> bool {
	return(
		axis == .X ? layout.config.layout_direction == .Top_To_Bottom : layout.config.layout_direction == .Left_To_Right \
	)
}

@(private = "file")
layout_get_final_offset :: proc(layout: Layout_Attributes, axis: Axis) -> f32 {
	return axis == .X ? layout.config.offset.x : layout.config.offset.y
}

@(private = "file")
ele_set_size :: proc(element: ^UI_Element, value: f32, axis: Axis) {
	if axis == .X do element.size.x = value
	else do element.size.y = value
}

@(private = "file")
ele_set_min :: proc(element: ^UI_Element, value: f32, axis: Axis) {
	if axis == .X do element.limits.x.min = value
	else do element.limits.y.min = value
}

@(private = "file")
ele_set_max :: proc(element: ^UI_Element, value: f32, axis: Axis) {
	if axis == .X do element.limits.x.max = value
	else do element.limits.y.max = value
}

@(private = "file")
ele_get_size :: proc(element: ^UI_Element, axis: Axis) -> f32 {
	return axis == .X ? element.size.x : element.size.y
}

@(private = "file")
ele_get_min :: proc(element: ^UI_Element, axis: Axis) -> f32 {
	return axis == .X ? element.limits.x.min.? or_else 0 : element.limits.y.min.? or_else 0
}

@(private = "file")
ele_get_max :: proc(element: ^UI_Element, axis: Axis) -> Maybe(f32) {
	return axis == .X ? element.limits.x.max : element.limits.y.max
}

@(private = "file")
ele_get_lims :: proc(element: ^UI_Element, axis: Axis) -> UI_Axis_Limits {
	return axis == .X ? element.limits.x : element.limits.y
}

@(private = "file")
ele_set_pos :: proc(element: ^UI_Element, value: f32, axis: Axis) {
	if axis == .X do element.position.x = value
	else do element.position.y = value
}

@(private = "file")
ele_get_pos :: proc(element: ^UI_Element, axis: Axis) -> f32 {
	if axis == .X do return element.position.x
	else do return element.position.y
}

@(private = "file")
ele_get_rect :: #force_inline proc(element: UI_Element) -> rl.Rectangle {
	return {x = element.position.x, y = element.position.y, width = element.size.x, height = element.size.y}
}

@(private = "file")
text_get_preferred :: proc(text_attr: Text_Attributes, axis: Axis) -> f32 {
	return axis == .X ? text_attr.preferred_size.x : text_attr.preferred_size.y
}

@(private = "file")
align_get_offset :: proc(alignment: rl.Vector2, axis: Axis) -> f32 {
	return axis == .X ? alignment.x : alignment.y
}

BORDER_DEFAULT: Border_Config : {thickness = 0, color = {0, 0, 0, 255}}

@(require_results, private = "file")
draw_layout :: proc(
	width: Sizing_Axis = {mode = Fit_Size{}},
	height: Sizing_Axis = {mode = Fit_Size{}},
	padding: Layout_Padding = {8, 8, 8, 8},
	child_gap: f32 = 8,
	layout_direction: Layout_Direction = .Left_To_Right,
	child_alignment: Alignment = {x = .Left, y = .Top},
	background_color: rl.Color = {},
	corner_radius: f32 = 8,
	border: Border_Config = BORDER_DEFAULT,
	mouse_mode: UI_Layout_Mouse_Mode = .Capture,
	callbacks: UI_Layout_Mouse_Event_Callbacks = {},
	clip: bool = false,
	scroll: bool = false,
	ignore_scroll: bool = false,
	float: UI_Float = Float_None{},
	offset: rl.Vector2 = {},
) -> bool {
	return open_layout(
		builder.current_context,
		builder.last_id,
		{
			width = width.mode,
			height = height.mode,
			padding = padding,
			child_gap = child_gap,
			layout_direction = layout_direction,
			child_alignment = get_alignment_offset(child_alignment),
			background_color = background_color,
			corner_radius = corner_radius,
			mouse_mode = mouse_mode,
			// debug
			border = {thickness = 2, color = rl.ColorBrightness(background_color, -0.15)},
			callbacks = callbacks,
			clip = clip,
			scroll = scroll,
			float = float,
			ignore_scroll = ignore_scroll,
			offset = offset,
		},
		{x = {min = width.min, max = width.max}, y = {min = height.min, max = height.max}},
	)
}

@(private = "file")
close_layout_deffered :: proc() {
	close_layout(builder.current_context)
}

@(private = "file")
draw_text :: proc(
	content: string,
	font_index: Font_Index = 0,
	font_size: f32 = 16,
	color: rl.Color = {0, 0, 0, 255},
	line_spacing: f32 = 8,
	alignment: Alignment = {x = .Left, y = .Top},
	loc := #caller_location,
) -> bool {
	open_text(
		builder.current_context,
		builder.last_id,
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

grow :: #force_inline proc(min: Maybe(f32) = nil, max: Maybe(f32) = nil) -> Sizing_Axis {
	return {mode = Grow_Size{}, min = min, max = max}
}

fixed :: #force_inline proc(value: f32 = 0, min: Maybe(f32) = nil, max: Maybe(f32) = nil) -> Sizing_Axis {
	return {mode = Fixed_Size{value = value}, min = min, max = max}
}

fit :: #force_inline proc(min: Maybe(f32) = nil, max: Maybe(f32) = nil) -> Sizing_Axis {
	return {mode = Fit_Size{}, min = min, max = max}
}

percent :: #force_inline proc(value: f32, min: Maybe(f32) = nil, max: Maybe(f32) = nil) -> Sizing_Axis {
	return {mode = Percent_Size{value = value}, min = min, max = max}
}

pad_all :: #force_inline proc(value: f32) -> Layout_Padding {
	return Layout_Padding{value, value, value, value}
}

mouse_state :: proc() -> UI_Mouse_State {
	return get_layout_mouse_state_by_id(builder.current_context^, builder.last_id)
}

mouse_state_by_id :: proc(id: u32) -> UI_Mouse_State {
	return get_layout_mouse_state_by_id(builder.current_context^, id)
}

current_scroll_data :: proc() -> UI_Scroll_Data {
	return get_layout_scroll_data(builder.current_context^)
}

set_scroll_offset :: proc(scroll: rl.Vector2) {
	set_layout_scroll_offset(builder.current_context, scroll)
}

// Internal ultilities
@(private = "file")
set_layout_scroll_offset :: proc(ctx: ^UI_Context, new_scroll: rl.Vector2) {
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
get_layout_mouse_state_by_id :: proc(ctx: UI_Context, id: u32) -> UI_Mouse_State {
	for ele_id in ctx.input_event.hovered_elements {
		if ele_id == id {
			return ctx.input.mouse_state
		}
	}
	return .None
}

@(private = "file")
get_alignment_offset :: proc(alignment: Alignment) -> rl.Vector2 {
	offset: rl.Vector2
	switch variant in alignment.x {
	case Alignment_X:
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
	case Alignment_Y:
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

@(private, require_results)
intersect_rect :: proc(a, b: rl.Rectangle) -> (rl.Rectangle, bool) #optional_ok {
	left := max(a.x, b.x)
	top := max(a.y, b.y)
	right := min(a.x + a.width, b.x + b.width)
	bottom := min(a.y + a.height, b.y + b.height)

	width := right - left
	height := bottom - top

	return {x = left, y = top, width = max(width, 0), height = max(height, 0)}, width > 0 && height > 0
}

@(private, require_results)
rect_contains :: proc(p: rl.Vector2, rec: rl.Rectangle) -> bool {
	return p.x >= rec.x && p.x <= rec.x + rec.width && p.y >= rec.y && p.y <= rec.y + rec.height
}

@(private, require_results)
back :: proc(arr: [dynamic]$T) -> T {
	return arr[len(arr) - 1]
}

auto_id_hash :: proc(parent_hash: u32, loc: runtime.Source_Code_Location) -> u32 {
	line := transmute([4]u8)loc.line
	column := transmute([4]u8)loc.column
	h: u32 = parent_hash
	h = hash.adler32(transmute([]u8)loc.file_path, h)
	h = hash.adler32(transmute([]u8)line[:], h)
	h = hash.adler32(transmute([]u8)column[:], h)
	return h
}

@(require_results)
global_id :: proc(id: string) -> u32 {
	id := hash.adler32(transmute([]u8)id)

	return id
}

@(require_results)
local_id :: proc(id: string) -> u32 {
	parent_hash := builder.current_context.elements[back(builder.current_context.open_layout_stack)].id
	id := hash.adler32(transmute([]u8)id, parent_hash)

	return id
}

@(require_results)
family_id :: proc(id: string, owner: string) -> u32 {
	parent_hash := builder.current_context.elements[back(builder.current_context.open_layout_stack)].id
	id := hash.adler32(transmute([]u8)id, parent_hash)

	return id
}

@(private = "file")
declare_id :: proc(id: Maybe(u32) = nil, loc := #caller_location) {
	index := i32(len(builder.current_context.elements))

	new_id: u32
	if id == nil {
		parent_hash := builder.current_context.elements[back(builder.current_context.open_layout_stack)].id
		new_id = auto_id_hash(parent_hash, loc)
		push_and_dedupe_id(builder.current_context, index, new_id)

	} else {
		new_id = id.?
		push_id(builder.current_context, index, new_id)
	}

	builder.last_id = new_id
}

UI_Element_Builder :: struct($T: typeid) {
	config: T,
}


@(deferred_none = end_declare_layout)
layout :: proc(id: Maybe(u32) = nil, loc := #caller_location) -> UI_Element_Builder(type_of(draw_layout)) {
	declare_id(id, loc)
	return {draw_layout}
}

text :: proc(id: Maybe(u32) = nil, loc := #caller_location) -> UI_Element_Builder(type_of(draw_text)) {
	declare_id(id, loc)
	return {draw_text}
}


@(private = "file")
end_declare_layout :: proc() {
	close_layout(builder.current_context)
}


last_id :: proc() -> u32 {
	return builder.last_id
}
