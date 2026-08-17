package main

import "core:fmt"
import "core:math"
import "core:reflect"
import rl "vendor:raylib"

MAX_CHILD_COUNT :: 50
EPSILON :: 1e-20

UI_Input :: struct {
	mouse_position:      rl.Vector2,
	mouse_pressed:       bool,
	mouse_just_pressed:  bool,
	mouse_just_released: bool,
	scroll:              rl.Vector2,
}

UI_TextMeasurer :: proc(text: UI_TextConfig) -> rl.Vector2

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
	content:   string,
	font:      rl.Font,
	font_size: f32,
	spacing:   f32,
	color:     rl.Color,
	position:  rl.Vector2,
}

Push_Clip_Command :: struct {
	rect: rl.Rectangle,
}

Pop_Clip_Command :: struct {}

UI_Context :: struct {
	elements:           [dynamic]UI_Element,
	open_element_stack: [dynamic]UI_Index,
	growable_buffer:    [dynamic]UI_Index,
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

Child_Alignment :: struct {
	x: Child_Alignment_X,
	y: Child_Alignment_Y,
}

Child_Alignment_X :: enum {
	Left,
	Center,
	Right,
}

Child_Alignment_Y :: enum {
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
	child_alignment:  Maybe(Child_Alignment),
	background_color: Maybe(rl.Color),
}

UI_TextDeclare :: struct {
	id:        string,
	content:   Maybe(string),
	font:      Maybe(rl.Font),
	font_size: Maybe(f32),
	spacing:   Maybe(f32),
}

UI_LayoutConfig :: struct {
	width:            Size_Mode,
	height:           Size_Mode,
	padding:          Layout_Padding,
	child_gap:        f32,
	layout_direction: Layout_Direction,
	child_alignment:  Child_Alignment,
	background_color: rl.Color,
}

UI_TextConfig :: struct {
	content:   string,
	font:      rl.Font,
	font_size: f32,
	spacing:   f32,
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

UI_Limits :: struct {
	min_width:  Maybe(f32),
	max_width:  Maybe(f32),
	min_height: Maybe(f32),
	max_height: Maybe(f32),
}

LayoutAttributes :: struct {
	element: UI_Index,
	config:  UI_LayoutConfig,
}

TextAttributes :: struct {
	element: UI_Index,
	config:  UI_TextConfig,
}

ChildIter :: struct {
	ctx:     ^UI_Context,
	current: UI_Index, // next child index to visit
	end:     UI_Index, // exclusive end of this node's subtree
}

@(deferred_in_out = close_layout)
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
	}

	append(&ctx.elements, ui_ele)
	append(&ctx.open_element_stack, index)
	return true
}

@(deferred_in_out = close_text)
open_text :: proc(ctx: ^UI_Context, declare: UI_TextDeclare) -> bool {
	parent_idx := ctx.open_element_stack[len(ctx.open_element_stack) - 1]
	index := UI_Index(len(ctx.elements))

	config, limits := parse_text_declare(ctx^, default_text(ctx^), declare)
	ui_ele := UI_Element {
		id = declare.id,
		parent = parent_idx,
		index = i32(len(ctx.elements)),
		attributes = TextAttributes{config = config, element = index},
		limits = limits,
	}

	append(&ctx.elements, ui_ele)
	append(&ctx.open_element_stack, index)
	return true
}

@(private)
close_layout :: proc(ctx: ^UI_Context, _: UI_LayoutDeclare, ok: bool) {
	if ok do close_element(ctx)
}

@(private)
close_text :: proc(ctx: ^UI_Context, _: UI_TextDeclare, ok: bool) {
	if ok do close_element(ctx)
}

@(private)
close_element :: proc(ctx: ^UI_Context) {
	index := pop(&ctx.open_element_stack)
	ele := &ctx.elements[index]

	// Compute subtree size: everything appended after this node is in its subtree
	ele.subtree_size = i32(len(ctx.elements)) - ele.index

	// Calculate preferred size of text element
	calculate_text_size(ctx, index)

	// Run sizing calculations (they use the jump‑loop to iterate children)
	calculate_width(ctx, index)
	fit_sizing_widths(ctx, index)
	grow_and_shrink_sizing_widths(ctx, index)

	calculate_height(ctx, index)
	fit_sizing_heights(ctx, index)
	grow_and_shrink_sizing_height(ctx, index)
}

@(private)
calculate_text_size :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := &ctx.elements[index]
	current_text, ok := current.attributes.(TextAttributes)
	if !ok do return

	preferred_size := ctx.text_measurer(current_text.config)
	current.size = preferred_size

	// Min size is approximated, should have been the shortest english word in the sentence
	min_size := 4 * current_text.config.font_size

	current.size.x = clamp_element_size(current.size.x, min_size, nil)
}


@(private)
calculate_width :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := &ctx.elements[index]
	if layout, ok := current.attributes.(LayoutAttributes); ok {
		if mode, ok := layout.config.width.(Fixed_Size); ok {
			current.size.x = mode.value
		}
	}
	current.size.x = clamp_element_size(
		current.size.x,
		current.limits.min_width,
		current.limits.max_width,
	)
}

@(private)
calculate_height :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := &ctx.elements[index]
	if layout, ok := current.attributes.(LayoutAttributes); ok {
		if mode, ok := layout.config.height.(Fixed_Size); ok {
			current.size.y = mode.value
		}
	}
	current.size.y = clamp_element_size(
		current.size.y,
		current.limits.min_height,
		current.limits.max_height,
	)
}

@(private)
clamp_element_size :: proc(
	current_size: f32,
	maybe_min_size: Maybe(f32),
	maybe_max_size: Maybe(f32),
) -> f32 {
	res := current_size
	if min_size, ok := maybe_min_size.(f32); ok && res < min_size {
		res = min_size
	}
	if max_size, ok := maybe_max_size.(f32); ok && res > max_size {
		res = max_size
	}
	return res
}

@(private)
fit_sizing_widths :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(LayoutAttributes)
	if !ok do return

	if _, ok := layout.config.width.(Fixed_Size); ok do return

	padding := layout.config.padding.left + layout.config.padding.right
	current.size.x += padding

	if layout.config.layout_direction == .Left_To_Right {
		// Jump‑loop over direct children
		child_count := 0
		// Sum widths of children + gaps
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			current.size.x += child.size.x
			child_count += 1
		}
		if child_count > 0 {
			current.size.x += f32(child_count - 1) * layout.config.child_gap
		}
	} else {
		// Max width among children
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			current.size.x = max(current.size.x, child.size.x + padding)
		}
	}

	if max_size, ok := current.limits.max_width.(f32); ok {
		current.size.x = min(current.size.x, max_size)
	}

	fmt.println("index: ", index, current.size)
}

@(private)
fit_sizing_heights :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(LayoutAttributes)
	if !ok do return

	if _, ok := layout.config.height.(Fixed_Size); ok do return


	if layout.config.layout_direction == .Top_To_Bottom {
		child_count := 0
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			current.size.y += child.size.y
			child_count += 1
		}
		if child_count > 0 {
			current.size.y += f32(child_count - 1) * layout.config.child_gap
		}
	} else {
		padding := layout.config.padding.top + layout.config.padding.bottom
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			current.size.y = max(current.size.y, child.size.y + padding)
		}
	}

	if max_size, ok := current.limits.max_height.(f32); ok {
		current.size.y = min(current.size.y, max_size)
	}
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
			if child_layout, ok := child.attributes.(LayoutAttributes); ok {
				if _, ok := child_layout.config.width.(Grow_Size); ok {
					child.size.x = content_width
				}
			}
		}
		return
	}

	// Horizontal layout: distribute remaining space among grow children
	growables := ctx.growable_buffer
	clear(&growables)

	remaining_width := content_width
	child_count := 0

	idx, end := current.index + 1, current.index + current.subtree_size

	for idx < end {
		child_idx := idx
		child := ctx.elements[child_idx]
		if child_layout, ok := child.attributes.(LayoutAttributes); ok {
			remaining_width -= child.size.x
			if _, ok := child_layout.config.width.(Grow_Size); ok {
				append(&growables, child_idx)
			}
		}
		child_count += 1
		idx += child.subtree_size
	}

	if child_count > 0 {
		remaining_width -= f32(child_count - 1) * layout.config.child_gap
	}

	if len(growables) == 0 do return

	growable_count := len(growables)

	// ---- Grow phase ----
	for remaining_width > math.F32_EPSILON && len(growables) > 0 {
		smallest := math.inf_f32(1)
		second_smallest := math.inf_f32(1)
		width_to_add := remaining_width

		for child in growables {
			child_ele := ctx.elements[child]
			if child_ele.size.x < smallest {
				second_smallest = smallest
				smallest = child_ele.size.x
			}
			if child_ele.size.x > second_smallest {
				second_smallest = min(second_smallest, child_ele.size.x)
				width_to_add = second_smallest - smallest
			}
		}
		width_to_add = min(width_to_add, remaining_width / f32(len(growables)))

		for i := 0; i < len(growables); {
			growable := growables[i]
			if ctx.elements[growable].size.x == smallest {
				growable_ele := &ctx.elements[growable]
				prev_size := growable_ele.size.x
				growable_ele.size.x += width_to_add

				if max_size, ok := growable_ele.limits.max_width.(f32);
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

	// ---- Shrink phase (if overshoot) ----
	shrinkables := growables
	overshoot_width := -remaining_width

	for overshoot_width > math.F32_EPSILON && len(shrinkables) > 0 {
		largest := math.inf_f32(-1)
		second_largest := math.inf_f32(-1)
		width_to_subtract := overshoot_width

		for child in shrinkables {
			child_ele := ctx.elements[child]
			if child_ele.size.x > largest {
				second_largest = largest
				largest = child_ele.size.x
			}
			if child_ele.size.x > second_largest {
				second_largest = max(second_largest, child_ele.size.x)
				width_to_subtract = largest - second_largest
			}
		}
		width_to_subtract = max(width_to_subtract, overshoot_width / f32(len(shrinkables)))

		for i := 0; i < len(shrinkables); {
			shrinkable := shrinkables[i]
			if ctx.elements[shrinkable].size.x == largest {
				shrinkable_ele := &ctx.elements[shrinkable]
				prev_size := shrinkable_ele.size.x
				shrinkable_ele.size.x -= width_to_subtract

				min_size := shrinkable_ele.limits.min_width.(f32) or_else 0
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
grow_and_shrink_sizing_height :: proc(ctx: ^UI_Context, index: UI_Index) {
	current := ctx.elements[index]
	layout, ok := current.attributes.(LayoutAttributes)
	if !ok || current.subtree_size <= 1 do return

	content_height := current.size.y - layout.config.padding.top - layout.config.padding.bottom

	// Horizontal layout: all grow children expand to fill height
	if layout.config.layout_direction == .Left_To_Right {
		idx := current.index + 1
		end := current.index + current.subtree_size
		for idx < end {
			child_idx := idx
			child := &ctx.elements[child_idx]
			if child_layout, ok := child.attributes.(LayoutAttributes); ok {
				if _, ok := child_layout.config.height.(Grow_Size); ok {
					child.size.y = content_height
				}
			}
			idx += child.subtree_size
		}
		return
	}

	growables := ctx.growable_buffer
	clear(&growables)

	remaining_height := content_height
	child_count := 0

	idx, end := current.index + 1, current.index + current.subtree_size

	for idx < end {
		child_idx := idx
		child := ctx.elements[child_idx]
		if child_layout, ok := child.attributes.(LayoutAttributes); ok {
			remaining_height -= child.size.y
			if _, ok := child_layout.config.height.(Grow_Size); ok {
				append(&growables, child_idx)
			}
		}
		child_count += 1
		idx += child.subtree_size
	}

	if child_count > 0 {
		remaining_height -= f32(child_count - 1) * layout.config.child_gap
	}

	if len(growables) == 0 do return

	growable_count := len(growables)

	// Grow
	for remaining_height > math.F32_EPSILON && len(growables) > 0 {
		smallest := math.inf_f32(1)
		second_smallest := math.inf_f32(1)
		height_to_add := remaining_height

		for child in growables {
			child_ele := ctx.elements[child]
			if child_ele.size.y < smallest {
				second_smallest = smallest
				smallest = child_ele.size.y
			}
			if child_ele.size.y > second_smallest {
				second_smallest = min(second_smallest, child_ele.size.y)
				height_to_add = second_smallest - smallest
			}
		}
		height_to_add = min(height_to_add, remaining_height / f32(len(growables)))

		for i := 0; i < len(growables); {
			growable := growables[i]
			if ctx.elements[growable].size.y == smallest {
				growable_ele := &ctx.elements[growable]
				prev_size := growable_ele.size.y
				growable_ele.size.y += height_to_add

				if max_size, ok := growable_ele.limits.max_height.(f32);
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
		largest := math.inf_f32(-1)
		second_largest := math.inf_f32(-1)
		height_to_subtract := overshoot_height

		for child in shrinkables {
			child_ele := ctx.elements[child]
			if child_ele.size.y > largest {
				second_largest = largest
				largest = child_ele.size.y
			}
			if child_ele.size.y > second_largest {
				second_largest = max(second_largest, child_ele.size.y)
				height_to_subtract = largest - second_largest
			}
		}
		height_to_subtract = max(height_to_subtract, overshoot_height / f32(len(shrinkables)))

		for i := 0; i < len(shrinkables); {
			shrinkable := shrinkables[i]
			if ctx.elements[shrinkable].size.y == largest {
				shrinkable_ele := &ctx.elements[shrinkable]
				prev_size := shrinkable_ele.size.y
				shrinkable_ele.size.y -= height_to_subtract

				min_size := shrinkable_ele.limits.min_height.(f32) or_else 0
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
calculate_position_x :: proc(ctx: ^UI_Context, index: UI_Index = 0) {
	current := ctx.elements[index]
	layout, ok := current.attributes.(LayoutAttributes)
	if !ok do return

	left_offset := current.position.x + layout.config.padding.left

	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		child.position.x = left_offset

		if layout.config.layout_direction == .Left_To_Right {
			left_offset += child.size.x + layout.config.child_gap
		}

		calculate_position_x(ctx, child.index)
	}
}

@(private)
calculate_position_y :: proc(ctx: ^UI_Context, index: UI_Index = 0) {
	current := ctx.elements[index]
	layout, ok := current.attributes.(LayoutAttributes)
	if !ok do return

	top_offset := current.position.y + layout.config.padding.top

	for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
		child.position.y = top_offset

		if layout.config.layout_direction == .Top_To_Bottom {
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
			16,
			0,
			"assets/fonts/NotoSansMono-SemiBold.ttf",
			"assets/fonts/NotoSansMono-Regular.ttf",
		),
		text_measurer = text_measurer,
	}
}

ui_context_delete :: proc(ctx: UI_Context) {
	delete(ctx.elements)
	delete(ctx.open_element_stack)
	delete(ctx.render_commands)
	delete(ctx.growable_buffer)
	viewer_unload_font(ctx.default_font)
}

@(deferred_in_out = end_layout)
begin_layout :: proc(ctx: ^UI_Context, window_width: f32, window_height: f32) -> bool {
	// Create the root element at index 0
	root := root_layout(window_width, window_height)
	append(&ctx.elements, root)
	// Set its preorder_idx explicitly (it's 0)
	ctx.elements[0].index = 0
	append(&ctx.open_element_stack, 0)
	return true
}

@(private)
end_layout :: proc(ctx: ^UI_Context, _: f32, _: f32, ok: bool) {
	if !ok do return

	// Close the root – this computes sizes and subtree_size
	close_element(ctx)

	// Compute positions
	calculate_position_x(ctx)
	calculate_position_y(ctx)

	// Generate render commands
	clear(&ctx.render_commands)
	for ele in ctx.elements {
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
				layout_direction = .Left_To_Right,
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
	}
}

ui_get_id :: proc(ctx: UI_Context, index: UI_Index) -> string {
	return ctx.elements[index].id
}

@(private)
set_if_set :: proc(dest: ^$T, src: Maybe(T)) {
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
		min_width  = width.min,
		max_width  = width.max,
		min_height = height.min,
		max_height = height.max,
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
