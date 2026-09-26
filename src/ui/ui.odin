package ui

import "base:runtime"
import "core:fmt"
import "core:hash"
import "core:math"
import "core:unicode/utf8"

Rect :: struct {
	x:      f32,
	y:      f32,
	width:  f32,
	height: f32,
}

Texture_Id :: distinct u64
Font_Id :: distinct u32
Id :: u64

NPatch_Layout :: enum {
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
g_ui_builder: Builder

Axis :: enum {
	X,
	Y,
}

Element_Pointer_State :: enum {
	Away,
	Pressed,
	Down,
	Released,
	Hovered,
}

Pointer_Kind :: enum {
	Mouse,
	Touch,
}

Pointer_State :: enum {
	None,
	Pressed,
	Down,
	Released,
}

Pointer_Mode :: enum {
	Capture,
	Passthrough,
	Ignore,
}

Pointer :: struct {
	kind:     Pointer_Kind,
	state:    Pointer_State,
	position: [2]f32,
	delta:    [2]f32,
	scroll:   [2]f32,
	is_valid: bool,
}

Key_State :: enum {
	None,
	Pressed,
	Down,
	Released,
}

Key :: enum {
	Invalid,
	Tab,
	Enter,
	Escape,
	Space,
	Left,
	Up,
	Right,
	Down,
	Backspace,
	Delete,
	Home,
	End,
	A,
	C,
	V,
	X,
	Z,
}

Keyboard_Modifier :: enum {
	Shift,
	Ctrl,
	Alt,
	Super,
}

Keyboard_Modifiers :: bit_set[Keyboard_Modifier]

Keyboard :: struct {
	keys:       [Key]Key_State,
	modifiers:  Keyboard_Modifiers,
	characters: [dynamic]rune,
}

Input :: struct {
	pointer:  Pointer,
	keyboard: Keyboard,
}

Input_Event :: struct {
	pointer_captured:  bool,
	scroll_captured:   bool,
	keyboard_captured: bool,
	pressed_once:      bool,
	hovered_elements:  [dynamic]Id,
	pressed_elements:  [dynamic]Id,
	held_elements:     [dynamic]Id,
	unheld_elements:   [dynamic]Id,
	released_elements: [dynamic]Id,
	clicked_elements:  [dynamic]Id,
	scrolls:           map[Id]Scroll_Data,
	focusables:        [dynamic]Id,
	focused_id:        Id,
}

Scroll_Data :: struct #all_or_none {
	offset:         [2]f32,
	content_size:   [2]f32,
	min_offset:     [2]f32,
	pending_offset: Maybe([2]f32),
}

ClipData :: struct {
	open_clip_stack: [dynamic]Rect,
}


Nine_Patch_Config :: struct {
	source: Rect,
	left:   i32,
	top:    i32,
	right:  i32,
	bottom: i32,
	layout: NPatch_Layout,
}

Image_Fit :: enum {
	Stretch,
	Contain,
	Cover,
	Center,
}

Image :: struct {
	texture: Texture_Id,
	source:  Rect,
	tint:    [4]u8,
	fit:     Image_Fit,
	npatch:  Maybe(Nine_Patch_Config),
}

Image_Command :: struct #all_or_none {
	texture: Texture_Id,
	source:  Rect,
	dest:    Rect,
	npatch:  Maybe(Nine_Patch_Config),
	tint:    [4]u8,
	fit:     Image_Fit,
}

Gradient_Direction :: enum {
	Horizontal,
	Vertical,
}

Gradient_Stop :: struct {
	color:    [4]u8,
	position: f32,
}

Gradient :: struct {
	direction: Gradient_Direction,
	stops:     []Gradient_Stop,
}

Gradient_Rect_Command :: struct #all_or_none {
	rect:          Rect,
	corner_radius: Corner_Radius,
	border:        Border_Config,
	gradient:      Gradient,
}

Render_Command :: union {
	Rect_Command,
	Gradient_Rect_Command,
	Image_Command,
	Text_Command,
	Text_Edit_Command,
	Push_Clip_Command,
	Pop_Clip_Command,
}

Rect_Command :: struct #all_or_none {
	rect:          Rect,
	corner_radius: Corner_Radius,
	border:        Border_Config,
	color:         [4]u8,
}

Text_Command :: struct #all_or_none {
	font:         Font_Index,
	rect:         Rect,
	lines:        []string,
	font_size:    f32,
	spacing:      f32,
	line_spacing: f32,
	color:        [4]u8,
}

Text_Edit_Command :: struct #all_or_none {
	using text:      Text_Command,
	selection_range: [2]int,
	selection_color: [4]u8,
	cursor_index:    int,
	cursor_visible:  bool,
	cursor_color:    [4]u8,
	scroll_offset:   [2]f32,
}

Push_Clip_Command :: struct {
	rect: Rect,
}

Pop_Clip_Command :: struct {}

Pointer_Config :: struct {
	texture_id: Texture_Id,
	size:       f32,
	offset:     [2]f32,
}

Pointer_Attributes :: struct {
	config: Pointer_Config,
}


Glyph :: struct {
	xadvance: f32,
}

Font :: struct {
	base_size: f32,
	spacing:   f32,
	glyphs:    [96]Glyph,
}

Font_Config :: struct {
	base_size: f32,
	spacing:   f32,
}

Builder :: struct {
	current_context: ^Context,
	last_id:         Id,
	context_events:  Context_Events,
}

CTX_MAX_EVENT_LISTENERS :: 3
Context_Events :: struct {
	on_make:   [dynamic; CTX_MAX_EVENT_LISTENERS]proc(),
	on_delete: [dynamic; CTX_MAX_EVENT_LISTENERS]proc(),
	on_begin:  [dynamic; CTX_MAX_EVENT_LISTENERS]proc(),
	on_end:    [dynamic; CTX_MAX_EVENT_LISTENERS]proc(),
}

Clipboard_Get_Proc :: #type proc(user_data: rawptr) -> string
Clipboard_Set_Proc :: #type proc(text: string, user_data: rawptr)

Context :: struct {
	canvas_size:         [2]f32,
	elements:            [dynamic]Element,
	open_layout_stack:   [dynamic]Index,
	growable_buffer:     [dynamic]Index,
	wrapped_text_lines:  [dynamic]string,
	render_commands:     [dynamic]Render_Command,
	pointer:             Pointer_Attributes,
	fonts:               []Font,
	input:               Input,
	input_event:         Input_Event,
	clip:                ClipData,
	ids:                 map[Id]Id_Info,
	floats:              [dynamic]Index,
	bounds:              map[Id]Rect,
	entry_dir:           string,
	get_clipboard:       Clipboard_Get_Proc,
	set_clipboard:       Clipboard_Set_Proc,
	clipboard_user_data: rawptr,
}


Id_Info :: struct {
	base:       Id,
	index:      Index,
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

Padding :: struct {
	left:   f32,
	right:  f32,
	top:    f32,
	bottom: f32,
}

Corner_Radius :: struct {
	top_left:     f32,
	top_right:    f32,
	bottom_right: f32,
	bottom_left:  f32,
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

Index :: i32
Font_Index :: i32

Border_Config :: struct #all_or_none {
	thickness: f32,
	color:     [4]u8,
}

Outline_Config :: struct #all_or_none {
	thickness: f32,
	offset:    f32,
	color:     [4]u8,
}

Normalized_End :: enum {
	Start,
	End,
}

Element_Link :: struct {
	parent: Index,
	next:   Maybe(Index),
	prev:   Maybe(Index),
	last:   Maybe(Index),
}

Layout_Config :: struct {
	width:               Size_Mode,
	height:              Size_Mode,
	padding:             Padding,
	child_gap:           f32,
	layout_direction:    Layout_Direction,
	child_alignment:     [2]f32,
	background_color:    [4]u8,
	background_gradient: Maybe(Gradient),
	background_image:    Maybe(Image),
	corner_radius:       Corner_Radius,
	border:              Border_Config,
	outline:             Outline_Config,
	pointer_mode:        Pointer_Mode,
	clip:                bool,
	scroll:              bool,
	ignore_scroll:       bool,
	float_mode:          Float_Mode,
	offset:              [2]f32,
}


Float_Mode :: union {
	Float_None,
	Float_At_Parent,
	Float_At_Id,
	Float_At_Root,
}

Float_None :: struct {}
Float_At_Id :: struct {
	attach_id: Id,
	using _:   Float_Config,
}
Float_At_Parent :: struct {
	using _: Float_Config,
}
Float_At_Root :: struct {
	using _: Float_Config,
}

Float_Attach_Points :: struct {
	element: Anchor_Point,
	parent:  Anchor_Point,
}

Float_Config :: struct {
	attach_points: Float_Attach_Points,
	offset:        [2]f32,
	z_index:       i32,
}

Anchor_Point :: enum {
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

Text_Config :: struct {
	content:      string,
	font_index:   Font_Index,
	font_size:    f32,
	color:        [4]u8,
	line_spacing: f32,
	alignment:    [2]f32,
}

Text_Edit_Config :: struct {
	using text:      Text_Config,
	selection_range: [2]int,
	selection_color: [4]u8,
	cursor_index:    int,
	cursor_visible:  bool,
	cursor_color:    [4]u8,
	scroll_offset:   [2]f32,
	multiline:       bool,
	wrap:            bool,
}

Element :: struct {
	position:   [2]f32,
	size:       [2]f32,
	limits:     Limits,
	link:       Element_Link,
	id:         Id,
	attributes: union {
		Layout_Attributes,
		Text_Attributes,
		Text_Edit_Attributes,
	},
}

Element_Bound :: struct {
	position: [2]f32,
	size:     [2]f32,
}

Axis_Limits :: struct {
	min: Maybe(f32),
	max: Maybe(f32),
}

Limits :: struct {
	x: Axis_Limits,
	y: Axis_Limits,
}

Layout_Attributes :: struct {
	config: Layout_Config,
}

Text_Attributes :: struct {
	config:                   Text_Config,
	preferred_size:           [2]f32,
	bound_size:               [2]f32,
	wrapped_text_lines_start: i32,
	wrapped_text_lines_count: i32,
}

Text_Edit_Attributes :: struct {
	config:                   Text_Edit_Config,
	preferred_size:           [2]f32,
	bound_size:               [2]f32,
	wrapped_text_lines_start: i32,
	wrapped_text_lines_count: i32,
}

Child_Iter :: struct {
	ctx:  ^Context,
	next: Maybe(Index),
}

@(require_results)
push_and_dedupe_id :: proc(ctx: ^Context, index: Index, id: Id) -> Id {
	if id_entry, ok := ctx.ids[id]; ok {
		id_entry.loop_count += 1

		ctx.ids[id] = id_entry

		loop_tag := "loop"
		loop_tail := transmute([4]u8)id_entry.loop_count

		new_id := hash.fnv64a(transmute([]u8)loop_tag, id)
		new_id = hash.fnv64a(loop_tail[:], new_id)

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

push_id :: proc(ctx: ^Context, index: Index, id: Id) {
	_, existed := ctx.ids[id]
	if existed {
		panic("Duplicate ids without manually using dedupe")
	}
	ctx.ids[id] = {
		base       = id,
		index      = index,
		loop_count = 1,
	}
}

is_floating_element :: proc(ctx: ^Context, index: Index) -> bool {
	ele := &ctx.elements[index]
	if attr, ok := ele.attributes.(Layout_Attributes); ok {
		return attr.config.float_mode != Float_None{}
	}
	return false
}

open_layout :: proc(
	ctx: ^Context,
	id: Id,
	config: Layout_Config,
	limits: Limits,
) -> bool {
	parent := back(ctx.open_layout_stack)
	index := Index(len(ctx.elements))

	ui_ele := Element {
		id = id,
		attributes = Layout_Attributes{config = config},
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
	if is_floating_element(ctx, index) {
		append(&ctx.floats, index)
	}

	return true
}

open_text :: proc(ctx: ^Context, id: Id, config: Text_Config) {
	parent_idx := back(ctx.open_layout_stack)
	index := Index(len(ctx.elements))

	ui_ele := Element {
		id = id,
		attributes = Text_Attributes{config = config},
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

open_text_edit :: proc(ctx: ^Context, id: Id, config: Text_Edit_Config) {
	parent_idx := back(ctx.open_layout_stack)
	index := Index(len(ctx.elements))

	ui_ele := Element {
		id = id,
		attributes = Text_Edit_Attributes{config = config},
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

close_layout :: proc(ctx: ^Context, loc := #caller_location) {
	index := pop(&ctx.open_layout_stack)
	ele := &ctx.elements[index]
}

measure_text_width :: proc(input: Text_Config, font_info: Font) -> f32 {
	scale :=
		font_info.base_size > 0 ? (input.font_size / font_info.base_size) : 1.0
	width: f32 = 0
	for ch in input.content {
		if ch < 32 || ch >= 128 do continue
		width +=
			font_info.glyphs[ch - 32].xadvance * scale +
			font_info.spacing * scale
	}
	return width
}

calculate_text_width :: proc(ctx: ^Context, index: Index) {
	current := &ctx.elements[index]
	config: Text_Config
	preferred_size: ^[2]f32
	multiline := true
	#partial switch &attr in current.attributes {
	case Text_Attributes:
		config = attr.config
		preferred_size = &attr.preferred_size
	case Text_Edit_Attributes:
		config = attr.config.text
		preferred_size = &attr.preferred_size
		multiline = attr.config.multiline
	case:
		return
	}

	content := config.content
	max_line_width := f32(0)
	largest_word_width := f32(0)

	if !multiline {
		config.content = content
		max_line_width = measure_text_width(
			config,
			ctx.fonts[config.font_index],
		)
	} else {
		line_start := 0
		for byte_index := 0; byte_index <= len(content); byte_index += 1 {
			is_newline :=
				byte_index == len(content) || content[byte_index] == '\n'
			if is_newline {
				line_end := byte_index
				if line_end > line_start && content[line_end - 1] == '\r' {
					line_end -= 1
				}
				config.content = content[line_start:line_end]
				line_w := measure_text_width(
					config,
					ctx.fonts[config.font_index],
				)
				if line_w > max_line_width {
					max_line_width = line_w
				}
				line_start = byte_index + 1
			}
		}
	}

	preferred_size.x = max_line_width
	preferred_size.y = config.font_size
	current.size.x = preferred_size.x

	{
		word_start := 0
		byte_index := 0
		for byte_index < len(content) {
			whitespace_start := byte_index

			for byte_index < len(content) {
				r, size := utf8.decode_rune(content[byte_index:])
				if !is_separator(r) && r != '\n' && r != '\r' {
					break
				}
				byte_index += size
			}

			word_start = byte_index

			for byte_index < len(content) {
				r, size := utf8.decode_rune(content[byte_index:])
				if is_separator(r) || r == '\n' || r == '\r' {
					break
				}
				byte_index += size
			}

			word_end := byte_index

			if word_start == word_end {
				break
			}

			config.content = content[word_start:word_end]

			word_width := measure_text_width(
				config,
				ctx.fonts[config.font_index],
			)

			if word_width > largest_word_width {
				largest_word_width = word_width
			}
		}

		current.limits.x.min = largest_word_width
	}

	current.size.x = clamp_element_size(current.size.x, current.limits.x)
}

clamp_element_size :: proc(current_size: f32, limits: Axis_Limits) -> f32 {
	res := current_size
	if min_size, ok := limits.min.(f32); ok && res <= min_size {
		res = min_size
	}
	if max_size, ok := limits.max.(f32); ok && res >= max_size {
		res = max_size
	}
	return res
}

fit_sizing :: proc(ctx: ^Context, index: Index, axis: Axis) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(Layout_Attributes)
	if !ok do return

	if fixed_val, ok := layout_get_mode(layout, axis).(Fixed_Size); ok {
		ele_set_min(current, fixed_val.value, axis)
		ele_set_max(current, fixed_val.value, axis)
		ele_set_size(current, fixed_val.value, axis)
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
		ele_set_min(
			current,
			max(ele_get_min(current, axis), children_min_size),
			axis,
		)
	}
	ele_set_size(
		current,
		clamp_element_size(children_size, ele_get_lims(current, axis)),
		axis,
	)
}

fit_sizing_tree :: proc(ctx: ^Context, index: Index, axis: Axis) {
	for it := child_iter_start(ctx, index); child, child_index in child_iter_next(&it) {
		fit_sizing_tree(ctx, child_index, axis)
	}
	fit_sizing(ctx, index, axis)
}

grow_and_percent_sizing :: proc(ctx: ^Context, index: Index, axis: Axis) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(Layout_Attributes)
	if !ok || current.link.last == nil do return

	available := ele_get_size(current, axis) - layout_get_pad(layout, axis)
	percent_basis := available

	if layout_is_across(layout, axis) {
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			if is_grow_layout_or_text(child^, axis) {
				ele_set_size(
					child,
					clamp_element_size(available, ele_get_lims(child, axis)),
					axis,
				)
			} else if percent_size, ok := layout_get_mode(
				   child^,
				   axis,
			   ).(Percent_Size); ok {
				ele_set_size(
					child,
					clamp_element_size(
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
	for it := child_iter_start(ctx, index); child in child_iter_next(&it) do child_count += 1
	if child_count == 0 do return

	gap_total := f32(child_count - 1) * layout.config.child_gap

	remaining := available - gap_total
	percent_basis -= gap_total

	for it := child_iter_start(ctx, index); child, child_index in child_iter_next(&it) {
		if is_grow_layout_or_text(child^, axis) {
			append(growables, child_index)
		} else if percent_size, ok := layout_get_mode(
			   child^,
			   axis,
		   ).(Percent_Size); ok {
			ele_set_size(
				child,
				clamp_element_size(
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

grow_and_percent_sizing_tree :: proc(ctx: ^Context, index: Index, axis: Axis) {
	grow_and_percent_sizing(ctx, index, axis)
	for it := child_iter_start(ctx, index); child, child_index in child_iter_next(&it) {
		grow_and_percent_sizing_tree(ctx, child_index, axis)
	}
}

is_separator :: #force_inline proc(r: rune) -> bool {
	for sep in WORD_SEPARATION_CHARS {
		if r == sep {
			return true
		}
	}
	return false
}

wrap_texts :: proc(ctx: ^Context, index: Index = 0) {
	for it := child_iter_start(ctx, index); ele, child_index in child_iter_next(&it) {
		config: Text_Config
		preferred_size: [2]f32
		bound_size: ^[2]f32
		wrapped_text_lines_start: ^i32
		wrapped_text_lines_count: ^i32
		multiline := true
		wrap := true

		#partial switch &attr in ele.attributes {
		case Text_Attributes:
			config = attr.config
			preferred_size = attr.preferred_size
			bound_size = &attr.bound_size
			wrapped_text_lines_start = &attr.wrapped_text_lines_start
			wrapped_text_lines_count = &attr.wrapped_text_lines_count
		case Text_Edit_Attributes:
			config = attr.config.text
			preferred_size = attr.preferred_size
			bound_size = &attr.bound_size
			wrapped_text_lines_start = &attr.wrapped_text_lines_start
			wrapped_text_lines_count = &attr.wrapped_text_lines_count
			multiline = attr.config.multiline
			wrap = attr.config.wrap
		case:
			wrap_texts(ctx, child_index)
			continue
		}

		content := config.content

		wrapped_start := len(ctx.wrapped_text_lines)
		wrapped_count := 0

		defer {
			wrapped_text_lines_start^ = i32(wrapped_start)
			wrapped_text_lines_count^ = i32(wrapped_count)

			if wrapped_count > 1 {
				ele.size.y =
					config.font_size * f32(wrapped_count) +
					f32(wrapped_count - 1) * config.line_spacing
				bound_size.x = wrap ? ele.size.x : preferred_size.x
			} else {
				ele.size.y = config.font_size
				bound_size.x = preferred_size.x
			}
			ele.limits.y.min = ele.size.y
			bound_size.y = ele.size.y
		}

		if !multiline {
			append(&ctx.wrapped_text_lines, content)
			wrapped_count += 1
			continue
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

			if !wrap {
				append(&ctx.wrapped_text_lines, raw_line)
				wrapped_count += 1
				continue
			}

			config.content = raw_line
			line_w := measure_text_width(config, ctx.fonts[config.font_index])

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
					if !is_separator(r) {
						break
					}
					byte_index += size
				}

				word_start := byte_index

				for byte_index < len(raw_line) {
					r, size := utf8.decode_rune(raw_line[byte_index:])
					if is_separator(r) {
						break
					}
					byte_index += size
				}

				word_end := byte_index

				if word_start == word_end {
					break
				}

				config.content = raw_line[whitespace_start:word_start]
				whitespace_width := measure_text_width(
					config,
					ctx.fonts[config.font_index],
				)

				config.content = raw_line[word_start:word_end]
				word_width := measure_text_width(
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


get_anchor_point :: proc(ele: Element, anchor: Anchor_Point) -> [2]f32 {
	return ele.position + ele.size * get_anchor_offset(anchor)
}

get_anchor_offset :: proc(anchor: Anchor_Point) -> [2]f32 {
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

calculate_position :: proc(ctx: ^Context, index: Index) {
	current := &ctx.elements[index]
	layout, ok := current.attributes.(Layout_Attributes)
	if !ok {
		config_alignment: [2]f32
		preferred_size: [2]f32
		bound_size: [2]f32
		#partial switch attr in current.attributes {
		case Text_Attributes:
			config_alignment = attr.config.alignment
			preferred_size = attr.preferred_size
			bound_size = attr.bound_size
		case Text_Edit_Attributes:
			config_alignment = attr.config.alignment
			preferred_size = attr.preferred_size
			bound_size = attr.bound_size
		}

		for axis in Axis {
			pref := axis == .X ? preferred_size.x : preferred_size.y
			bound := axis == .X ? bound_size.x : bound_size.y
			if ele_get_size(current, axis) > pref {
				remaining := ele_get_size(current, axis) - pref
				align_offset :=
					remaining * align_get_offset(config_alignment, axis)
				ele_set_pos(
					current,
					ele_get_pos(current, axis) + align_offset,
					axis,
				)
			}

			ele_set_size(current, bound, axis)
		}

		return
	}

	scroll_data := ctx.input_event.scrolls[current.id]
	scroll_offsets := [Axis]f32 {
		.X = scroll_data.offset.x,
		.Y = scroll_data.offset.y,
	}

	offsets: [Axis]f32
	for axis in Axis {
		offsets[axis] =
			ele_get_pos(current, axis) +
			layout_get_pad_at(layout, axis, .Start) +
			scroll_offsets[axis]

		if layout_is_along(layout, axis) {
			remaining :=
				ele_get_size(current, axis) - layout_get_pad(layout, axis)

			child_count := 0
			for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
				remaining -= ele_get_size(child, axis)
				child_count += 1
			}

			if child_count > 0 {
				remaining -= f32(child_count - 1) * layout.config.child_gap
			}

			offsets[axis] +=
				remaining *
				align_get_offset(layout.config.child_alignment, axis)
		}
	}

	for it := child_iter_start(ctx, index); child, child_index in child_iter_next(&it) {
		child_layout, is_child_layout := child.attributes.(Layout_Attributes)

		for axis in Axis {
			child_offset :=
				offsets[axis] +
				(is_child_layout ? ((child_layout.config.ignore_scroll ? -scroll_offsets[axis] : 0) + layout_get_final_offset(child_layout, axis)) : 0)

			ele_set_pos(child, child_offset, axis)

			if layout_is_across(layout, axis) {
				remaining :=
					ele_get_size(current, axis) -
					layout_get_pad(layout, axis) -
					ele_get_size(child, axis)

				align_offset :=
					remaining *
					align_get_offset(layout.config.child_alignment, axis)

				ele_set_pos(
					child,
					ele_get_pos(child, axis) + align_offset,
					axis,
				)
			} else {
				offsets[axis] +=
					ele_get_size(child, axis) + layout.config.child_gap
			}
		}

		calculate_position(ctx, child_index)
	}
}

make_context :: proc(
	pointer: Pointer_Config = {texture_id = 0, size = 16, offset = {0, 0}},
	fonts: []Font = {},
	entry_dir: string = "",
	get_clipboard: Clipboard_Get_Proc = nil,
	set_clipboard: Clipboard_Set_Proc = nil,
	clipboard_user_data: rawptr = nil,
) -> Context {
	for event in g_ui_builder.context_events.on_make {
		event()
	}

	fonts_copy := make([]Font, len(fonts))
	copy(fonts_copy, fonts)

	return Context {
		elements = make([dynamic]Element, 0, 5),
		open_layout_stack = make([dynamic]Index, 0, 5),
		render_commands = make([dynamic]Render_Command, 0, 5),
		growable_buffer = make([dynamic]Index, 0, 5),
		wrapped_text_lines = make([dynamic]string, 0, 5),
		pointer = {config = pointer},
		fonts = fonts_copy,
		input = {keyboard = {characters = make([dynamic]rune, 0, 16)}},
		input_event = {
			pointer_captured = false,
			hovered_elements = make([dynamic]Id, 0, 4),
			pressed_elements = make([dynamic]Id, 0, 4),
			held_elements = make([dynamic]Id, 0, 4),
			unheld_elements = make([dynamic]Id, 0, 4),
			released_elements = make([dynamic]Id, 0, 4),
			clicked_elements = make([dynamic]Id, 0, 4),
			scrolls = make(map[Id]Scroll_Data, 4),
			focusables = make([dynamic]Id, 0, 16),
			focused_id = 0,
		},
		clip = {open_clip_stack = make([dynamic]Rect, 0, 2)},
		ids = make(map[Id]Id_Info, 50),
		floats = make([dynamic]Index, 0, 4),
		bounds = make(map[Id]Rect, 50),
		entry_dir = entry_dir,
		get_clipboard = get_clipboard,
		set_clipboard = set_clipboard,
		clipboard_user_data = clipboard_user_data,
	}
}

delete_context :: proc(ctx: Context) {
	for event in g_ui_builder.context_events.on_delete {
		event()
	}

	delete(ctx.elements)
	delete(ctx.open_layout_stack)
	delete(ctx.render_commands)
	delete(ctx.growable_buffer)
	delete(ctx.wrapped_text_lines)
	delete(ctx.fonts)
	delete(ctx.input.keyboard.characters)

	delete(ctx.input_event.hovered_elements)
	delete(ctx.input_event.pressed_elements)
	delete(ctx.input_event.held_elements)
	delete(ctx.input_event.unheld_elements)
	delete(ctx.input_event.released_elements)
	delete(ctx.input_event.clicked_elements)
	delete(ctx.input_event.scrolls)
	delete(ctx.input_event.focusables)
	delete(ctx.clip.open_clip_stack)
	delete(ctx.ids)
	delete(ctx.floats)
	delete(ctx.bounds)
}

@(require_results, deferred_in_out = end)
begin :: proc(ctx: ^Context, canvas_size: [2]f32) -> bool {
	g_ui_builder.current_context = ctx
	for p in g_ui_builder.context_events.on_begin do p()

	ctx.canvas_size = canvas_size

	clear(&ctx.ids)
	clear(&ctx.elements)
	clear(&ctx.open_layout_stack)
	clear(&ctx.floats)
	clear(&ctx.input_event.focusables)
	ctx.input_event.keyboard_captured = false

	append(&ctx.elements, root_layout(canvas_size))
	append(&ctx.open_layout_stack, 0)

	clear(&ctx.render_commands)
	clear(&ctx.growable_buffer)
	clear(&ctx.wrapped_text_lines)

	return true
}

end :: proc(ctx: ^Context, _: [2]f32, ok: bool) {
	if !ok do return

	// close root
	close_layout(ctx)

	fit_sizing_tree(ctx, 0, .X)
	grow_and_percent_sizing_tree(ctx, 0, .X)
	wrap_texts(ctx, 0)

	fit_sizing_tree(ctx, 0, .Y)
	grow_and_percent_sizing_tree(ctx, 0, .Y)

	calculate_position(ctx, 0)

	handle_floats(ctx)

	// generate render commands
	clear(&ctx.render_commands)
	clear(&ctx.clip.open_clip_stack)

	generate_commands(ctx, 0)

	// sort floats by z_index ascending for rendering
	sort_floats_by_zindex(ctx, ctx.floats[:])
	for idx in ctx.floats {
		generate_commands(ctx, idx)
	}

	// pointer input
	{
		ctx.input_event.pointer_captured = false
		ctx.input_event.scroll_captured = false
		ctx.input_event.pressed_once = false

		clear(&ctx.input_event.hovered_elements)
		clear(&ctx.input_event.pressed_elements)
		clear(&ctx.input_event.unheld_elements)
		clear(&ctx.input_event.released_elements)
		clear(&ctx.input_event.clicked_elements)
		clear(&ctx.clip.open_clip_stack)

		// detect pointer input on floats first, in reverse z index order
		#reverse for idx in ctx.floats {
			detect_pointer(ctx, idx)
			if ctx.input_event.pointer_captured && ctx.input_event.scroll_captured do break
		}
		// then the normal layout layer
		detect_pointer(ctx, 0)

		if ctx.input.pointer.state == .Released {
			append(
				&ctx.input_event.unheld_elements,
				..ctx.input_event.held_elements[:],
			)
			clear(&ctx.input_event.held_elements)
		}
	}

	if len(ctx.input_event.clicked_elements) > 0 {
		ctx.input_event.focused_id = ctx.input_event.clicked_elements[0]
	}

	if !ctx.input_event.keyboard_captured {
		if ctx.input.keyboard.keys[.Tab] == .Pressed {
			if .Shift in ctx.input.keyboard.modifiers {
				focus_previous_in_ctx(ctx)
			} else {
				focus_next_in_ctx(ctx)
			}
		}

		if ctx.input.keyboard.keys[.Enter] == .Pressed ||
		   ctx.input.keyboard.keys[.Space] == .Pressed {
			if ctx.input_event.focused_id != 0 {
				append(
					&ctx.input_event.held_elements,
					ctx.input_event.focused_id,
				)
			}
		}

		if ctx.input.keyboard.keys[.Enter] == .Released ||
		   ctx.input.keyboard.keys[.Space] == .Released {
			if ctx.input_event.focused_id != 0 &&
			   is_id_held(ctx.input_event.focused_id) {
				append(
					&ctx.input_event.clicked_elements,
					ctx.input_event.focused_id,
				)
				clear(&ctx.input_event.held_elements)
			}
		}
	}

	// write bounds, forward to later frame
	clear(&ctx.bounds)
	for ele in ctx.elements {
		ctx.bounds[ele.id] = ele_get_rect(ele)
	}

	for p in g_ui_builder.context_events.on_end do p()
}

@(private = "file")
focus_next_in_ctx :: proc(ctx: ^Context) {
	if len(ctx.input_event.focusables) == 0 do return
	current_idx := -1
	for id, i in ctx.input_event.focusables {
		if id == ctx.input_event.focused_id {
			current_idx = i
			break
		}
	}
	next_idx := (current_idx + 1) % len(ctx.input_event.focusables)
	ctx.input_event.focused_id = ctx.input_event.focusables[next_idx]
}

@(private = "file")
focus_previous_in_ctx :: proc(ctx: ^Context) {
	if len(ctx.input_event.focusables) == 0 do return
	current_idx := -1
	for id, i in ctx.input_event.focusables {
		if id == ctx.input_event.focused_id {
			current_idx = i
			break
		}
	}
	prev_idx :=
		current_idx <= 0 ? len(ctx.input_event.focusables) - 1 : current_idx - 1
	ctx.input_event.focused_id = ctx.input_event.focusables[prev_idx]
}

handle_floats :: proc(ctx: ^Context) {
	grow_and_percent_float_root :: proc(
		ctx: ^Context,
		index: Index,
		axis: Axis,
	) {
		current := &ctx.elements[index]
		layout := ctx.elements[index].attributes.(Layout_Attributes)

		float_parent_index, _ := get_float_target(
			ctx^,
			index,
			layout.config.float_mode,
		)

		float_parent := &ctx.elements[float_parent_index]

		#partial switch mode in layout_get_mode(layout, axis) {
		case Grow_Size:
			size := clamp_element_size(
				ele_get_size(float_parent, axis),
				ele_get_lims(current, axis),
			)
			ele_set_size(current, size, axis)
		case Percent_Size:
			size := clamp_element_size(
				mode.value * ele_get_size(float_parent, axis),
				ele_get_lims(current, axis),
			)
			ele_set_size(current, size, axis)
		}
	}

	calculate_float_root_position :: proc(ctx: ^Context, index: Index) {
		ele := &ctx.elements[index]
		layout := ele.attributes.(Layout_Attributes)

		target_index, float_config := get_float_target(
			ctx^,
			index,
			layout.config.float_mode,
		)

		element_offset :=
			ele.size * get_anchor_offset(float_config.attach_points.element)
		target_anchor := get_anchor_point(
			ctx.elements[target_index],
			float_config.attach_points.parent,
		)

		pos := target_anchor - element_offset + float_config.offset
		ele.position = pos
	}

	for float_index in ctx.floats {
		// only fit sizing includes direct sizing on current layout,
		// grow and percent sizing only calculate children sizing
		fit_sizing_tree(ctx, float_index, .X)

		grow_and_percent_float_root(ctx, float_index, .X)
		grow_and_percent_sizing_tree(ctx, float_index, .X)
		wrap_texts(ctx, float_index)

		fit_sizing_tree(ctx, float_index, .Y)

		grow_and_percent_float_root(ctx, float_index, .Y)
		grow_and_percent_sizing_tree(ctx, float_index, .Y)

		calculate_float_root_position(ctx, float_index)
		calculate_position(ctx, float_index)
	}
}


generate_commands :: proc(ctx: ^Context, index: Index) {
	ele := &ctx.elements[index]

	switch attr in ele.attributes {
	case Layout_Attributes:
		if bg_grad, ok := attr.config.background_gradient.?; ok {
			append(
				&ctx.render_commands,
				Gradient_Rect_Command{
					rect = {
						ele.position.x,
						ele.position.y,
						ele.size.x,
						ele.size.y,
					},
					gradient = bg_grad,
					corner_radius = attr.config.corner_radius,
					border = attr.config.border,
				},
			)
		} else if attr.config.background_color.a > 0 ||
		   attr.config.border.thickness > 0 {
			append(
				&ctx.render_commands,
				Rect_Command{
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
		if attr.config.outline.thickness > 0 &&
		   attr.config.outline.color.a > 0 {
			off := attr.config.outline.offset
			append(
				&ctx.render_commands,
				Rect_Command{
					rect = {
						ele.position.x - off,
						ele.position.y - off,
						ele.size.x + off * 2,
						ele.size.y + off * 2,
					},
					color = {0, 0, 0, 0},
					corner_radius = {
						attr.config.corner_radius.top_left > 0 ? attr.config.corner_radius.top_left + off : 0,
						attr.config.corner_radius.top_right > 0 ? attr.config.corner_radius.top_right + off : 0,
						attr.config.corner_radius.bottom_right > 0 ? attr.config.corner_radius.bottom_right + off : 0,
						attr.config.corner_radius.bottom_left > 0 ? attr.config.corner_radius.bottom_left + off : 0,
					},
					border = {
						thickness = attr.config.outline.thickness,
						color = attr.config.outline.color,
					},
				},
			)
		}
		if bg_img, ok := attr.config.background_image.?; ok {
			append(
				&ctx.render_commands,
				Image_Command{
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
		if attr.config.clip && !is_floating_element(ctx, index) {
			append(
				&ctx.render_commands,
				Push_Clip_Command{
					rect = {
						ele.position.x,
						ele.position.y,
						ele.size.x,
						ele.size.y,
					},
				},
			)
		}
	case Text_Attributes:
		append(
			&ctx.render_commands,
			Text_Command{
				font = attr.config.font_index,
				font_size = attr.config.font_size,
				spacing = ctx.fonts[attr.config.font_index].spacing,
				line_spacing = attr.config.line_spacing,
				color = attr.config.color,
				lines = ctx.wrapped_text_lines[attr.wrapped_text_lines_start:][:attr.wrapped_text_lines_count],
				rect = {
					ele.position.x,
					ele.position.y,
					attr.bound_size.x,
					attr.bound_size.y,
				},
			},
		)
	case Text_Edit_Attributes:
		append(
			&ctx.render_commands,
			Text_Edit_Command{
				text = {
					font = attr.config.font_index,
					font_size = attr.config.font_size,
					spacing = ctx.fonts[attr.config.font_index].spacing,
					line_spacing = attr.config.line_spacing,
					color = attr.config.color,
					lines = ctx.wrapped_text_lines[attr.wrapped_text_lines_start:][:attr.wrapped_text_lines_count],
					rect = {
						ele.position.x,
						ele.position.y,
						attr.bound_size.x,
						attr.bound_size.y,
					},
				},
				selection_range = attr.config.selection_range,
				selection_color = attr.config.selection_color,
				cursor_index = attr.config.cursor_index,
				cursor_visible = attr.config.cursor_visible,
				cursor_color = attr.config.cursor_color,
				scroll_offset = attr.config.scroll_offset,
			},
		)
	}

	for it := child_iter_start(ctx, index); child, child_index in child_iter_next(&it) {
		generate_commands(ctx, child_index)
	}

	if layout_attr, ok := ele.attributes.(Layout_Attributes);
	   ok && layout_attr.config.clip && !is_floating_element(ctx, index) {
		append(&ctx.render_commands, Pop_Clip_Command{})
	}
}

detect_pointer :: proc(ctx: ^Context, index: Index) {
	detect_pointer_should_stop :: proc(input_event: Input_Event) -> bool {
		return input_event.pointer_captured && input_event.scroll_captured
	}

	if detect_pointer_should_stop(ctx.input_event) {
		return
	}

	travel_tree_reverse(ctx, index, on_down = proc(ctx: ^Context, idx: i32) -> (stop: bool) {
			ele := ctx.elements[idx]

			layout := ele.attributes.(Layout_Attributes) or_return
			ele_rect := ele_get_rect(ele)

			if layout.config.clip && !is_floating_element(ctx, idx) {
				if len(ctx.clip.open_clip_stack) == 0 {
					append(&ctx.clip.open_clip_stack, ele_rect)
				} else {
					append(&ctx.clip.open_clip_stack, intersect_rect(back(ctx.clip.open_clip_stack), ele_rect))
				}
			}

			return
		}, on_up = proc(ctx: ^Context, idx: i32) -> (stop: bool) {
			ele := ctx.elements[idx]

			layout, ok := ele.attributes.(Layout_Attributes)
			if !ok do return

			defer if layout.config.clip && !is_floating_element(ctx, idx) {
				pop(&ctx.clip.open_clip_stack)
			}

			if layout.config.pointer_mode == .Ignore do return
			if !ctx.input.pointer.is_valid do return

			clipped_rect: Rect = {ele.position.x, ele.position.y, ele.size.x, ele.size.y}

			if !ctx.input_event.pointer_captured {
				if len(ctx.clip.open_clip_stack) > 0 {
					clipped_rect = intersect_rect(clipped_rect, back(ctx.clip.open_clip_stack))
				}

				if rect_contains(ctx.input.pointer.position, clipped_rect) {
					switch ctx.input.pointer.state {
					case .Pressed:
						if !ctx.input_event.pressed_once {
							clear(&ctx.input_event.pressed_elements)
							clear(&ctx.input_event.held_elements)
							ctx.input_event.pressed_once = true
						}
						append(&ctx.input_event.pressed_elements, ele.id)
						append(&ctx.input_event.held_elements, ele.id)
					case .Released:
						append(&ctx.input_event.released_elements, ele.id)
						if is_id_held(ele.id) {
							append(&ctx.input_event.clicked_elements, ele.id)
						}
					case .None, .Down:
					}

					append(&ctx.input_event.hovered_elements, ele.id)

					if layout.config.pointer_mode == .Capture {
						ctx.input_event.pointer_captured = true
					}
				}
			}

			if !ctx.input_event.scroll_captured && layout.config.scroll {
				ele_rect := ele_get_rect(ele)

				clipped_rect := ele_rect

				if len(ctx.clip.open_clip_stack) > 0 {
					clipped_rect = intersect_rect(back(ctx.clip.open_clip_stack), ele_rect)
				}

				if rect_contains(ctx.input.pointer.position, clipped_rect) {
					content_size: [2]f32 = {layout_get_content_size(ctx, idx, layout, .X), layout_get_content_size(ctx, idx, layout, .Y)}
					min_offset: [2]f32 = {-(content_size.x - (ele.size.x - layout_get_pad(layout, .X))), -(content_size.y - (ele.size.y - layout_get_pad(layout, .Y)))}

					cur_scroll := ctx.input_event.scrolls[ele.id]
					pending_offset, is_pending := cur_scroll.pending_offset.?
					next_scroll_offset := is_pending ? pending_offset : cur_scroll.offset + ctx.input.pointer.scroll * 20.0

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

			stop = detect_pointer_should_stop(ctx.input_event)

			return
		})
}

travel_tree_reverse :: proc(
	ctx: ^Context,
	index: Index = 0,
	on_up: proc(ctx: ^Context, index: Index) -> bool = nil,
	on_down: proc(ctx: ^Context, index: Index) -> bool = nil,
) -> bool {
	if on_down != nil && on_down(ctx, index) do return true
	it := child_iter_reverse_start(ctx, index)
	for child, child_index in child_iter_reverse_next(&it) {
		if travel_tree_reverse(ctx, child_index, on_up, on_down) {
			return true
		}
	}
	if on_up != nil && on_up(ctx, index) do return true
	return false
}

root_layout :: proc(screen_size: [2]f32) -> Element {
	return Element {
		id = 0,
		position = {0, 0},
		size = {screen_size.x, screen_size.y},
		limits = {},
		attributes = Layout_Attributes {
			config = Layout_Config {
				child_gap = 2,
				width = Fixed_Size{screen_size.x},
				height = Fixed_Size{screen_size.y},
				layout_direction = .Top_To_Bottom,
				padding = pad_all(2),
				background_color = {},
			},
		},
	}
}

child_iter_start :: proc(
	ctx: ^Context,
	start_index: Index,
	exclude_floats := true,
) -> Child_Iter {
	start := ctx.elements[start_index]

	next_index: Maybe(Index) = start.link.last != nil ? start_index + 1 : nil

	// Forwards until we find non float
	for next_index != nil && is_floating_element(ctx, next_index.?) {
		next_index = ctx.elements[next_index.?].link.next
	}

	return {ctx = ctx, next = next_index}
}

child_iter_next :: proc(
	it: ^Child_Iter,
) -> (
	child: ^Element,
	child_index: Index,
	cond: bool,
) {
	if it.next == nil {
		return
	}

	child_index = it.next.?
	child = &it.ctx.elements[child_index]
	cond = true

	it.next = child.link.next

	for it.next != nil && is_floating_element(it.ctx, it.next.?) {
		it.next = it.ctx.elements[it.next.?].link.next
	}

	return
}

child_iter_reverse_start :: proc(
	ctx: ^Context,
	start_index: Index,
) -> Child_Iter {
	start := ctx.elements[start_index]
	next_index := start.link.last

	// Backwards until we find non float
	for next_index != nil && is_floating_element(ctx, next_index.?) {
		next_index = ctx.elements[next_index.?].link.prev
	}

	return {ctx = ctx, next = next_index}
}

child_iter_reverse_next :: proc(
	it: ^Child_Iter,
) -> (
	child: ^Element,
	child_index: Index,
	cond: bool,
) {
	if it.next == nil {
		return
	}

	child_index = it.next.?
	child = &it.ctx.elements[child_index]
	cond = true

	it.next = child.link.prev

	for it.next != nil && is_floating_element(it.ctx, it.next.?) {
		it.next = it.ctx.elements[it.next.?].link.prev
	}

	return
}

get_float_target :: proc(
	ctx: Context,
	index: Index,
	float_mode: Float_Mode,
) -> (
	target_index: Index,
	config: Float_Config,
) {
	ele := ctx.elements[index]
	switch mode in float_mode {
	case Float_At_Parent:
		{
			parent_idx := ele.link.parent
			target_index = parent_idx
			config = mode
		}
	case Float_At_Id:
		{
			id_entry, existed := ctx.ids[mode.attach_id]
			assert(existed)
			target_index = id_entry.index
			config = mode
		}
	case Float_At_Root:
		{
			target_index = 0
			config = mode
		}
	case Float_None:
		panic("Element doesn't float")
	}
	return
}

is_grow_layout_or_text :: proc(ele: Element, axis: Axis) -> bool {
	switch attr in ele.attributes {
	case Text_Attributes, Text_Edit_Attributes:
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
layout_get_content_size :: proc(
	ctx: ^Context,
	index: Index,
	layout: Layout_Attributes,
	axis: Axis,
) -> f32 {
	content_size: f32 = 0
	if layout_is_along(layout, axis) {
		child_count: i32 = 0
		for it := child_iter_start(ctx, index); child in child_iter_next(&it) {
			content_size += ele_get_size(child, axis)
			child_count += 1
		}
		content_size +=
			child_count > 0 ? f32(child_count - 1) * layout.config.child_gap : 0
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
layout_get_pad_at :: proc(
	layout: Layout_Attributes,
	axis: Axis,
	end: Normalized_End,
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
	layout: Layout_Attributes,
	axis: Axis,
) -> Size_Mode {
	return axis == .X ? layout.config.width : layout.config.height
}

@(private = "file")
layout_get_mode_from_ele :: proc(element: Element, axis: Axis) -> Size_Mode {
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
ele_set_size :: proc(element: ^Element, value: f32, axis: Axis) {
	if axis == .X do element.size.x = value
	else do element.size.y = value
}

@(private = "file")
ele_set_min :: proc(element: ^Element, value: f32, axis: Axis) {
	if axis == .X do element.limits.x.min = value
	else do element.limits.y.min = value
}

@(private = "file")
ele_set_max :: proc(element: ^Element, value: f32, axis: Axis) {
	if axis == .X do element.limits.x.max = value
	else do element.limits.y.max = value
}

@(private = "file")
ele_get_size :: proc(element: ^Element, axis: Axis) -> f32 {
	return axis == .X ? element.size.x : element.size.y
}

@(private = "file")
ele_get_min :: proc(element: ^Element, axis: Axis) -> f32 {
	return(
		axis == .X ? element.limits.x.min.? or_else 0 : element.limits.y.min.? or_else 0 \
	)
}

@(private = "file")
ele_get_max :: proc(element: ^Element, axis: Axis) -> Maybe(f32) {
	return axis == .X ? element.limits.x.max : element.limits.y.max
}

@(private = "file")
ele_get_lims :: proc(element: ^Element, axis: Axis) -> Axis_Limits {
	return axis == .X ? element.limits.x : element.limits.y
}

@(private = "file")
ele_set_pos :: proc(element: ^Element, value: f32, axis: Axis) {
	if axis == .X do element.position.x = value
	else do element.position.y = value
}

@(private = "file")
ele_get_pos :: proc(element: ^Element, axis: Axis) -> f32 {
	if axis == .X do return element.position.x
	else do return element.position.y
}

@(private = "file")
ele_get_rect :: #force_inline proc(element: Element) -> Rect {
	return {
		x = element.position.x,
		y = element.position.y,
		width = element.size.x,
		height = element.size.y,
	}
}

@(private = "file")
text_get_preferred :: proc(text_attr: Text_Attributes, axis: Axis) -> f32 {
	return axis == .X ? text_attr.preferred_size.x : text_attr.preferred_size.y
}

@(private = "file")
text_get_bound_size :: proc(text_attr: Text_Attributes, axis: Axis) -> f32 {
	return axis == .X ? text_attr.bound_size.x : text_attr.bound_size.y
}

@(private = "file")
align_get_offset :: proc(alignment: [2]f32, axis: Axis) -> f32 {
	return axis == .X ? alignment.x : alignment.y
}

sort_floats_by_zindex :: proc(ctx: ^Context, indices: []Index) {
	// ascending sort
	if len(indices) <= 1 do return
	// simple insertion sort
	for i in 1 ..< len(indices) {
		j := i
		for j > 0 {
			a := &ctx.elements[indices[j]]
			b := &ctx.elements[indices[j - 1]]
			a_float := a.attributes.(Layout_Attributes).config.float_mode
			b_float := b.attributes.(Layout_Attributes).config.float_mode
			a_z := get_float_z_index(a_float)
			b_z := get_float_z_index(b_float)
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

get_float_z_index :: proc(float: Float_Mode) -> i32 {
	switch float_type in float {
	case Float_None:
		panic("Element doesn't float")
	case Float_At_Parent:
		return float_type.z_index
	case Float_At_Id:
		return float_type.z_index
	case Float_At_Root:
		return float_type.z_index
	}
	return 0
}

BORDER_DEFAULT: Border_Config : {thickness = 0, color = {0, 0, 0, 255}}

@(require_results)
draw_layout :: proc(
	width: Sizing_Axis = {mode = Fit_Size{}},
	height: Sizing_Axis = {mode = Fit_Size{}},
	padding: Padding = {2, 2, 2, 2},
	child_gap: f32 = 2,
	layout_direction: Layout_Direction = .Left_To_Right,
	child_alignment: Alignment = {x = .Left, y = .Top},
	background_color: [4]u8 = {},
	background_gradient: Maybe(Gradient) = nil,
	background_image: Maybe(Image) = nil,
	corner_radius: Corner_Radius = {4, 4, 4, 4},
	border: Border_Config = BORDER_DEFAULT,
	outline: Outline_Config = {},
	pointer_mode: Pointer_Mode = .Capture,
	clip: bool = false,
	scroll: bool = false,
	ignore_scroll: bool = false,
	float_mode: Float_Mode = Float_None{},
	offset: [2]f32 = {},
) -> bool {
	return open_layout(
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
			background_gradient = background_gradient,
			background_image = background_image,
			corner_radius = corner_radius,
			pointer_mode = pointer_mode,
			border = border,
			outline = outline,
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

draw_text :: proc(
	content: string,
	font_index: Font_Index = 0,
	font_size: f32 = 16,
	color: [4]u8 = {0, 0, 0, 255},
	line_spacing: f32 = 8,
	alignment: Alignment = {x = .Left, y = .Top},
	loc := #caller_location,
) -> bool {
	open_text(
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

draw_text_edit :: proc(
	content: string,
	font_index: Font_Index = 0,
	font_size: f32 = 16,
	color: [4]u8 = {0, 0, 0, 255},
	line_spacing: f32 = 8,
	alignment: Alignment = {x = .Left, y = .Top},
	selection_range: [2]int = {0, 0},
	selection_color: [4]u8 = {0, 0, 0, 0},
	cursor_index: int = -1,
	cursor_visible: bool = false,
	cursor_color: [4]u8 = {0, 0, 0, 0},
	scroll_offset: [2]f32 = {0, 0},
	multiline: bool = false,
	wrap: bool = false,
	loc := #caller_location,
) -> bool {
	open_text_edit(
		g_ui_builder.current_context,
		g_ui_builder.last_id,
		{
			content = content,
			font_index = font_index,
			font_size = font_size,
			color = color,
			line_spacing = line_spacing,
			alignment = get_alignment_offset(alignment),
			selection_range = selection_range,
			selection_color = selection_color,
			cursor_index = cursor_index,
			cursor_visible = cursor_visible,
			cursor_color = cursor_color,
			scroll_offset = scroll_offset,
			multiline = multiline,
			wrap = wrap,
		},
	)
	return true
}

grow :: #force_inline proc(
	min: Maybe(f32) = nil,
	max: Maybe(f32) = nil,
) -> Sizing_Axis {
	return {mode = Grow_Size{}, min = min, max = max}
}

fixed :: #force_inline proc(
	value: f32 = 0,
	min: Maybe(f32) = nil,
	max: Maybe(f32) = nil,
) -> Sizing_Axis {
	return {mode = Fixed_Size{value = value}, min = min, max = max}
}

fit :: #force_inline proc(
	min: Maybe(f32) = nil,
	max: Maybe(f32) = nil,
) -> Sizing_Axis {
	return {mode = Fit_Size{}, min = min, max = max}
}

percent :: #force_inline proc(
	value: f32,
	min: Maybe(f32) = nil,
	max: Maybe(f32) = nil,
) -> Sizing_Axis {
	return {mode = Percent_Size{value = value}, min = min, max = max}
}

pad_all :: #force_inline proc(value: f32) -> Padding {
	return Padding{value, value, value, value}
}

corner_radius_all :: #force_inline proc(value: f32) -> Corner_Radius {
	return Corner_Radius{value, value, value, value}
}


pointer_state_on_this :: proc() -> Element_Pointer_State {
	return get_layout_pointer_state_by_id(
		g_ui_builder.current_context^,
		g_ui_builder.last_id,
	)
}

pointer_state_on_id :: proc(id: Id) -> Element_Pointer_State {
	return get_layout_pointer_state_by_id(g_ui_builder.current_context^, id)
}

pointer_state :: proc() -> Pointer_State {
	return g_ui_builder.current_context.input.pointer.state
}

pointer_delta :: proc() -> [2]f32 {
	return g_ui_builder.current_context.input.pointer.delta
}

pointer_position :: proc() -> [2]f32 {
	return g_ui_builder.current_context.input.pointer.position
}

pointer_is_valid :: proc() -> bool {
	return g_ui_builder.current_context.input.pointer.is_valid
}

pointer_kind :: proc() -> Pointer_Kind {
	return g_ui_builder.current_context.input.pointer.kind
}

input_end_frame :: proc(input: ^Input) {
	#partial switch input.pointer.state {
	case .Pressed:
		input.pointer.state = .Down
	case .Released:
		input.pointer.state = .None
		if input.pointer.kind == .Touch {
			input.pointer.is_valid = false
		}
	}

	input.pointer.delta = {0, 0}
	input.pointer.scroll = {0, 0}

	for &state in input.keyboard.keys {
		#partial switch state {
		case .Pressed:
			state = .Down
		case .Released:
			state = .None
		}
	}

	clear(&input.keyboard.characters)
}

rect_by_id :: proc(id: Id) -> (Rect, bool) #optional_ok {
	rect, ok := g_ui_builder.current_context.bounds[id]
	return rect, ok
}

is_id_pressed :: proc(id: Id) -> bool {
	for ele_id in g_ui_builder.current_context.input_event.pressed_elements {
		if ele_id == id do return true
	}
	return false
}

is_this_pressed :: proc() -> bool {
	return is_id_pressed(g_ui_builder.last_id)
}

is_pressed :: is_this_pressed

is_id_held :: proc(id: Id) -> bool {
	for ele_id in g_ui_builder.current_context.input_event.held_elements {
		if ele_id == id do return true
	}
	return false
}

is_this_held :: proc() -> bool {
	return is_id_held(g_ui_builder.last_id)
}

is_held :: is_this_held

was_id_held :: proc(id: Id) -> bool {
	for ele_id in g_ui_builder.current_context.input_event.unheld_elements {
		if ele_id == id do return true
	}
	return false
}

was_this_held :: proc() -> bool {
	return was_id_held(g_ui_builder.last_id)
}

was_held :: was_this_held

is_id_released :: proc(id: Id) -> bool {
	for ele_id in g_ui_builder.current_context.input_event.released_elements {
		if ele_id == id do return true
	}
	return false
}

is_this_released :: proc() -> bool {
	return is_id_released(g_ui_builder.last_id)
}

is_released :: is_this_released

is_id_hovered :: proc(id: Id) -> bool {
	for ele_id in g_ui_builder.current_context.input_event.hovered_elements {
		if ele_id == id do return true
	}
	return false
}

is_this_hovered :: proc() -> bool {
	return is_id_hovered(g_ui_builder.last_id)
}

is_hovered :: is_this_hovered

is_id_pressed_away :: proc(id: Id) -> bool {
	if len(g_ui_builder.current_context.input_event.pressed_elements) == 0 {
		return false
	}
	return !is_id_hovered(id)
}

is_this_pressed_away :: proc() -> bool {
	return is_id_pressed_away(g_ui_builder.last_id)
}

is_pressed_away :: proc(ids: ..Id) -> bool {
	if len(g_ui_builder.current_context.input_event.pressed_elements) == 0 {
		return false
	}
	for id in ids {
		if is_id_hovered(id) do return false
	}
	return true
}

is_id_clicked :: proc(id: Id) -> bool {
	for ele_id in g_ui_builder.current_context.input_event.clicked_elements {
		if ele_id == id do return true
	}
	return false
}

is_this_clicked :: proc() -> bool {
	return is_id_clicked(g_ui_builder.last_id)
}

is_clicked :: is_this_clicked

register_focusable :: proc(id: Id) {
	for f_id in g_ui_builder.current_context.input_event.focusables {
		if f_id == id do return
	}
	append(&g_ui_builder.current_context.input_event.focusables, id)
}

register_this_focusable :: proc() {
	register_focusable(g_ui_builder.last_id)
}

is_id_focused :: proc(id: Id) -> bool {
	return g_ui_builder.current_context.input_event.focused_id == id
}

is_this_focused :: proc() -> bool {
	return is_id_focused(g_ui_builder.last_id)
}

is_focused :: is_this_focused

set_focused_id :: proc(id: Id) {
	g_ui_builder.current_context.input_event.focused_id = id
}

clear_focus :: proc() {
	g_ui_builder.current_context.input_event.focused_id = 0
}

focus_next :: proc() {
	focus_next_in_ctx(g_ui_builder.current_context)
}

focus_previous :: proc() {
	focus_previous_in_ctx(g_ui_builder.current_context)
}

key_state :: proc(k: Key) -> Key_State {
	return g_ui_builder.current_context.input.keyboard.keys[k]
}

is_key_pressed :: proc(k: Key) -> bool {
	return g_ui_builder.current_context.input.keyboard.keys[k] == .Pressed
}

is_key_down :: proc(k: Key) -> bool {
	return(
		g_ui_builder.current_context.input.keyboard.keys[k] == .Down ||
		g_ui_builder.current_context.input.keyboard.keys[k] == .Pressed \
	)
}

is_key_released :: proc(k: Key) -> bool {
	return g_ui_builder.current_context.input.keyboard.keys[k] == .Released
}

has_modifier :: proc(mod: Keyboard_Modifier) -> bool {
	return mod in g_ui_builder.current_context.input.keyboard.modifiers
}

get_input_characters :: proc() -> []rune {
	return g_ui_builder.current_context.input.keyboard.characters[:]
}

measure_text :: proc(
	content: string,
	font_size: f32 = 16,
	font_index: Font_Index = 0,
) -> f32 {
	assert(g_ui_builder.current_context != nil)
	assert(int(font_index) < len(g_ui_builder.current_context.fonts))
	return measure_text_width(
		{content = content, font_size = font_size, font_index = font_index},
		g_ui_builder.current_context.fonts[font_index],
	)
}

get_char_index_at_x :: proc(
	content: string,
	target_x: f32,
	font_size: f32 = 16,
	font_index: Font_Index = 0,
) -> int {
	assert(g_ui_builder.current_context != nil)
	assert(int(font_index) < len(g_ui_builder.current_context.fonts))
	font_info := g_ui_builder.current_context.fonts[font_index]
	scale := font_info.base_size > 0 ? (font_size / font_info.base_size) : 1.0
	cur_x: f32 = 0
	for i in 0 ..< len(content) {
		ch := content[i]
		adv: f32 = 0
		if ch >= 32 && ch < 128 {
			adv =
				font_info.glyphs[ch - 32].xadvance * scale +
				font_info.spacing * scale
		}
		if target_x < cur_x + adv * 0.5 {
			return i
		}
		cur_x += adv
	}
	return len(content)
}

set_clipboard :: proc(text: string) {
	ctx := g_ui_builder.current_context
	assert(ctx != nil)
	assert(ctx.set_clipboard != nil)
	ctx.set_clipboard(text, ctx.clipboard_user_data)
}

get_clipboard :: proc() -> string {
	ctx := g_ui_builder.current_context
	assert(ctx != nil)
	assert(ctx.get_clipboard != nil)
	return ctx.get_clipboard(ctx.clipboard_user_data)
}

capture_keyboard :: proc() {
	assert(g_ui_builder.current_context != nil)
	g_ui_builder.current_context.input_event.keyboard_captured = true
}

is_keyboard_captured :: proc() -> bool {
	assert(g_ui_builder.current_context != nil)
	return g_ui_builder.current_context.input_event.keyboard_captured
}

current_scroll_data :: proc() -> Scroll_Data {
	return get_layout_scroll_data(g_ui_builder.current_context^)
}

set_scroll_offset :: proc(scroll: [2]f32) {
	set_layout_scroll_offset(g_ui_builder.current_context, scroll)
}

// Internal ultilities
@(private = "file")
set_layout_scroll_offset :: proc(ctx: ^Context, new_scroll: [2]f32) {
	open_ele := ctx.open_layout_stack[len(ctx.open_layout_stack) - 1]
	scroll := ctx.input_event.scrolls[ctx.elements[open_ele].id]
	scroll.pending_offset = new_scroll

	ctx.input_event.scrolls[ctx.elements[open_ele].id] = scroll
}

@(private = "file")
get_layout_scroll_data :: proc(ctx: Context) -> Scroll_Data {
	open_ele := ctx.open_layout_stack[len(ctx.open_layout_stack) - 1]
	return ctx.input_event.scrolls[ctx.elements[open_ele].id]
}


@(private = "file")
get_layout_pointer_state_by_id :: proc(
	ctx: Context,
	id: Id,
) -> Element_Pointer_State {
	for ele_id in ctx.input_event.hovered_elements {
		if ele_id == id {
			switch ctx.input.pointer.state {
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
get_alignment_offset :: proc(alignment: Alignment) -> [2]f32 {
	offset: [2]f32
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

@(require_results)
intersect_rect :: proc(a, b: Rect) -> (Rect, bool) #optional_ok {
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
rect_contains :: proc(p: [2]f32, rec: Rect) -> bool {
	return(
		p.x >= rec.x &&
		p.x <= rec.x + rec.width &&
		p.y >= rec.y &&
		p.y <= rec.y + rec.height \
	)
}


auto_id_hash :: proc(
	parent_hash: Id,
	loc: runtime.Source_Code_Location,
) -> Id {
	line := transmute([4]u8)loc.line
	column := transmute([4]u8)loc.column
	path := loc.file_path
	if g_ui_builder.current_context != nil {
		entry_dir := g_ui_builder.current_context.entry_dir
		if len(entry_dir) > 0 &&
		   len(path) >= len(entry_dir) &&
		   path[:len(entry_dir)] == entry_dir {
			path = path[len(entry_dir):]
		}
	}
	h: u64 = parent_hash
	h = hash.fnv64a(transmute([]u8)path, h)
	h = hash.fnv64a(line[:], h)
	h = hash.fnv64a(column[:], h)
	return h
}

@(require_results)
global_id :: proc(id: string) -> Id {
	return hash.fnv64a(transmute([]u8)id)
}

@(require_results)
local_id :: proc(id: string) -> Id {
	parent_hash :=
		g_ui_builder.current_context.elements[back(g_ui_builder.current_context.open_layout_stack)].id
	return hash.fnv64a(transmute([]u8)id, parent_hash)
}

@(require_results)
family_id :: proc(id: string, owner: string) -> Id {
	parent_hash :=
		g_ui_builder.current_context.elements[back(g_ui_builder.current_context.open_layout_stack)].id
	return hash.fnv64a(transmute([]u8)id, parent_hash)
}

declare_id :: proc(id: Maybe(Id), loc: runtime.Source_Code_Location) {
	index := i32(len(g_ui_builder.current_context.elements))

	new_id: Id
	if id == nil {
		parent_hash :=
			g_ui_builder.current_context.elements[back(g_ui_builder.current_context.open_layout_stack)].id
		new_id = auto_id_hash(parent_hash, loc)
		new_id = push_and_dedupe_id(
			g_ui_builder.current_context,
			index,
			new_id,
		)

	} else {
		new_id = id.?
		push_id(g_ui_builder.current_context, index, new_id)
	}

	g_ui_builder.last_id = new_id
}

Element_Draw :: struct($T: typeid) {
	draw: T,
}

@(deferred_none = end_layout)
layout :: proc(
	id: Maybe(Id) = nil,
	loc := #caller_location,
	reuse_id: bool = false,
) -> Element_Draw(type_of(draw_layout)) {
	return begin_layout(id, loc, reuse_id)
}

begin_layout :: proc(
	id: Maybe(Id) = nil,
	loc := #caller_location,
	reuse_id: bool = false,
) -> Element_Draw(type_of(draw_layout)) {
	if !reuse_id {
		declare_id(id, loc)
	}
	return {draw_layout}
}

end_layout :: proc() {
	close_layout(g_ui_builder.current_context)
}

@(deferred_none = end_layout)
defer_end_layout :: proc() -> bool {
	return true
}

text :: proc(
	id: Maybe(Id) = nil,
	loc := #caller_location,
) -> Element_Draw(type_of(draw_text)) {
	declare_id(id, loc)
	return {draw_text}
}

text_edit :: proc(
	id: Maybe(Id) = nil,
	loc := #caller_location,
) -> Element_Draw(type_of(draw_text_edit)) {
	declare_id(id, loc)
	return {draw_text_edit}
}


last_id :: proc() -> Id {
	return g_ui_builder.last_id
}

get_builder :: proc "contextless" () -> ^Builder {
	return &g_ui_builder
}
