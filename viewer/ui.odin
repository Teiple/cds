package main

import rl "vendor:raylib"

UI_Input :: struct {
	mouse_position:      rl.Vector2,
	mouse_pressed:       bool,
	mouse_just_pressed:  bool,
	mouse_just_released: bool,
	scroll:              rl.Vector2,
}


UI_Context :: struct {
	elements:           [dynamic]UI_Element,
	open_element_stack: [dynamic]UI_Element_Index,
}

Sizing_Axis :: struct {
	mode: Size_Mode,
	min:  Maybe(f32),
	max:  Maybe(f32),
}

Size_Mode :: union {
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
	Top_To_Bottom,
	Left_To_Right,
}

Layout_Padding :: struct {
	top:    f32,
	bottom: f32,
	right:  f32,
	left:   f32,
}

Layout_Sizing :: struct {
	width:  Sizing_Axis,
	height: Sizing_Axis,
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

Layout_Config :: struct {
	using sizing:     Layout_Sizing,
	padding:          Layout_Padding,
	child_gap:        f32,
	layout_direction: Layout_Direction,
	child_alignment:  Child_Alignment,
	background_color: rl.Color,
}

UI_ElementDeclaration :: struct {
	using layout: Layout_Config,
}

UI_Element :: struct {
	declaration: UI_ElementDeclaration,
	position:    rl.Vector2,
	size:        rl.Vector2,
	parent:      UI_Element_Index,
}

@(deferred_in_out = end_box)
box :: proc(ctx: ^UI_Context, declr: UI_ElementDeclaration) -> bool {

	parent := get_open_element_index(ctx)
	index := add_element(ctx, UI_Element{declaration = declr, parent = parent})
	push_open_element_index(ctx, index)

	return true
}

@(private)
end_box :: proc(ctx: ^UI_Context, declr: UI_ElementDeclaration, ok: bool) {
	if ok {
		cur_idx := ctx.current_element_count - 1
		cur_ele := ctx.elements[cur_idx]
	}
}

grow :: #force_inline proc(min: Maybe(f32) = nil, max: Maybe(f32) = nil) -> Sizing_Axis {
	return {mode = Grow_Size{}, min = min, max = max}
}

fixed :: #force_inline proc(
	value: f32,
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

@(private)
add_element :: proc(ctx: ^UI_Context, element: UI_Element) -> UI_Element_Index {
	append(&ctx.elements, element)
	return UI_Element_Index(len(ctx.elements) - 1)
}


@(private)
get_open_element_index :: proc(ctx: ^UI_Context) -> UI_Element_Index {
	return ctx.open_element_stack[len(ctx.open_element_stack) - 1]
}

@(private)
push_open_element_index :: proc(ctx: ^UI_Context, index: UI_Element_Index) {
	append(&ctx.open_element_stack, index)
}

@(private)
pop_open_element_index :: proc(ctx: ^UI_Context) -> UI_Element_Index {
	unordered_remove(ctx.open_element_stack, len(ctx.open_element_stack) - 1)
}
