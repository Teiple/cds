package ui

import "core:fmt"
import "core:math"
import "core:os"
import "core:unicode/utf8"
import rl "vendor:raylib"

MAX_CHILD_COUNT :: 50
WORD_SEPARATION_CHARS :: [?]rune{' ', '\t', '\v', '\f'}

@(private = "file")
current_context: ^UI_Context

Axis :: enum {
	X,
	Y,
}

UI_MouseState :: enum {
	None,
	Pressed,
	Down,
	Released,
	Hover,
}

UI_Input :: struct {
	mouse_position: rl.Vector2,
	mouse_state:    UI_MouseState,
	scroll:         rl.Vector2,
}

UI_InputEvent :: struct {
	hovered_element: UI_Index,
}

UI_Measure_Text :: proc(text: UI_Text_Config, font_info: UI_Font) -> (width: f32)

Render_Command :: union {
	Rect_Command,
	Text_Command,
	Push_Clip_Command,
	Pop_Clip_Command,
}

Rect_Command :: struct {
	rect:          rl.Rectangle,
	color:         rl.Color,
	corner_radius: rl.Vector4,
	shadow:        Shadow_Config,
	border:        Border_Config,
	rect_shader:   Rect_Shader,
}

Text_Command :: struct {
	content:       string,
	font:          rl.Font,
	font_size:     f32,
	spacing:       f32,
	line_spacing:  f32,
	color:         rl.Color,
	position:      rl.Vector2,
	wrapped_lines: []string,
	shader:        rl.Shader,
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


UI_Context :: struct {
	elements:           [dynamic]UI_Element,
	open_element_stack: [dynamic]UI_Index,
	growable_buffer:    [dynamic]UI_Index,
	wrapped_text_lines: [dynamic]string,
	render_commands:    [dynamic]Render_Command,
	measure_text:       UI_Measure_Text,
	fonts:              []UI_Font,
	font_shader:        rl.Shader,
	rect_shader:        Rect_Shader,
	input:              UI_Input,
	input_event:        UI_InputEvent,
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
	x: Alignment_X,
	y: Alignment_Y,
}

NormalizedAlignment :: enum {
	Start,
	Center,
	End,
}

NormalizedEnd :: enum {
	Start,
	End,
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

UI_Layout_Declare :: struct {
	id:               string,
	width:            Maybe(Sizing_Axis),
	height:           Maybe(Sizing_Axis),
	padding:          Maybe(Layout_Padding),
	child_gap:        Maybe(f32),
	layout_direction: Maybe(Layout_Direction),
	child_alignment:  Maybe(Alignment),
	background_color: Maybe(rl.Color),
	corner_radius:    Maybe(f32),
	border:           Maybe(Border_Declare),
	shadow:           Maybe(Shadow_Declare),
}

UI_Border_Declare :: struct {
	width: Maybe(f32),
	color: Maybe(rl.Color),
}

UI_Text_Declare :: struct {
	id:           string,
	content:      Maybe(string),
	font_index:   Font_Index,
	font_size:    Maybe(f32),
	spacing:      Maybe(f32),
	color:        Maybe(rl.Color),
	line_spacing: Maybe(f32),
	alignment:    Maybe(Alignment),
}

Border_Config :: struct {
	thickness: f32,
	color:     rl.Color,
}

Border_Declare :: struct {
	thickness: Maybe(f32),
	color:     Maybe(rl.Color),
}

Shadow_Config :: struct {
	color:  rl.Color,
	radius: f32,
	offset: rl.Vector2,
	scale:  f32,
}

Shadow_Declare :: struct {
	color:  Maybe(rl.Color),
	radius: Maybe(f32),
	offset: Maybe(rl.Vector2),
	scale:  Maybe(f32),
}

UI_Layout_Config :: struct {
	width:            Size_Mode,
	height:           Size_Mode,
	padding:          Layout_Padding,
	child_gap:        f32,
	layout_direction: Layout_Direction,
	child_alignment:  Alignment,
	background_color: rl.Color,
	corner_radius:    f32,
	border:           Border_Config,
	shadow:           Shadow_Config,
}

UI_Text_Config :: struct {
	content:      string,
	font_index:   Font_Index,
	font_size:    f32,
	color:        rl.Color,
	line_spacing: f32,
	alignment:    Alignment,
}

UI_Element_Declare :: union {
	UI_Layout_Declare,
	UI_Text_Declare,
}

UI_Element :: struct {
	id:           string,
	position:     rl.Vector2,
	size:         rl.Vector2,
	parent:       UI_Index,
	index:        UI_Index, // index in the flat elements array
	subtree_size: i32, // number of nodes in this subtree (set on close)
	limits:       UI_Limits,
	attributes:   union {
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
	wrapped_text_lines_start: i32,
	wrapped_text_lines_count: i32,
}

Child_Iter :: struct {
	ctx:     ^UI_Context,
	current: UI_Index, // next child index to visit
	end:     UI_Index, // exclusive end of this node's subtree
}

@(private = "file")
open_layout :: proc(ctx: ^UI_Context, declare: UI_Layout_Declare) -> bool {
	parent := ctx.open_element_stack[len(ctx.open_element_stack) - 1]
	index := UI_Index(len(ctx.elements))

	config, limits := parse_layout_declare(default_layout(), declare)
	ui_ele := UI_Element {
		id = declare.id,
		parent = parent,
		index = i32(len(ctx.elements)), // set before append
		attributes = Layout_Attributes{config = config, element = index},
		limits = limits,
		// layout sets its tree size when close
	}

	append(&ctx.elements, ui_ele)
	append(&ctx.open_element_stack, index)
	return true
}

@(private = "file")
open_text :: proc(ctx: ^UI_Context, declare: UI_Text_Declare) {
	parent_idx := ctx.open_element_stack[len(ctx.open_element_stack) - 1]
	index := UI_Index(len(ctx.elements))

	config, limits := parse_text_declare(ctx^, default_text(ctx^), declare)
	ui_ele := UI_Element {
		id = declare.id,
		parent = parent_idx,
		index = i32(len(ctx.elements)),
		attributes = Text_Attributes{config = config, element = index},
		limits = limits,
		subtree_size = 1,
	}

	append(&ctx.elements, ui_ele)
	calculate_text_width(ctx, index)
}


@(private = "file")
close_layout :: proc(ctx: ^UI_Context) {
	index := pop(&ctx.open_element_stack)
	ele := &ctx.elements[index]

	// Compute subtree size: everything appended after this node is in its subtree
	ele.subtree_size = i32(len(ctx.elements)) - ele.index

	fit_sizing(ctx, index, .X)
}

@(private = "file")
calculate_text_width :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := &ctx.elements[index]
	text_attr, ok := &current.attributes.(Text_Attributes)
	if !ok do return

	// prefered size
	text_attr.preferred_size.x = ctx.measure_text(text_attr.config, ctx.fonts[text_attr.config.font_index])
	text_attr.preferred_size.y = text_attr.config.font_size

	current.size.x = text_attr.preferred_size.x

	// min size is the longest english word in the sentence
	{
		content := text_attr.config.content
		config := text_attr.config
		word_start := 0
		largest_word_width := f32(0)

		byte_index := 0
		for byte_index < len(content) {
			whitespace_start := byte_index

			// Skip whitespace / find word start.
			for byte_index < len(content) {
				r, size := utf8.decode_rune(content[byte_index:])
				if !is_separator(r) {
					break
				}
				byte_index += size
			}

			word_start = byte_index

			// Find end of word.
			for byte_index < len(content) {
				r, size := utf8.decode_rune(content[byte_index:])
				if is_separator(r) {
					break
				}
				byte_index += size
			}

			word_end := byte_index

			if word_start == word_end {
				// Only whitespace remains.
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
calculate_layout_height :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := &ctx.elements[index]
	if layout, ok := current.attributes.(Layout_Attributes); ok {
		if mode, ok := layout.config.height.(Fixed_Size); ok {
			current.size.y = mode.value
		}
	}
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

	ele_set_min(current, max(ele_get_min(current, axis), children_min_size), axis)
	ele_set_size(current, clamp_element_size(children_size, ele_get_lims(current, axis)), axis)
}

@(private = "file")
fit_sizing_heights_tree :: proc(ctx: ^UI_Context, index: UI_Index) {
	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		fit_sizing_heights_tree(ctx, child.index)
	}

	fit_sizing(ctx, index, .Y)
}

@(private = "file")
grow_and_shrink_sizing :: proc(ctx: ^UI_Context, index: UI_Index, axis: Axis) {
	// Grow and Shrink phases, not gonna merge them because of readability
	current := &ctx.elements[index]
	layout, ok := current.attributes.(Layout_Attributes)
	if !ok || current.subtree_size <= 1 do return

	// Content space available to children.
	available := ele_get_size(current, axis) - layout_get_pad(layout, axis)

	// Cross-axis: grow children simply fill the available space
	if layout_is_across(layout, axis) {
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			if is_grow_layout_or_text(child^, axis) {
				ele_set_size(child, clamp_element_size(available, ele_get_lims(child, axis)), axis)
			}
		}
		return
	}

	// Along-axis: distribute remaining/overshoot space among grow children
	growables := ctx.growable_buffer
	clear(&growables)
	defer clear(&growables)

	remaining := available
	child_count := 0

	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		remaining -= ele_get_size(child, axis)

		if is_grow_layout_or_text(child^, axis) {
			append(&growables, child.index)
		}

		child_count += 1
	}

	if child_count > 1 {
		remaining -= f32(child_count - 1) * layout.config.child_gap
	}

	if len(growables) == 0 do return

	growable_count := len(growables)

	// Grow phase
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
					unordered_remove(&growables, i)
					continue
				}

				ele_set_size(child, new_size, axis)
				remaining -= size_to_add
			}

			i += 1
		}
	}

	// Hacking the growables array back to original size
	non_zero_resize(&growables, growable_count)

	// Shrink phase
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
					unordered_remove(&shrinkables, i)
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
grow_and_shrink_sizing_tree :: proc(ctx: ^UI_Context, index: UI_Index, axis: Axis) {
	grow_and_shrink_sizing(ctx, index, axis)
	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		grow_and_shrink_sizing_tree(ctx, child.index, axis)
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
			} else {
				ele.size.y = config.font_size
			}
			ele.limits.y.min = ele.size.y
		}

		byte_index := 0

		for byte_index < len(content) {
			whitespace_start := byte_index

			// Skip whitespace / find word start.
			for byte_index < len(content) {
				r, size := utf8.decode_rune(content[byte_index:])
				if !is_separator(r) {
					break
				}
				byte_index += size
			}

			word_start := byte_index

			// Find end of word.
			for byte_index < len(content) {
				r, size := utf8.decode_rune(content[byte_index:])
				if is_separator(r) {
					break
				}
				byte_index += size
			}

			word_end := byte_index

			if word_start == word_end {
				// Only whitespace remains.
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
calculate_position :: proc(ctx: ^UI_Context, index: UI_Index, axis: Axis) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(Layout_Attributes)
	if !ok {
		text_attr, ok := current.attributes.(Text_Attributes)
		assert(ok)

		if ele_get_size(current, axis) > text_get_preferred(text_attr, axis) {
			remaining := ele_get_size(current, axis) - text_get_preferred(text_attr, axis)

			switch align_get_norm(text_attr.config.alignment, axis) {
			case .Start:
				break
			case .Center:
				ele_set_pos(current, ele_get_pos(current, axis) + remaining * 0.5, axis)
			case .End:
				ele_set_pos(current, ele_get_pos(current, axis) + remaining, axis)
			}
		}

		return
	}

	offset := ele_get_pos(current, axis) + layout_get_pad_at(layout, axis, .Start)

	if layout_is_along(layout, axis) {
		// Find the remaining size
		remaining := ele_get_size(current, axis) - layout_get_pad(layout, axis)

		child_count := 0
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			remaining -= ele_get_size(child, axis)
			child_count += 1
		}

		if child_count > 0 {
			remaining -= f32(child_count - 1) * layout.config.child_gap
		}

		switch align_get_norm(layout.config.child_alignment, axis) {
		case .Start:
			break
		case .Center:
			offset += remaining * 0.5
		case .End:
			offset += remaining
		}
	}

	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		ele_set_pos(child, offset, axis)

		if layout_is_across(layout, axis) {
			// Find the remaining size
			remaining := ele_get_size(current, axis) - layout_get_pad(layout, axis) - ele_get_size(child, axis)

			switch align_get_norm(layout.config.child_alignment, axis) {
			case .Start:
				break
			case .Center:
				ele_set_pos(child, ele_get_pos(child, axis) + remaining * 0.5, axis)
			case .End:
				ele_set_pos(child, ele_get_pos(child, axis) + remaining, axis)
			}
		} else {
			offset += ele_get_size(child, axis) + layout.config.child_gap
		}

		calculate_position(ctx, child.index, axis)
	}
}

ui_debug_draw_tree :: proc(ctx: ^UI_Context, index: UI_Index = 0, cur_level: i32 = 1) {
	current := ctx.elements[index]

	for i in 0 ..< cur_level - 1 {
		fmt.print(" . ")
	}

	layout, ok := current.attributes.(Layout_Attributes)

	fmt.printf(
		"%v (%v) %vx%v (pre=%v, sub=%v)",
		current.id,
		ctx.elements[current.parent].id,
		current.size.x,
		current.size.y,
		current.index,
		current.subtree_size,
	)

	if ok {
		fmt.println(layout.config.layout_direction == .Left_To_Right ? " LTR" : " TTB")
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			ui_debug_draw_tree(ctx, child.index, cur_level + 1)
		}
	} else {
		fmt.println()
	}
}

@(private = "file")
load_font :: proc(base_size: f32, spacing: f32, font_path: cstring) -> UI_Font {
	assert(os.exists(string(font_path)))

	font := rl.LoadFontEx(font_path, i32(base_size), nil, 0)

	assert(rl.IsFontValid(font))

	rl.GenTextureMipmaps(&font.texture)
	rl.SetTextureFilter(font.texture, rl.TextureFilter.BILINEAR)

	return {font = font, spacing = spacing}
}

@(private = "file")
load_font_shader :: proc(shader_path: cstring) -> rl.Shader {
	assert(os.exists(string(shader_path)))

	return rl.LoadShader(nil, shader_path)
}


context_make :: proc(
	measure_text_proc: UI_Measure_Text,
	font_configs: []UI_Font_Config,
	font_shader: cstring,
) -> UI_Context {
	fonts := make([dynamic]UI_Font, 0, 16)
	for config in font_configs {
		append(&fonts, load_font(config.base_size, config.spacing, config.font_path))
	}

	font_shader := load_font_shader(font_shader)
	rect_shader := load_rect_shader()

	return UI_Context {
		elements = make([dynamic]UI_Element, 0, 500),
		open_element_stack = make([dynamic]UI_Index, 0, 50),
		render_commands = make([dynamic]Render_Command, 0, 500),
		growable_buffer = make([dynamic]UI_Index, 0, 500),
		wrapped_text_lines = make([dynamic]string, 0, 500),
		measure_text = measure_text_proc,
		fonts = fonts[:],
		font_shader = font_shader,
		rect_shader = rect_shader,
	}
}

context_delete :: proc(ctx: UI_Context) {
	delete(ctx.elements)
	delete(ctx.open_element_stack)
	delete(ctx.render_commands)
	delete(ctx.growable_buffer)
	delete(ctx.wrapped_text_lines)

	for f in ctx.fonts {
		rl.UnloadFont(f.font)
	}
	rl.UnloadShader(ctx.font_shader)

	delete(ctx.fonts)

	rl.UnloadShader(ctx.rect_shader.shader)
}

@(require_results, deferred_in_out = end_layout)
begin_layout :: proc(ctx: ^UI_Context, window_width: f32, window_height: f32) -> bool {
	current_context = ctx

	clear(&ctx.elements)
	clear(&ctx.open_element_stack)

	// Create the root element at index 0
	append(&ctx.elements, root_layout(window_width, window_height))

	// Set its preorder_idx explicitly (it's 0)
	ctx.elements[0].index = 0
	append(&ctx.open_element_stack, 0)

	clear(&ctx.render_commands)
	clear(&ctx.growable_buffer)
	clear(&ctx.wrapped_text_lines)

	return true
}


@(private = "file")
end_layout :: proc(ctx: ^UI_Context, _: f32, _: f32, ok: bool) {
	if !ok do return

	// Close the root – this computes sizes and subtree_size
	close_layout(ctx)

	// Top down, calculate grow sizing widths
	grow_and_shrink_sizing_tree(ctx, 0, .X)
	wrap_texts(ctx)

	// Calculate heights
	fit_sizing_heights_tree(ctx, 0)
	grow_and_shrink_sizing_tree(ctx, 0, .Y)

	// Compute positions
	calculate_position(ctx, 0, .X)
	calculate_position(ctx, 0, .Y)

	// Mouse input, forward to next frame
	detect_mouse(ctx)

	// Generate render commands
	clear(&ctx.render_commands)
	for ele in ctx.elements {
		switch attr in ele.attributes {
		case Layout_Attributes:
			{
				append(
					&ctx.render_commands,
					Rect_Command {
						rect = {x = ele.position.x, y = ele.position.y, width = ele.size.x, height = ele.size.y},
						color = attr.config.background_color,
						corner_radius = attr.config.corner_radius,
						border = attr.config.border,
						shadow = attr.config.shadow,
						rect_shader = ctx.rect_shader,
					},
				)
			}
		case Text_Attributes:
			{
				append(
					&ctx.render_commands,
					Text_Command {
						content = attr.config.content,
						font_size = attr.config.font_size,
						spacing = ctx.fonts[attr.config.font_index].spacing,
						line_spacing = attr.config.line_spacing,
						font = ctx.fonts[attr.config.font_index].font,
						position = ele.position,
						wrapped_lines = ctx.wrapped_text_lines[attr.wrapped_text_lines_start:][:attr.wrapped_text_lines_count],
						color = attr.config.color,
						shader = ctx.font_shader,
					},
				)
			}
		}

	}

	// Clean up
	clear(&ctx.elements)
	clear(&ctx.open_element_stack)
}

detect_mouse :: proc(ctx: ^UI_Context) {
	ctx.input = {
		mouse_position = rl.GetMousePosition(),
		mouse_state    = rl.IsMouseButtonPressed(rl.MouseButton.LEFT) ? .Pressed : (rl.IsMouseButtonDown(rl.MouseButton.LEFT) ? .Down : (rl.IsMouseButtonReleased(rl.MouseButton.LEFT) ? .Released : .Hover)),
	}

	ctx.input_event = {}

	travel_bottom_up(ctx, proc(ctx: ^UI_Context, index: i32) {
		if ctx.input_event.hovered_element > 0 do return
		ele := ctx.elements[index]

		if _, ok := ele.attributes.(Layout_Attributes); !ok do return

		mouse_position := ctx.input.mouse_position

		is_rect_hovered := mouse_position.x >= ele.position.x && mouse_position.x <= ele.position.x + ele.size.x && mouse_position.y >= ele.position.y && mouse_position.y <= ele.position.y + ele.size.y

		if is_rect_hovered {
			ctx.input_event.hovered_element = index
		}
	})
}

travel_bottom_up :: proc(
	ctx: ^UI_Context,
	do_proc: proc(ctx: ^UI_Context, index: UI_Index) = nil,
	index: UI_Index = 0,
) {
	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		travel_bottom_up(ctx, do_proc, child.index)
	}

	if do_proc != nil do do_proc(ctx, index)
}

@(private = "file")
root_layout :: proc(width: f32, height: f32) -> UI_Element {
	return UI_Element {
		id = "root",
		parent = 0,
		position = {0, 0},
		size = {width, height},
		limits = {}, // no limits
		attributes = Layout_Attributes {
			config = UI_Layout_Config {
				child_alignment = {x = .Left, y = .Top},
				child_gap = 8,
				width = Fixed_Size{width},
				height = Fixed_Size{height},
				layout_direction = .Top_To_Bottom,
				padding = pad_all(16),
				background_color = rl.BLUE,
			},
		},
	}
}

@(private = "file")
default_layout :: proc() -> UI_Layout_Config {
	return UI_Layout_Config {
		child_alignment = {x = .Left, y = .Top},
		child_gap = 8,
		width = Fit_Size{},
		height = Fit_Size{},
		layout_direction = .Left_To_Right,
		padding = pad_all(8),
		background_color = rl.RAYWHITE,
		corner_radius = 8,
		border = {thickness = 0, color = rl.BLACK},
		shadow = {radius = 4, scale = 1.0, color = rl.ColorAlpha(rl.BLACK, 0.5), offset = {4, -4}},
	}
}

@(private = "file")
default_text :: proc(ctx: UI_Context) -> UI_Text_Config {
	return UI_Text_Config {
		font_index = 0,
		font_size = f32(ctx.fonts[0].font.baseSize),
		line_spacing = 4,
		color = rl.BLACK,
		alignment = {.Left, .Top},
	}
}

ui_get_id :: proc(ctx: UI_Context, index: UI_Index) -> string {
	return ctx.elements[index].id
}

@(private = "file")
set_if_set :: #force_inline proc(dest: ^$T, src: Maybe(T)) {
	if v, ok := src.(T); ok {
		dest^ = v
	}
}

@(private = "file")
parse_layout_declare :: proc(
	default_config: UI_Layout_Config,
	declare: UI_Layout_Declare,
) -> (
	UI_Layout_Config,
	UI_Limits,
) {
	config := default_config
	width, height: Sizing_Axis

	set_if_set(&width, declare.width)
	set_if_set(&height, declare.height)

	config.width = width.mode
	config.height = height.mode

	limits := UI_Limits {
		x = {min = width.min, max = width.max},
		y = {min = height.min, max = height.max},
	}

	set_if_set(&config.padding, declare.padding)
	set_if_set(&config.child_gap, declare.child_gap)
	set_if_set(&config.layout_direction, declare.layout_direction)
	set_if_set(&config.child_alignment, declare.child_alignment)
	set_if_set(&config.background_color, declare.background_color)
	set_if_set(&config.corner_radius, declare.corner_radius)

	if border, ok := declare.border.(Border_Declare); ok {
		set_if_set(&config.border.thickness, border.thickness)
		set_if_set(&config.border.color, border.color)
	}

	if shadow, ok := declare.shadow.(Shadow_Declare); ok {
		set_if_set(&config.shadow.radius, shadow.radius)
		set_if_set(&config.shadow.scale, shadow.scale)
		set_if_set(&config.shadow.offset, shadow.offset)
		set_if_set(&config.shadow.color, shadow.color)
	}

	return config, limits
}

@(private = "file")
parse_text_declare :: proc(
	ctx: UI_Context,
	default_config: UI_Text_Config,
	declare: UI_Text_Declare,
) -> (
	UI_Text_Config,
	UI_Limits,
) {
	config := default_config

	set_if_set(&config.content, declare.content)
	set_if_set(&config.font_size, declare.font_size)
	set_if_set(&config.font_index, declare.font_index)
	set_if_set(&config.color, declare.color)
	set_if_set(&config.line_spacing, declare.line_spacing)
	set_if_set(&config.alignment, declare.alignment)

	return config, UI_Limits{}
}


@(private = "file")
child_iter_start :: proc(ctx: ^UI_Context, start_index: UI_Index) -> Child_Iter {
	start := ctx.elements[start_index]
	return Child_Iter{ctx = ctx, current = start.index + 1, end = start.index + start.subtree_size}
}

@(private = "file")
child_iter_next :: proc(it: ^Child_Iter) -> (child: ^UI_Element, cond: bool) {
	if it.current >= it.end {
		return nil, false
	}
	child = &it.ctx.elements[it.current]
	it.current += child.subtree_size // jump to next sibling
	return child, true
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

// Axis independant internal ultilities
// Layout
@(private = "file")
layout_get_pad :: proc(layout: Layout_Attributes, axis: Axis) -> f32 {
	return(
		axis == .X ? layout.config.padding.left + layout.config.padding.right : layout.config.padding.top + layout.config.padding.bottom \
	)
}

@(private = "file")
layout_get_pad_at :: proc(layout: Layout_Attributes, axis: Axis, end: NormalizedEnd) -> f32 {
	return(
		axis == .X ? (end == .Start ? layout.config.padding.left : layout.config.padding.right) : (end == .Start ? layout.config.padding.top : layout.config.padding.bottom) \
	)
}

@(private = "file")
layout_get_mode :: proc(layout: Layout_Attributes, axis: Axis) -> Size_Mode {
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

// Elements
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

// Text
@(private = "file")
text_get_preferred :: proc(text_attr: Text_Attributes, axis: Axis) -> f32 {
	return axis == .X ? text_attr.preferred_size.x : text_attr.preferred_size.y
}

// Alignment
@(private = "file")
align_get_norm :: proc(aligment: Alignment, axis: Axis) -> NormalizedAlignment {
	if axis == .X {
		switch aligment.x {
		case .Left:
			return .Start
		case .Center:
			return .Center
		case .Right:
			return .End
		}
	} else {
		switch aligment.y {
		case .Top:
			return .Start
		case .Center:
			return .Center
		case .Bottom:
			return .End
		}
	}
	return .Start
}

// Public layout declaration ultilities
// Elements
@(deferred_none = close_layout_deffered)
layout :: proc(declare: UI_Layout_Declare) -> bool {
	return open_layout(current_context, declare)
}

@(private = "file")
close_layout_deffered :: proc() {
	close_layout(current_context)
}

text :: proc(declare: UI_Text_Declare) -> bool {
	open_text(current_context, declare)
	return true
}

// Config shorthands
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

pad :: #force_inline proc(value: Layout_Padding) -> Layout_Padding {
	return value
}

align :: #force_inline proc(value: Alignment) -> Alignment {
	return value
}

border :: #force_inline proc(value: Border_Declare) -> Border_Declare {
	return value
}

// Inout queries
// Input

mouse_state :: proc() -> UI_MouseState {
	return get_layout_mouse_state(current_context^)
}

mouse_state_ahead :: proc() -> UI_MouseState {
	return get_layout_mouse_state_ahead(current_context^)
}

@(private = "file")
get_layout_mouse_state :: proc(ctx: UI_Context) -> UI_MouseState {
	open_ele := ctx.open_element_stack[len(ctx.open_element_stack) - 1]
	return ctx.input_event.hovered_element == open_ele ? ctx.input.mouse_state : .None
}

@(private = "file")
get_layout_mouse_state_ahead :: proc(ctx: UI_Context) -> UI_MouseState {
	return ctx.input_event.hovered_element == UI_Index(len(ctx.elements)) ? ctx.input.mouse_state : .None
}

// Shapes
Rect_Shader :: struct {
	shader: rl.Shader,
	locs:   struct {
		shadow_scale:         f32,
		border_thickness:     f32,
		rectangle_loc:        i32,
		radius_loc:           i32,
		color_loc:            i32,
		shadow_radius_loc:    i32,
		shadow_offset_loc:    i32,
		shadow_scale_loc:     i32,
		shadow_color_loc:     i32,
		border_thickness_loc: i32,
		border_color_loc:     i32,
	},
}

load_rect_shader :: proc() -> Rect_Shader {
	shader := rl.LoadShader("./shaders/base.vs", "./shaders/rounded_rect.fs")
	return {
		shader = shader,
		locs = {
			rectangle_loc = rl.GetShaderLocation(shader, "rectangle"),
			radius_loc = rl.GetShaderLocation(shader, "radius"),
			color_loc = rl.GetShaderLocation(shader, "color"),
			shadow_radius_loc = rl.GetShaderLocation(shader, "shadowRadius"),
			shadow_offset_loc = rl.GetShaderLocation(shader, "shadowOffset"),
			shadow_scale_loc = rl.GetShaderLocation(shader, "shadowScale"),
			shadow_color_loc = rl.GetShaderLocation(shader, "shadowColor"),
			border_thickness_loc = rl.GetShaderLocation(shader, "borderThickness"),
			border_color_loc = rl.GetShaderLocation(shader, "borderColor"),
		},
	}
}
