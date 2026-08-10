package main

import rl "vendor:raylib"

MAX_CHILD_COUNT :: 50

UI_Input :: struct {
	mouse_position:      rl.Vector2,
	mouse_pressed:       bool,
	mouse_just_pressed:  bool,
	mouse_just_released: bool,
	scroll:              rl.Vector2,
}


UI_Context :: struct {
	elements:            [dynamic]UI_Element,
	open_element_stack:  [dynamic]UI_Element_Index,
	shared_children_arr: [dynamic]UI_Element_Index,
	child_buffer:        [dynamic]UI_Element_Index,
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
	width:            Sizing_Axis,
	height:           Sizing_Axis,
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
	declaration:    UI_ElementDeclaration,
	position:       rl.Vector2,
	size:           rl.Vector2,
	parent:         UI_Element_Index,
	children_start: UI_Element_Index,
	children_count: i32,
}

@(deferred_in_out = close_element)
open_element :: proc(ctx: ^UI_Context, declr: UI_ElementDeclaration) -> bool {

	parent_idx := ctx.open_element_stack[len(ctx.open_element_stack) - 1]
	parent := ctx.elements[parent_idx]


	ui_ele := UI_Element {
		declaration = declr,
		parent      = parent_idx,
	}

	append(&ctx.elements, ui_ele)

	index := len(ctx.elements) - 1

	append(&ctx.open_element_stack, UI_Element_Index(index))

	return true
}

@(private)
close_element :: proc(ctx: ^UI_Context, declr: UI_ElementDeclaration, ok: bool) {
	if ok {
		index := ctx.open_element_stack[len(ctx.open_element_stack) - 1]
		ui_ele := ctx.elements[index]

		append(&ctx.shared_children_arr, index)

		chilren_slice := ctx.elements[ui_ele.parent].children
		ctx.elements[ui_ele.parent].children = chilren_slice[:len(chilren_slice) + 1]
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

init_ui_context :: proc() -> UI_Context {
	return {
		elements = make([dynamic]UI_Element, 0, 500),
		open_element_stack = make([dynamic]UI_Element_Index, 0, 50),
		shared_children_arr = make([dynamic]UI_Element_Index, 0, 50),
		child_buffer = make([dynamic]UI_Element_Index, 0, 10),
	}
}

deinit_ui_context :: proc(ctx: UI_Context) {
	delete(ctx.elements)
	delete(ctx.open_element_stack)
	delete(ctx.shared_children_arr)
	delete(ctx.child_buffer)
}
