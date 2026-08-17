package main

import "core:fmt"
import "core:math"
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
	open_element_stack: [dynamic]UI_Element_Index,
	child_array:        [dynamic]UI_Element_Index,
	growable_buffer:    [dynamic]UI_Element_Index,
	child_buffer_scope: UI_Element_Index,
	child_buffer:       [dynamic]UI_Element_Index,
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

UI_Element_Index :: distinct i32


Unset :: struct {}

UI_LayoutDeclare :: struct {
	id:               string,
	// config
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
	// config
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
	id:         string,
	position:   rl.Vector2,
	size:       rl.Vector2,
	parent:     UI_Element_Index,
	limits:     UI_Limits,
	attributes: union {
		LayoutAttributes,
		TextAttributes,
	},
}

UI_Limits :: struct {
	width_min:  Maybe(f32),
	width_max:  Maybe(f32),
	height_min: Maybe(f32),
	height_max: Maybe(f32),
}

LayoutAttributes :: struct {
	element:     UI_Element_Index,
	config:      UI_LayoutConfig,
	child_start: i32, // index to shared children arr
	child_count: i32, // count from children_start
}

TextAttributes :: struct {
	element: UI_Element_Index,
	config:  UI_TextConfig,
}


@(deferred_in_out = close_layout)
open_layout :: proc(ctx: ^UI_Context, declare: UI_LayoutDeclare) -> bool {
	parent := ctx.open_element_stack[len(ctx.open_element_stack) - 1]
	parent_ele := ctx.elements[parent]

	index := UI_Element_Index(len(ctx.elements))

	config, limits := parse_layout_declare(default_layout(), declare)
	ui_ele: UI_Element = {
		id = declare.id,
		parent = parent,
		attributes = LayoutAttributes{config = config, element = index},
		limits = limits,
	}

	append(&ctx.elements, ui_ele)
	append(&ctx.open_element_stack, UI_Element_Index(index))

	return true
}

@(deferred_in_out = close_text)
open_text :: proc(ctx: ^UI_Context, declare: UI_TextDeclare) -> bool {
	parent_idx := ctx.open_element_stack[len(ctx.open_element_stack) - 1]
	parent := ctx.elements[parent_idx]

	index := UI_Element_Index(len(ctx.elements))

	config, limits := parse_text_declare(default_text(ctx^), declare)
	ui_ele: UI_Element = {
		id = declare.id,
		parent = parent_idx,
		attributes = TextAttributes{config = config, element = index},
		limits = limits,
	}

	append(&ctx.elements, ui_ele)
	append(&ctx.open_element_stack, UI_Element_Index(index))

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

	gather_children(ctx, index)

	calculate_width(ctx, index)
	fit_sizing_widths(ctx, index)
	grow_and_shrink_sizing_widths(ctx, index)

	calculate_height(ctx, index)
	fit_sizing_heights(ctx, index)
	grow_and_shrink_sizing_height(ctx, index)

}

@(private)
gather_children :: proc(ctx: ^UI_Context, index: UI_Element_Index) {
	parent := ctx.elements[index].parent

	if len(ctx.child_buffer) > 0 {
		if ctx.child_buffer_scope == parent {
			// parent unchanged, gathering siblings
			append(&ctx.child_buffer, index)
			return
		} else {
			// parent changed, previously gathered chilren is this current element's children
			current_layout, ok := ctx.elements[index].attributes.(LayoutAttributes)
			assert(ok)

			current_layout.child_start = i32(len(ctx.child_array))
			current_layout.child_count = i32(len(ctx.child_buffer))

			fmt.println(ctx.elements[index].id, ":", ctx.child_buffer)

			append(&ctx.child_array, ..ctx.child_buffer[:])
			clear(&ctx.child_buffer)
		}
	}

	// initialize or right after children have been gathered
	if len(ctx.child_buffer) == 0 {
		clear(&ctx.child_buffer)
		ctx.child_buffer_scope = parent
		append(&ctx.child_buffer, index)
		return
	}
}

@(private)
grow_and_shrink_sizing_widths :: proc(ctx: ^UI_Context, index: UI_Element_Index) {
	current := ctx.elements[index]
	current_layout, ok := ctx.elements[index].attributes.(LayoutAttributes)

	if !ok || current_layout.child_count == 0 {
		return
	}

	// For verticle layout, expand all grow widths
	content_width := current.size.x
	content_width -= current_layout.config.padding.left + current_layout.config.padding.right

	if current_layout.config.layout_direction == .Top_To_Bottom {
		for child in ctx.child_array[current_layout.child_start:][:current_layout.child_count] {
			child_layout := ctx.elements[child].attributes.(LayoutAttributes) or_continue
			if _, ok := child_layout.config.width.(Grow_Size); ok {
				ctx.elements[child].size.x = content_width
			}
		}
		return
	}

	// Calculate remaining width
	remaining_width :=
		content_width - f32(current_layout.child_count - 1) * current_layout.config.child_gap

	for child in ctx.child_array[current_layout.child_start:][:current_layout.child_count] {
		remaining_width -= ctx.elements[child].size.x
	}

	growables := ctx.growable_buffer
	clear(&growables)

	// find all growables
	for child in ctx.child_array[current_layout.child_start:][:current_layout.child_count] {
		child_ele := ctx.elements[child]
		child_layout := child_ele.attributes.(LayoutAttributes) or_continue

		if _, ok := child_layout.config.width.(Grow_Size); ok {
			append(&growables, child)
		}
	}

	growable_count := len(growables)

	if growable_count == 0 {
		return
	}

	// Grow Sizing Widths 	
	for remaining_width > math.F32_EPSILON && len(growables) > 0 {
		smallest := math.inf_f32(1)
		second_smallest := math.inf_f32(1)

		// in case of all zero size growables we would just grow to remaining width
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

		// keep expand the smallest elements to the second smallest until there is no space left

		for i := 0; i < len(growables); {
			growable := growables[i]

			if ctx.elements[growable].size.x == smallest {
				growable_ele := &ctx.elements[growable]

				growable_layout, ok := growable_ele.attributes.(LayoutAttributes)
				assert(ok)

				prev_size := growable_ele.size.x
				growable_ele.size.x += width_to_add

				if max_size, ok := growable_ele.limits.width_max.(f32);
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

	// this resize won't cause reallocated since it's already at the current size
	// we reused swapped back values from unordered_remove() so we won't use resize()
	// which would zeroes out the later values
	non_zero_resize(&growables, growable_count)

	shrinkables := growables
	overshoot_width := -remaining_width

	// Shrink Sizing Widths 	
	for overshoot_width > math.F32_EPSILON && len(shrinkables) > 0 {
		largest := math.inf_f32(-1)
		second_largest := math.inf_f32(-1)

		width_to_substract := overshoot_width

		for child in shrinkables {
			child_ele := ctx.elements[child]

			if child_ele.size.x > largest {
				second_largest = largest
				largest = child_ele.size.x
			}

			if child_ele.size.x > second_largest {
				second_largest = max(second_largest, child_ele.size.x)
				width_to_substract = largest - second_largest
			}
		}

		width_to_substract = max(width_to_substract, overshoot_width / f32(len(shrinkables)))

		// keep shrinking the largest elements to the second largest until there is no space left

		for i := 0; i < len(shrinkables); {
			shrinkable := shrinkables[i]

			if ctx.elements[shrinkable].size.x == largest {
				shrinkable_ele := &ctx.elements[shrinkable]
				shrinkable_layout, ok := shrinkable_ele.attributes.(LayoutAttributes)
				assert(ok)

				prev_size := shrinkable_ele.size.x
				shrinkable_ele.size.x -= width_to_substract

				min_size := shrinkable_ele.limits.width_min.(f32) or_else 0
				if shrinkable_ele.size.x <= min_size {
					shrinkable_ele.size.x = min_size
					overshoot_width -= prev_size - min_size
					unordered_remove(&shrinkables, i)
					continue
				} else {
					overshoot_width -= width_to_substract
				}
			}

			i += 1
		}
	}
}

@(private)
grow_and_shrink_sizing_height :: proc(ctx: ^UI_Context, index: UI_Element_Index) {
	current := ctx.elements[index]
	current_layout, ok := ctx.elements[index].attributes.(LayoutAttributes)

	if !ok || current_layout.child_count == 0 {
		return
	}

	// For horizontal layout, expand all grow heights
	content_height := current.size.y
	content_height -= current_layout.config.padding.top + current_layout.config.padding.bottom

	if current_layout.config.layout_direction == .Left_To_Right {
		for child in ctx.child_array[current_layout.child_start:][:current_layout.child_count] {
			child_layout := ctx.elements[child].attributes.(LayoutAttributes) or_continue
			if _, ok := child_layout.config.height.(Grow_Size); ok {
				ctx.elements[child].size.y = content_height
			}
		}
		return
	}

	// Calculate remaining height
	remaining_height :=
		content_height - f32(current_layout.child_count - 1) * current_layout.config.child_gap

	for child in ctx.child_array[current_layout.child_start:][:current_layout.child_count] {
		remaining_height -= ctx.elements[child].size.y
	}

	growables := ctx.growable_buffer
	clear(&growables)

	// Find all growables
	for child in ctx.child_array[current_layout.child_start:][:current_layout.child_count] {
		child_ele := ctx.elements[child]
		child_layout := child_ele.attributes.(LayoutAttributes) or_continue

		if _, ok := child_layout.config.height.(Grow_Size); ok {
			append(&growables, child)
		}
	}

	growable_count := len(growables)

	if growable_count == 0 {
		return
	}

	// Grow Sizing Heights
	for remaining_height > math.F32_EPSILON && len(growables) > 0 {
		smallest := math.inf_f32(1)
		second_smallest := math.inf_f32(1)

		// In case of all zero-size growables, grow to the remaining height
		height_to_add := remaining_height

		for child in growables {
			child_ele := ctx.elements[child]

			if child_ele.size.y < smallest {
				second_smallest = smallest
				smallest = child_ele.size.y
			}

			if child_ele.size.y >= second_smallest {
				second_smallest = min(second_smallest, child_ele.size.y)
				height_to_add = second_smallest - smallest
			}
		}

		height_to_add = min(height_to_add, remaining_height / f32(len(growables)))

		// Keep expanding the smallest elements to the second smallest
		// until there is no space left or they hit their maximum size.
		for i := 0; i < len(growables); {
			growable := growables[i]

			if ctx.elements[growable].size.y == smallest {
				growable_ele := &ctx.elements[growable]

				growable_layout, ok := growable_ele.attributes.(LayoutAttributes)
				assert(ok)

				prev_size := growable_ele.size.y
				growable_ele.size.y += height_to_add

				if max_size, ok := growable_ele.limits.height_max.(f32);
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

	// This resize won't cause reallocation since it is already at the current size.
	// We reused swapped-back values from unordered_remove, so don't use resize()
	// which would zero the later values.
	non_zero_resize(&growables, growable_count)

	shrinkables := growables
	overshoot_height := -remaining_height

	// Shrink Sizing Heights
	for overshoot_height > math.F32_EPSILON && len(shrinkables) > 0 {
		largest := math.inf_f32(-1)
		second_largest := math.inf_f32(-1)

		width_to_substract := overshoot_height

		for child in shrinkables {
			child_ele := ctx.elements[child]

			if child_ele.size.y > largest {
				second_largest = largest
				largest = child_ele.size.y
			}

			if child_ele.size.y > second_largest {
				second_largest = max(second_largest, child_ele.size.y)
				width_to_substract = largest - second_largest
			}
		}

		width_to_substract = max(width_to_substract, overshoot_height / f32(len(shrinkables)))

		// Keep shrinking the largest elements to the second largest
		// until there is no space left or they hit their minimum size.
		for i := 0; i < len(shrinkables); {
			shrinkable := shrinkables[i]

			if ctx.elements[shrinkable].size.y == largest {
				shrinkable_ele := &ctx.elements[shrinkable]
				shrinkable_layout, ok := shrinkable_ele.attributes.(LayoutAttributes)
				assert(ok)

				prev_size := shrinkable_ele.size.y
				shrinkable_ele.size.y -= width_to_substract

				min_size := shrinkable_ele.limits.height_min.(f32) or_else 0
				if shrinkable_ele.size.y <= min_size {
					shrinkable_ele.size.y = min_size
					overshoot_height -= prev_size - min_size
					unordered_remove(&shrinkables, i)
					continue
				} else {
					overshoot_height -= width_to_substract
				}
			}

			i += 1
		}
	}
}


@(private)
calculate_width :: proc(ctx: ^UI_Context, index: UI_Element_Index) {
	current := &ctx.elements[index]

	if current_layout, ok := current.attributes.(LayoutAttributes); ok {
		if mode, ok := current_layout.config.width.(Fixed_Size); ok {
			current.size.x = mode.value
		}
	}

	current.size.x = clamp_element_size(
		current.size.x,
		current.limits.width_min,
		current.limits.width_max,
	)
}

@(private)
clamp_element_size :: proc(
	current_size: f32,
	maybe_min_size: Maybe(f32),
	maybe_max_size: Maybe(f32),
) -> f32 {
	res: f32 = current_size
	if min_size, ok := maybe_min_size.(f32); ok && res <= min_size {
		res = min_size
	}
	if max_size, ok := maybe_max_size.(f32); ok && res >= max_size {
		res = max_size
	}

	return res
}

@(private)
calculate_height :: proc(ctx: ^UI_Context, index: UI_Element_Index) {
	current := &ctx.elements[index]

	if current_layout, ok := current.attributes.(LayoutAttributes); ok {
		if mode, ok := current_layout.config.width.(Fixed_Size); ok {
			current.size.y = mode.value
		}
	}

	current.size.y = clamp_element_size(
		current.size.y,
		current.limits.height_min,
		current.limits.height_max,
	)
}


@(private)
fit_sizing_widths :: proc(ctx: ^UI_Context, index: UI_Element_Index) {
	current := ctx.elements[index]
	current_layout, ok := current.attributes.(LayoutAttributes)
	if !ok do return

	if mode, ok := current_layout.config.width.(Fixed_Size); ok {
		return
	}

	if current_layout.config.layout_direction == .Left_To_Right {
		for child in ctx.child_array[current_layout.child_start:][:current_layout.child_count] {
			current.size.x += ctx.elements[child].size.x
		}

		current.size.x += f32(current_layout.child_count - 1) * current_layout.config.child_gap
	} else {
		for child in ctx.child_array[current_layout.child_start:][:current_layout.child_count] {
			current.size.x = max(current.size.x, ctx.elements[child].size.x)
		}
	}

	if max_size, ok := current.limits.width_max.(f32); ok {
		current.size.x = max(max_size, current.size.x)
	}
}

@(private)
fit_sizing_heights :: proc(ctx: ^UI_Context, index: UI_Element_Index) {
	current := ctx.elements[index]
	current_layout, ok := current.attributes.(LayoutAttributes)
	if !ok do return

	if current_layout.config.layout_direction == .Top_To_Bottom {
		for child in ctx.child_array[current_layout.child_start:][:current_layout.child_count] {
			current.size.y += ctx.elements[child].size.y
		}

		current.size.y += f32(current_layout.child_count - 1) * current_layout.config.child_gap
	} else {
		for child in ctx.child_array[current_layout.child_start:][:current_layout.child_count] {
			current.size.y = max(current.size.y, ctx.elements[child].size.y)
		}
	}

	if max_size, ok := current.limits.height_max.(f32); ok {
		current.size.y = max(max_size, current.size.y)
	}
}

@(private)
calculate_position_x :: proc(ctx: ^UI_Context, index: UI_Element_Index = 0) {
	ui_ele := ctx.elements[index]
	layout, ok := ui_ele.attributes.(LayoutAttributes)
	if !ok do return

	left_offset := ui_ele.position.x + layout.config.padding.left

	for child in ctx.child_array[layout.child_start:][:layout.child_count] {
		ctx.elements[child].position.x = left_offset

		if layout.config.layout_direction == .Left_To_Right {
			left_offset += ctx.elements[child].size.x + layout.config.child_gap
		}

		calculate_position_x(ctx, child)
	}
}

@(private)
calculate_position_y :: proc(ctx: ^UI_Context, index: UI_Element_Index = 0) {
	ui_ele := ctx.elements[index]
	layout, ok := ui_ele.attributes.(LayoutAttributes)
	if !ok do return

	top_offset := ui_ele.position.y + layout.config.padding.top

	for child in ctx.child_array[layout.child_start:][:layout.child_count] {
		ctx.elements[child].position.y = top_offset

		if layout.config.layout_direction == .Top_To_Bottom {
			top_offset += ctx.elements[child].size.y + layout.config.child_gap

			if ctx.elements[child].size.y < 0 {
				fmt.println(ctx.elements[child].id, ctx.elements[child].size.y)
			}
		}

		calculate_position_y(ctx, child)
	}
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

ui_context_make :: proc() -> UI_Context {
	ctx: UI_Context = {
		elements           = make([dynamic]UI_Element, 0, 500),
		open_element_stack = make([dynamic]UI_Element_Index, 0, 50),
		child_array        = make([dynamic]UI_Element_Index, 0, 500),
		render_commands    = make([dynamic]Render_Command, 0, 500),
		growable_buffer    = make([dynamic]UI_Element_Index, 0, 500),
		child_buffer       = make([dynamic]UI_Element_Index, 0, 500),
		default_font       = viewer_load_font(
			16,
			0,
			"assets/fonts/NotoSansMono-SemiBold.ttf",
			"assets/fonts/NotoSansMono-Regular.ttf",
		),
	}

	return ctx
}

ui_context_delete :: proc(ctx: UI_Context) {
	delete(ctx.elements)
	delete(ctx.open_element_stack)
	delete(ctx.child_array)
	delete(ctx.render_commands)
	delete(ctx.growable_buffer)
	delete(ctx.child_buffer)
	viewer_unload_font(ctx.default_font)
}

ui_debug_draw_tree :: proc(ctx: UI_Context, index: UI_Element_Index = 0, cur_level: i32 = 1) {
	ele := ctx.elements[index]

	for i in 0 ..< cur_level - 1 {
		fmt.print(" . ")
	}

	layout, ok := ele.attributes.(LayoutAttributes)

	fmt.printf(
		"%v (%v) %vx%v (%v-%v)",
		ele.id,
		ctx.elements[ele.parent].id,
		ele.size.x,
		ele.size.y,
		ok ? layout.child_start : -1,
		ok ? layout.child_count : -1,
	)

	if ok {
		fmt.println(layout.config.layout_direction == .Left_To_Right ? "LTR" : "TTB")
		for child, slice_index in ctx.child_array[layout.child_start:][:layout.child_count] {
			ui_debug_draw_tree(ctx, child, cur_level + 1)
		}
	} else {
		fmt.println()
	}
}

@(deferred_in_out = end_layout)
begin_layout :: proc(ctx: ^UI_Context, window_width: f32, window_height: f32) -> bool {
	// sentinal root ele
	append(&ctx.open_element_stack, 0)
	append(&ctx.elements, root_layout(window_width, window_height))

	return true
}

@(private)
end_layout :: proc(ctx: ^UI_Context, _: f32, _: f32, ok: bool) {
	if !ok do return

	// closing root
	gather_children(ctx, 0)
	grow_and_shrink_sizing_widths(ctx, 0)
	grow_and_shrink_sizing_height(ctx, 0)

	clear(&ctx.render_commands)

	ui_debug_draw_tree(ctx^)

	calculate_position_x(ctx)
	calculate_position_y(ctx)

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

	clear(&ctx.elements)
	clear(&ctx.child_array)
	clear(&ctx.open_element_stack)
}


@(private)
root_layout :: proc(width: f32, height: f32) -> UI_Element {
	return UI_Element {
		id = "root",
		parent = 0,
		position = {0, 0},
		size = {width, height},
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


ui_get_id :: proc(ctx: UI_Context, index: UI_Element_Index) -> string {
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
	config: UI_LayoutConfig = default_config

	width, height: Sizing_Axis

	set_if_set(&width, declare.width)
	set_if_set(&height, declare.height)

	config.width = width.mode
	config.height = height.mode

	limits: UI_Limits = {
		width_min  = width.min,
		width_max  = width.max,
		height_min = height.min,
		height_max = height.max,
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
	default_config: UI_TextConfig,
	declare: UI_TextDeclare,
) -> (
	UI_TextConfig,
	UI_Limits,
) {
	config: UI_TextConfig = default_config

	set_if_set(&config.content, declare.content)
	set_if_set(&config.font_size, declare.font_size)
	set_if_set(&config.spacing, declare.spacing)
	set_if_set(&config.font, declare.font)

	limits: UI_Limits = {
		height_min = config.font_size,
		height_max = config.font_size,
		width_max  = 16 * config.font_size,
		width_min  = 4 * config.font_size,
	}

	return config, limits
}
