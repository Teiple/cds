package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:unicode/utf8"
import rl "vendor:raylib"

MAX_CHILD_COUNT :: 50
WORD_SEPARATION_CHARS :: [?]rune{' ', '\t', '\v', '\f'}

@(private)
current_context: ^UI_Context

Axis :: enum {
	X,
	Y,
}

UI_Input :: struct {
	mouse_position:      rl.Vector2,
	mouse_pressed:       bool,
	mouse_just_pressed:  bool,
	mouse_just_released: bool,
	scroll:              rl.Vector2,
}

UI_TextMeasurer :: proc(text: UI_TextConfig) -> (width: f32)

Render_Command :: union {
	Rect_Command,
	Text_Command,
	Push_Clip_Command,
	Pop_Clip_Command,
}

Rect_Command :: struct {
	using rect: rl.Rectangle,
	color:      rl.Color,
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
}

Push_Clip_Command :: struct {
	rect: rl.Rectangle,
}

Pop_Clip_Command :: struct {}

UI_Context :: struct {
	elements:           [dynamic]UI_Element,
	open_element_stack: [dynamic]UI_Index,
	growable_buffer:    [dynamic]UI_Index,
	wrapped_text_lines: [dynamic]string,
	render_commands:    [dynamic]Render_Command,
	text_measurer:      UI_TextMeasurer,
	default_font:       Viewer_Font,
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

UI_LayoutDeclare :: struct {
	id:               string,
	width:            Maybe(Sizing_Axis),
	height:           Maybe(Sizing_Axis),
	padding:          Maybe(Layout_Padding),
	child_gap:        Maybe(f32),
	layout_direction: Maybe(Layout_Direction),
	child_alignment:  Maybe(Alignment),
	background_color: Maybe(rl.Color),
}

UI_TextDeclare :: struct {
	id:           string,
	content:      Maybe(string),
	font:         Maybe(rl.Font),
	font_size:    Maybe(f32),
	spacing:      Maybe(f32),
	color:        Maybe(rl.Color),
	line_spacing: Maybe(f32),
	alignment:    Maybe(Alignment),
}

UI_LayoutConfig :: struct {
	width:            Size_Mode,
	height:           Size_Mode,
	padding:          Layout_Padding,
	child_gap:        f32,
	layout_direction: Layout_Direction,
	child_alignment:  Alignment,
	background_color: rl.Color,
}

UI_TextConfig :: struct {
	content:      string,
	font:         rl.Font,
	font_size:    f32,
	spacing:      f32,
	color:        rl.Color,
	line_spacing: f32,
	alignment:    Alignment,
}

UI_ElementDeclare :: union {
	UI_LayoutDeclare,
	UI_TextDeclare,
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
		LayoutAttributes,
		TextAttributes,
	},
}

UI_AxisLimits :: struct {
	min: Maybe(f32),
	max: Maybe(f32),
}

UI_Limits :: struct {
	x: UI_AxisLimits,
	y: UI_AxisLimits,
}

LayoutAttributes :: struct {
	element: UI_Index,
	config:  UI_LayoutConfig,
}

TextAttributes :: struct {
	element:                  UI_Index,
	config:                   UI_TextConfig,
	preferred_size:           rl.Vector2,
	wrapped_text_lines_start: i32,
	wrapped_text_lines_count: i32,
}

ChildIter :: struct {
	ctx:     ^UI_Context,
	current: UI_Index, // next child index to visit
	end:     UI_Index, // exclusive end of this node's subtree
}

@(private)
open_layout :: proc(ctx: ^UI_Context, declare: UI_LayoutDeclare) -> bool {
	parent := ctx.open_element_stack[len(ctx.open_element_stack) - 1]
	index := UI_Index(len(ctx.elements))

	config, limits := parse_layout_declare(default_layout(), declare)
	ui_ele := UI_Element {
		id = declare.id,
		parent = parent,
		index = i32(len(ctx.elements)), // set before append
		attributes = LayoutAttributes{config = config, element = index},
		limits = limits,
		// layout sets its tree size when close
	}

	append(&ctx.elements, ui_ele)
	append(&ctx.open_element_stack, index)
	return true
}

@(private)
open_text :: proc(ctx: ^UI_Context, declare: UI_TextDeclare) {
	parent_idx := ctx.open_element_stack[len(ctx.open_element_stack) - 1]
	index := UI_Index(len(ctx.elements))

	config, limits := parse_text_declare(ctx^, default_text(ctx^), declare)
	ui_ele := UI_Element {
		id = declare.id,
		parent = parent_idx,
		index = i32(len(ctx.elements)),
		attributes = TextAttributes{config = config, element = index},
		limits = limits,
		subtree_size = 1,
	}

	append(&ctx.elements, ui_ele)
	calculate_text_width(ctx, index)
}


@(private)
close_layout :: proc(ctx: ^UI_Context) {
	index := pop(&ctx.open_element_stack)
	ele := &ctx.elements[index]

	// Compute subtree size: everything appended after this node is in its subtree
	ele.subtree_size = i32(len(ctx.elements)) - ele.index

	fit_sizing_widths(ctx, index)
}

@(private)
calculate_text_width :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := &ctx.elements[index]
	text_attr, ok := &current.attributes.(TextAttributes)
	if !ok do return

	// prefered size
	text_attr.preferred_size.x = ctx.text_measurer(text_attr.config)
	text_attr.preferred_size.y = text_attr.config.font_size

	current.size.x = text_attr.preferred_size.x

	// min size is the longest english word in the sentence
	{
		text := text_attr.config.content
		config := text_attr.config
		word_start := 0
		largest_word_width := f32(0)

		byte_index := 0
		for byte_index < len(text) {
			whitespace_start := byte_index

			// Skip whitespace / find word start.
			for byte_index < len(text) {
				r, size := utf8.decode_rune(text[byte_index:])
				if !is_separator(r) {
					break
				}
				byte_index += size
			}

			word_start = byte_index

			// Find end of word.
			for byte_index < len(text) {
				r, size := utf8.decode_rune(text[byte_index:])
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

			config.content = text[word_start:word_end]
			word_width := ctx.text_measurer(config)
			if word_width > largest_word_width {
				largest_word_width = word_width
			}
		}

		current.limits.x.min = largest_word_width
	}

	current.size.x = clamp_element_size(current.size.x, current.limits.x)
}


@(private)
calculate_layout_height :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := &ctx.elements[index]
	if layout, ok := current.attributes.(LayoutAttributes); ok {
		if mode, ok := layout.config.height.(Fixed_Size); ok {
			current.size.y = mode.value
		}
	}
}

@(private)
clamp_element_size :: proc(current_size: f32, limits: UI_AxisLimits) -> f32 {
	res := current_size
	if min_size, ok := limits.min.(f32); ok && res <= min_size {
		res = min_size
	}
	if max_size, ok := limits.max.(f32); ok && res >= max_size {
		res = max_size
	}
	return res
}

@(private)
fit_sizing_widths :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(LayoutAttributes)
	if !ok do return


	if fixed_size, ok := layout.config.width.(Fixed_Size); ok {
		current.limits.x.min = fixed_size.value
		current.limits.x.max = fixed_size.value
		current.size.x = fixed_size.value
		return
	}

	padding := layout.config.padding.left + layout.config.padding.right
	children_min_size := f32(0)
	child_gap := f32(0)

	if layout.config.layout_direction == .Left_To_Right {
		// Jump‑loop over direct children
		child_count := 0
		// Sum widths of children + gaps
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			children_min_size += child.limits.x.min.? or_else 0

			current.size.x += child.size.x
			child_count += 1
		}
		if child_count > 0 {
			child_gap = f32(child_count - 1) * layout.config.child_gap
			current.size.x += child_gap
			children_min_size += child_gap
		}
	} else {
		// Max width among children
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			children_min_size = max(children_min_size, child.limits.x.min.? or_else 0)

			current.size.x = max(current.size.x, child.size.x + padding)
		}
	}

	if children_min_size > (current.limits.x.min.? or_else 0) {
		current.limits.x.min = children_min_size + padding
	} else {
		current.size.x += padding
	}

	current.size.x = clamp_element_size(current.size.x, current.limits.x)
}

@(private)
fit_sizing_heights :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(LayoutAttributes)
	if !ok do return

	if fixed_size, ok := layout.config.height.(Fixed_Size); ok {
		current.limits.y.min = fixed_size.value
		current.limits.y.max = fixed_size.value
		current.size.y = fixed_size.value
		return
	}


	padding := layout.config.padding.top + layout.config.padding.bottom
	children_min_size := f32(0)
	child_gap := f32(0)

	if layout.config.layout_direction == .Top_To_Bottom {
		// Jump‑loop over direct children
		child_count := 0
		// Sum heights of children + gaps
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			children_min_size += child.limits.y.min.? or_else 0

			current.size.y += child.size.y
			child_count += 1
		}
		if child_count > 0 {
			child_gap = f32(child_count - 1) * layout.config.child_gap
			current.size.y += child_gap
			children_min_size += child_gap
		}
	} else {
		// Max height among children
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			children_min_size = max(children_min_size, child.limits.y.min.? or_else 0)

			current.size.y = max(current.size.y, child.size.y + padding)
		}
	}

	if children_min_size > (current.limits.y.min.? or_else 0) {
		current.limits.y.min = children_min_size + padding
	} else {
		current.size.y += padding
	}

	current.size.y = clamp_element_size(current.size.y, current.limits.y)
}

@(private)
fit_sizing_heights_tree :: proc(ctx: ^UI_Context, index: UI_Index) {
	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		fit_sizing_heights_tree(ctx, child.index)
	}

	fit_sizing_heights(ctx, index)
}

@(private)
grow_and_shrink_sizing_widths :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := ctx.elements[index]
	layout, ok := current.attributes.(LayoutAttributes)
	if !ok || current.subtree_size <= 1 do return

	content_width := current.size.x - layout.config.padding.left - layout.config.padding.right

	// Vertical layout: all grow children expand to fill width
	if layout.config.layout_direction == .Top_To_Bottom {
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			if is_grow_layout_or_text(child^, .X) {
				child.size.x = clamp_element_size(content_width, child.limits.x)
			}
		}
		return
	}

	// Horizontal layout: distribute remaining space among grow children
	growables := ctx.growable_buffer
	clear(&growables)
	defer clear(&growables)

	remaining_width := content_width
	child_count := 0

	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		remaining_width -= child.size.x

		if is_grow_layout_or_text(child^, .X) {
			append(&growables, child.index)
		}

		child_count += 1
	}

	if child_count > 0 {
		remaining_width -= f32(child_count - 1) * layout.config.child_gap
	}

	if len(growables) == 0 do return

	growable_count := len(growables)


	for remaining_width > math.F32_EPSILON && len(growables) > 0 {
		smallest := ctx.elements[growables[0]].size.x
		second_smallest := ctx.elements[growables[0]].size.x
		width_to_add := remaining_width

		for growable_index in 1 ..< len(growables) {
			child_ele := ctx.elements[growables[growable_index]]
			if child_ele.size.x < smallest {
				second_smallest = smallest
				smallest = child_ele.size.x
			} else if child_ele.size.x < second_smallest {
				second_smallest = min(second_smallest, child_ele.size.x)
				width_to_add = second_smallest - smallest
			}
		}

		if width_to_add == 0 {
			// all childs already equally expanded from the start
			width_to_add = remaining_width / f32(len(growables))
		} else {
			width_to_add = min(width_to_add, remaining_width / f32(len(growables)))
		}

		for i := 0; i < len(growables); {
			growable := growables[i]
			if ctx.elements[growable].size.x == smallest {
				growable_ele := &ctx.elements[growable]
				prev_size := growable_ele.size.x
				growable_ele.size.x += width_to_add

				if max_size, ok := growable_ele.limits.x.max.(f32);
				   ok && growable_ele.size.x >= max_size {
					growable_ele.size.x = max_size
					remaining_width -= max_size - prev_size
					unordered_remove(&growables, i)
					continue
				}
				remaining_width -= width_to_add
			}
			i += 1
		}
	}

	non_zero_resize(&growables, growable_count) // keep capacity


	shrinkables := growables
	overshoot_width := -remaining_width

	for overshoot_width > math.F32_EPSILON && len(shrinkables) > 0 {
		largest := ctx.elements[shrinkables[0]].size.x
		second_largest := ctx.elements[shrinkables[0]].size.x
		width_to_subtract := overshoot_width

		for shrinkable_index in 1 ..< len(shrinkables) {
			child_ele := ctx.elements[shrinkables[shrinkable_index]]
			if child_ele.size.x > largest {
				second_largest = largest
				largest = child_ele.size.x
			} else if child_ele.size.x > second_largest {
				second_largest = max(second_largest, child_ele.size.x)
				width_to_subtract = largest - second_largest
			}
		}

		if width_to_subtract == 0 {
			width_to_subtract = remaining_width / f32(len(growables))
		} else {
			width_to_subtract = max(width_to_subtract, overshoot_width / f32(len(shrinkables)))
		}

		for i := 0; i < len(shrinkables); {
			shrinkable := shrinkables[i]
			if ctx.elements[shrinkable].size.x == largest {
				shrinkable_ele := &ctx.elements[shrinkable]
				prev_size := shrinkable_ele.size.x
				shrinkable_ele.size.x -= width_to_subtract

				min_size := shrinkable_ele.limits.x.min.(f32) or_else 0

				if shrinkable_ele.size.x <= min_size {
					shrinkable_ele.size.x = min_size
					overshoot_width -= prev_size - min_size
					unordered_remove(&shrinkables, i)
					continue
				} else {
					overshoot_width -= width_to_subtract
				}
			}
			i += 1
		}
	}
}

// Height version – analogous
@(private)
grow_and_shrink_sizing_heights :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := ctx.elements[index]
	layout, ok := current.attributes.(LayoutAttributes)
	if !ok || current.subtree_size <= 1 do return

	content_height := current.size.y - layout.config.padding.top - layout.config.padding.bottom

	// Horizontal layout: all grow children expand to fill height
	if layout.config.layout_direction == .Left_To_Right {
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			if is_grow_layout_or_text(child^, .Y) {
				child.size.y = clamp_element_size(content_height, child.limits.y)
			}
		}
		return
	}

	growables := ctx.growable_buffer
	clear(&growables)
	defer clear(&growables)

	remaining_height := content_height
	child_count := 0


	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		remaining_height -= child.size.y

		if is_grow_layout_or_text(child^, .Y) {
			append(&growables, child.index)
		}

		child_count += 1
	}

	if child_count > 0 {
		remaining_height -= f32(child_count - 1) * layout.config.child_gap
	}

	if len(growables) == 0 do return

	growable_count := len(growables)

	// Grow
	for remaining_height > math.F32_EPSILON && len(growables) > 0 {
		smallest := ctx.elements[growables[0]].size.y
		second_smallest := ctx.elements[growables[0]].size.y
		height_to_add := remaining_height

		for growable_index in 1 ..< len(growables) {
			child_ele := ctx.elements[growables[growable_index]]
			if child_ele.size.y < smallest {
				second_smallest = smallest
				smallest = child_ele.size.y
			} else if child_ele.size.y < second_smallest {
				second_smallest = min(second_smallest, child_ele.size.y)
				height_to_add = second_smallest - smallest
			}
		}

		if height_to_add == 0 {
			height_to_add = remaining_height / f32(len(growables))
		} else {
			height_to_add = min(height_to_add, remaining_height / f32(len(growables)))
		}

		for i := 0; i < len(growables); {
			growable := growables[i]
			if ctx.elements[growable].size.y == smallest {
				growable_ele := &ctx.elements[growable]
				prev_size := growable_ele.size.y
				growable_ele.size.y += height_to_add

				if max_size, ok := growable_ele.limits.y.max.(f32);
				   ok && growable_ele.size.y >= max_size {
					growable_ele.size.y = max_size
					remaining_height -= max_size - prev_size
					unordered_remove(&growables, i)
					continue
				}
				remaining_height -= height_to_add
			}
			i += 1
		}
	}

	non_zero_resize(&growables, growable_count)

	// Shrink
	shrinkables := growables
	overshoot_height := -remaining_height

	for overshoot_height > math.F32_EPSILON && len(shrinkables) > 0 {
		largest := ctx.elements[shrinkables[0]].size.y
		second_largest := ctx.elements[shrinkables[0]].size.y
		height_to_subtract := overshoot_height

		for shrinkable_index in 1 ..< len(shrinkables) {
			child_ele := ctx.elements[shrinkables[shrinkable_index]]
			if child_ele.size.y > largest {
				second_largest = largest
				largest = child_ele.size.y
			}
			if child_ele.size.y > second_largest {
				second_largest = max(second_largest, child_ele.size.y)
				height_to_subtract = largest - second_largest
			}
		}

		if height_to_subtract == 0 {
			height_to_subtract = overshoot_height / f32(len(shrinkables))
		} else {
			height_to_subtract = max(height_to_subtract, overshoot_height / f32(len(shrinkables)))
		}

		for i := 0; i < len(shrinkables); {
			shrinkable := shrinkables[i]
			if ctx.elements[shrinkable].size.y == largest {
				shrinkable_ele := &ctx.elements[shrinkable]
				prev_size := shrinkable_ele.size.y
				shrinkable_ele.size.y -= height_to_subtract

				min_size := shrinkable_ele.limits.y.min.(f32) or_else 0
				if shrinkable_ele.size.y <= min_size {
					shrinkable_ele.size.y = min_size
					overshoot_height -= prev_size - min_size
					unordered_remove(&shrinkables, i)
					continue
				} else {
					overshoot_height -= height_to_subtract
				}
			}
			i += 1
		}
	}
}

@(private)
grow_and_shrink_sizing_widths_tree :: proc(ctx: ^UI_Context, index: UI_Index) {
	grow_and_shrink_sizing_widths(ctx, index)
	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		grow_and_shrink_sizing_widths_tree(ctx, child.index)
	}
}

@(private)
grow_and_shrink_sizing_heights_tree :: proc(ctx: ^UI_Context, index: UI_Index) {
	grow_and_shrink_sizing_heights(ctx, index)
	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		grow_and_shrink_sizing_heights_tree(ctx, child.index)
	}
}

@(private)
is_separator :: #force_inline proc(r: rune) -> bool {
	for sep in WORD_SEPARATION_CHARS {
		if r == sep {
			return true
		}
	}
	return false
}

@(private)
wrap_texts :: proc(ctx: ^UI_Context) {
	for &ele in ctx.elements {
		text_attr := (&ele.attributes.(TextAttributes)) or_continue

		text := text_attr.config.content
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
			} else {
				ele.size.y = config.font_size
			}
			ele.limits.y.min = ele.size.y
		}

		byte_index := 0

		for byte_index < len(text) {
			whitespace_start := byte_index

			// Skip whitespace / find word start.
			for byte_index < len(text) {
				r, size := utf8.decode_rune(text[byte_index:])
				if !is_separator(r) {
					break
				}
				byte_index += size
			}

			word_start := byte_index

			// Find end of word.
			for byte_index < len(text) {
				r, size := utf8.decode_rune(text[byte_index:])
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


			config.content = text[whitespace_start:word_start]
			whitespace_width := ctx.text_measurer(config)

			config.content = text[word_start:word_end]
			word_width := ctx.text_measurer(config)

			candidate_width := whitespace_width + word_width

			if line_width > 0 && line_width + candidate_width > ele.size.x {
				append(&ctx.wrapped_text_lines, text[line_start:whitespace_start])
				wrapped_count += 1

				line_start = word_start
				line_width = word_width
			} else {
				line_width += candidate_width
			}
		}

		if wrapped_count > 0 {
			append(&ctx.wrapped_text_lines, text[line_start:])
			wrapped_count += 1
		}
	}
}

@(private)
calculate_position_x :: proc(ctx: ^UI_Context, index: UI_Index = 0) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(LayoutAttributes)
	if !ok {
		text_attr, ok := current.attributes.(TextAttributes)
		assert(ok)

		if current.size.x > text_attr.preferred_size.x {
			remaining_width := current.size.x - text_attr.preferred_size.x

			switch text_attr.config.alignment.x {
			case .Left:
				break
			case .Center:
				current.position.x += remaining_width * 0.5
			case .Right:
				current.position.x += remaining_width
			}
		}

		return
	}

	left_offset := current.position.x + layout.config.padding.left

	if layout.config.layout_direction == .Left_To_Right {
		// Find the remaining width
		remaining_width :=
			current.size.x - layout.config.padding.left - layout.config.padding.right
		child_count := 0
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			remaining_width -= child.size.x
			child_count += 1
		}
		remaining_width -= f32(child_count - 1) * layout.config.child_gap


		switch layout.config.child_alignment.x {
		case .Left:
			break
		case .Center:
			left_offset += remaining_width * 0.5
		case .Right:
			left_offset += remaining_width
		}
	}

	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		child.position.x = left_offset

		if layout.config.layout_direction == .Top_To_Bottom {
			// Find the remaining height
			remaining_width :=
				current.size.x -
				layout.config.padding.left -
				layout.config.padding.right -
				child.size.x

			switch layout.config.child_alignment.x {
			case .Left:
				break
			case .Center:
				child.position.x += remaining_width * 0.5
			case .Right:
				child.position.x += remaining_width
			}
		} else {
			left_offset += child.size.x + layout.config.child_gap
		}

		calculate_position_x(ctx, child.index)
	}
}

@(private)
calculate_position_y :: proc(ctx: ^UI_Context, index: UI_Index = 0) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(LayoutAttributes)
	if !ok {
		text_attr, ok := current.attributes.(TextAttributes)

		if current.size.y > text_attr.preferred_size.y {
			remaining_height := current.size.y - text_attr.preferred_size.y

			switch text_attr.config.alignment.y {
			case .Top:
				break
			case .Center:
				current.position.y += remaining_height * 0.5
			case .Bottom:
				current.position.y += remaining_height
			}
		}

		return
	}

	top_offset := current.position.y + layout.config.padding.top

	if layout.config.layout_direction == .Top_To_Bottom {
		// Find the remaining width
		remaining_height :=
			current.size.y - layout.config.padding.top - layout.config.padding.bottom
		child_count := 0
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			remaining_height -= child.size.y
			child_count += 1
		}
		remaining_height -= f32(child_count - 1) * layout.config.child_gap

		switch layout.config.child_alignment.y {
		case .Top:
			break
		case .Center:
			top_offset += remaining_height * 0.5
		case .Bottom:
			top_offset += remaining_height
		}
	}

	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		child.position.y = top_offset

		if layout.config.layout_direction == .Left_To_Right {
			// Find the remaining height
			remaining_height :=
				current.size.y -
				layout.config.padding.top -
				layout.config.padding.bottom -
				child.size.y

			switch layout.config.child_alignment.y {
			case .Top:
				break
			case .Center:
				child.position.y += remaining_height * 0.5
			case .Bottom:
				child.position.y += remaining_height
			}
		} else {
			top_offset += child.size.y + layout.config.child_gap
		}

		calculate_position_y(ctx, child.index)
	}
}

ui_debug_draw_tree :: proc(ctx: ^UI_Context, index: UI_Index = 0, cur_level: i32 = 1) {
	current := ctx.elements[index]

	for i in 0 ..< cur_level - 1 {
		fmt.print(" . ")
	}

	layout, ok := current.attributes.(LayoutAttributes)

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
		// print direct children
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			ui_debug_draw_tree(ctx, child.index, cur_level + 1)
		}
	} else {
		fmt.println()
	}
}

ui_context_make :: proc(text_measurer: UI_TextMeasurer) -> UI_Context {
	return UI_Context {
		elements = make([dynamic]UI_Element, 0, 500),
		open_element_stack = make([dynamic]UI_Index, 0, 50),
		render_commands = make([dynamic]Render_Command, 0, 500),
		growable_buffer = make([dynamic]UI_Index, 0, 500),
		default_font = viewer_load_font(
			12,
			0,
			"assets/fonts/NotoSansMono-SemiBold.ttf",
			"assets/fonts/NotoSansMono-Regular.ttf",
		),
		text_measurer = text_measurer,
		wrapped_text_lines = make([dynamic]string, 0, 500),
	}
}

ui_context_delete :: proc(ctx: UI_Context) {
	delete(ctx.elements)
	delete(ctx.open_element_stack)
	delete(ctx.render_commands)
	delete(ctx.growable_buffer)
	delete(ctx.wrapped_text_lines)
	viewer_unload_font(ctx.default_font)
}

@(deferred_in_out = end_layout)
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


@(private)
end_layout :: proc(ctx: ^UI_Context, _: f32, _: f32, ok: bool) {
	if !ok do return

	// Close the root – this computes sizes and subtree_size
	close_layout(ctx)

	// Top down, calculate grow sizing widths
	grow_and_shrink_sizing_widths_tree(ctx, 0)
	wrap_texts(ctx)

	fit_sizing_heights_tree(ctx, 0)
	grow_and_shrink_sizing_heights_tree(ctx, 0)

	// ui_debug_draw_tree(ctx,)

	// Compute positions
	calculate_position_x(ctx)
	calculate_position_y(ctx)

	// Generate render commands
	clear(&ctx.render_commands)
	for ele in ctx.elements {
		switch attr in ele.attributes {
		case LayoutAttributes:
			{
				append(
					&ctx.render_commands,
					Rect_Command {
						x = ele.position.x,
						y = ele.position.y,
						width = ele.size.x,
						height = ele.size.y,
						color = rl.BLUE,
					},
				)
			}
		case TextAttributes:
			{
				// debug rect
				append(
					&ctx.render_commands,
					Rect_Command {
						x = ele.position.x,
						y = ele.position.y,
						width = ele.size.x,
						height = ele.size.y,
						color = rl.BLUE,
					},
				)
				append(
					&ctx.render_commands,
					Text_Command {
						content = attr.config.content,
						font_size = attr.config.font_size,
						spacing = attr.config.spacing,
						line_spacing = attr.config.line_spacing,
						font = attr.config.font,
						position = ele.position,
						wrapped_lines = ctx.wrapped_text_lines[attr.wrapped_text_lines_start:][:attr.wrapped_text_lines_count],
						color = attr.config.color,
					},
				)
			}
		}

	}

	// Clean up
	clear(&ctx.elements)
	clear(&ctx.open_element_stack)
}

@(private)
root_layout :: proc(width: f32, height: f32) -> UI_Element {
	return UI_Element {
		id = "root",
		parent = 0,
		position = {0, 0},
		size = {width, height},
		limits = {}, // no limits
		attributes = LayoutAttributes {
			config = UI_LayoutConfig {
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

@(private)
default_layout :: proc() -> UI_LayoutConfig {
	return UI_LayoutConfig {
		child_alignment = {x = .Left, y = .Top},
		child_gap = 8,
		width = Fit_Size{},
		height = Fit_Size{},
		layout_direction = .Left_To_Right,
		padding = pad_all(8),
		background_color = rl.RAYWHITE,
	}
}

@(private)
default_text :: proc(ctx: UI_Context) -> UI_TextConfig {
	return UI_TextConfig {
		font_size = f32(ctx.default_font.font_size),
		font = ctx.default_font.font,
		spacing = ctx.default_font.spacing,
		line_spacing = 4,
		color = rl.BLACK,
		alignment = {.Left, .Top},
	}
}

ui_get_id :: proc(ctx: UI_Context, index: UI_Index) -> string {
	return ctx.elements[index].id
}

@(private)
set_if_set :: #force_inline proc(dest: ^$T, src: Maybe(T)) {
	if v, ok := src.(T); ok {
		dest^ = v
	}
}

@(private)
parse_layout_declare :: proc(
	default_config: UI_LayoutConfig,
	declare: UI_LayoutDeclare,
) -> (
	UI_LayoutConfig,
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

	return config, limits
}

@(private)
parse_text_declare :: proc(
	ctx: UI_Context,
	default_config: UI_TextConfig,
	declare: UI_TextDeclare,
) -> (
	UI_TextConfig,
	UI_Limits,
) {
	config := default_config

	set_if_set(&config.content, declare.content)
	set_if_set(&config.font_size, declare.font_size)
	set_if_set(&config.spacing, declare.spacing)
	set_if_set(&config.font, declare.font)
	set_if_set(&config.color, declare.color)
	set_if_set(&config.line_spacing, declare.line_spacing)
	set_if_set(&config.alignment, declare.alignment)

	return config, UI_Limits{}
}

grow :: #force_inline proc(min: Maybe(f32) = nil, max: Maybe(f32) = nil) -> Sizing_Axis {
	return {mode = Grow_Size{}, min = min, max = max}
}

fixed :: #force_inline proc(
	value: f32 = 0,
	min: Maybe(f32) = nil,
	max: Maybe(f32) = nil,
) -> Sizing_Axis {
	return {mode = Fixed_Size{value = value}, min = min, max = max}
}

fit :: #force_inline proc(min: Maybe(f32) = nil, max: Maybe(f32) = nil) -> Sizing_Axis {
	return {mode = Fit_Size{}, min = min, max = max}
}

percent :: #force_inline proc(
	value: f32,
	min: Maybe(f32) = nil,
	max: Maybe(f32) = nil,
) -> Sizing_Axis {
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


@(private)
child_iter_start :: proc(ctx: ^UI_Context, start_index: UI_Index) -> ChildIter {
	start := ctx.elements[start_index]
	return ChildIter{ctx = ctx, current = start.index + 1, end = start.index + start.subtree_size}
}

@(private)
child_iter_next :: proc(it: ^ChildIter) -> (child: ^UI_Element, cond: bool) {
	if it.current >= it.end {
		return nil, false
	}
	child = &it.ctx.elements[it.current]
	it.current += child.subtree_size // jump to next sibling
	return child, true
}

@(private)
is_grow_layout_or_text :: proc(ele: UI_Element, axis: Axis) -> bool {
	switch attr in ele.attributes {
	case TextAttributes:
		{
			return true
		}
	case LayoutAttributes:
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

@(deferred_none = close_layout_deffered)
layout :: proc(declare: UI_LayoutDeclare) -> bool {
	return open_layout(current_context, declare)
}

@(private)
close_layout_deffered :: proc() {
	close_layout(current_context)
}

text_config :: proc(declare: UI_TextDeclare) {
	open_text(current_context, declare)
}
