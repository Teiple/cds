package ui_sokol

import sg "../sokol/gfx"
import "../ui"
import "core:math"
import "core:math/linalg"
import stbtt "vendor:stb/truetype"

ARC_SEGMENTS :: 12

UI_Vertex :: struct {
	pos:   [2]f32,
	uv:    [2]f32,
	color: [4]u8,
}

Draw_Batch :: struct {
	view:         sg.View,
	scissor:      ui.Rect,
	element_base: i32,
	num_elements: i32,
}

UI_Renderer :: struct {
	pipeline:       sg.Pipeline,
	vertex_buffer:  sg.Buffer,
	index_buffer:   sg.Buffer,
	sampler:        sg.Sampler,
	white_image:    sg.Image,
	white_view:     sg.View,
	font_image:     sg.Image,
	font_view:      sg.View,
	font_chardata:  [96]stbtt.bakedchar,
	font_base_size: f32,
	font_spacing:   f32,
	vertices:       [dynamic]UI_Vertex,
	indices:        [dynamic]u16,
	batches:        [dynamic]Draw_Batch,
	scissor_stack:  [dynamic]ui.Rect,
}

ui_renderer_init :: proc(
	r: ^UI_Renderer,
	font_ttf: []byte,
	font_size: f32 = 20.0,
	max_vertices := 16384,
	max_indices := 32768,
) {
	r.vertices = make([dynamic]UI_Vertex, 0, max_vertices)
	r.indices = make([dynamic]u16, 0, max_indices)
	r.batches = make([dynamic]Draw_Batch, 0, 64)
	r.scissor_stack = make([dynamic]ui.Rect, 0, 16)

	r.vertex_buffer = sg.make_buffer({
		usage = {vertex_buffer = true, dynamic_update = true},
		size = uint(max_vertices * size_of(UI_Vertex)),
	})

	r.index_buffer = sg.make_buffer({
		usage = {index_buffer = true, dynamic_update = true},
		size = uint(max_indices * size_of(u16)),
	})

	pip_desc: sg.Pipeline_Desc = {
		shader = sg.make_shader(ui_shader_desc(sg.query_backend())),
		index_type = .UINT16,
		cull_mode = .NONE,
		depth = {compare = .ALWAYS, write_enabled = false},
	}
	pip_desc.layout.attrs[ATTR_ui_pos] = {
		format = .FLOAT2,
		offset = i32(offset_of(UI_Vertex, pos)),
	}
	pip_desc.layout.attrs[ATTR_ui_uv0] = {
		format = .FLOAT2,
		offset = i32(offset_of(UI_Vertex, uv)),
	}
	pip_desc.layout.attrs[ATTR_ui_color0] = {
		format = .UBYTE4N,
		offset = i32(offset_of(UI_Vertex, color)),
	}
	pip_desc.colors[0].blend = {
		enabled          = true,
		src_factor_rgb   = .SRC_ALPHA,
		dst_factor_rgb   = .ONE_MINUS_SRC_ALPHA,
		src_factor_alpha = .ONE,
		dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
	}
	r.pipeline = sg.make_pipeline(pip_desc)

	r.sampler = sg.make_sampler({
		min_filter = .LINEAR,
		mag_filter = .LINEAR,
		wrap_u = .CLAMP_TO_EDGE,
		wrap_v = .CLAMP_TO_EDGE,
	})

	white_pixel: [4]u8 = {255, 255, 255, 255}
	r.white_image = sg.make_image({
		width = 1,
		height = 1,
		pixel_format = .RGBA8,
		data = {
			mip_levels = {
				0 = {ptr = raw_data(white_pixel[:]), size = len(white_pixel)},
			},
		},
	})
	r.white_view = sg.make_view({texture = {image = r.white_image}})

	atlas_w, atlas_h := 512, 512
	alpha_bitmap := make([]u8, atlas_w * atlas_h)
	defer delete(alpha_bitmap)

	stbtt.BakeFontBitmap(
		raw_data(font_ttf),
		0,
		font_size,
		raw_data(alpha_bitmap),
		i32(atlas_w),
		i32(atlas_h),
		32,
		96,
		raw_data(r.font_chardata[:]),
	)

	rgba_pixels := make([]u8, atlas_w * atlas_h * 4)
	defer delete(rgba_pixels)

	for i in 0 ..< (atlas_w * atlas_h) {
		a := alpha_bitmap[i]
		rgba_pixels[i * 4 + 0] = 255
		rgba_pixels[i * 4 + 1] = 255
		rgba_pixels[i * 4 + 2] = 255
		rgba_pixels[i * 4 + 3] = a
	}

	r.font_image = sg.make_image({
		width = i32(atlas_w),
		height = i32(atlas_h),
		pixel_format = .RGBA8,
		data = {
			mip_levels = {
				0 = {ptr = raw_data(rgba_pixels), size = len(rgba_pixels)},
			},
		},
	})
	r.font_view = sg.make_view({texture = {image = r.font_image}})

	r.font_base_size = font_size
	r.font_spacing = 0.0
}

ui_renderer_font :: proc(
	r: ^UI_Renderer,
	id: ui.UI_Font_Id = 0,
) -> ui.UI_Font {
	f := ui.UI_Font {
		id        = id,
		base_size = r.font_base_size,
		spacing   = r.font_spacing,
	}
	for i in 0 ..< 96 {
		f.glyphs[i].xadvance = r.font_chardata[i].xadvance
	}
	return f
}

ui_renderer_destroy :: proc(r: ^UI_Renderer) {
	delete(r.vertices)
	delete(r.indices)
	delete(r.batches)
	delete(r.scissor_stack)

	sg.destroy_pipeline(r.pipeline)
	sg.destroy_buffer(r.vertex_buffer)
	sg.destroy_buffer(r.index_buffer)
	sg.destroy_sampler(r.sampler)

	sg.destroy_view(r.white_view)
	sg.destroy_image(r.white_image)

	sg.destroy_view(r.font_view)
	sg.destroy_image(r.font_image)
}

@(private = "file")
push_quad :: proc(
	r: ^UI_Renderer,
	p0, p1, p2, p3: [2]f32,
	uv0, uv1, uv2, uv3: [2]f32,
	color: [4]u8,
) {
	base_idx := u16(len(r.vertices))

	append(
		&r.vertices,
		UI_Vertex{pos = p0, uv = uv0, color = color},
		UI_Vertex{pos = p1, uv = uv1, color = color},
		UI_Vertex{pos = p2, uv = uv2, color = color},
		UI_Vertex{pos = p3, uv = uv3, color = color},
	)

	append(
		&r.indices,
		base_idx + 0,
		base_idx + 1,
		base_idx + 2,
		base_idx + 0,
		base_idx + 2,
		base_idx + 3,
	)

	if len(r.batches) > 0 {
		r.batches[len(r.batches) - 1].num_elements += 6
	}
}

@(private = "file")
draw_text_line :: proc(
	r: ^UI_Renderer,
	text: string,
	start_x, start_y: f32,
	scale_font: f32,
	spacing: f32,
	color: [4]u8,
) {
	pen_x := start_x
	for ch in text {
		if ch < 32 || ch >= 128 do continue
		bc := r.font_chardata[ch - 32]
		qw := f32(bc.x1 - bc.x0) * scale_font
		qh := f32(bc.y1 - bc.y0) * scale_font
		qx := pen_x + bc.xoff * scale_font
		qy := start_y + bc.yoff * scale_font

		uv0 := [2]f32{f32(bc.x0) / 512.0, f32(bc.y0) / 512.0}
		uv1 := [2]f32{f32(bc.x1) / 512.0, f32(bc.y0) / 512.0}
		uv2 := [2]f32{f32(bc.x1) / 512.0, f32(bc.y1) / 512.0}
		uv3 := [2]f32{f32(bc.x0) / 512.0, f32(bc.y1) / 512.0}

		push_quad(
			r,
			{qx, qy},
			{qx + qw, qy},
			{qx + qw, qy + qh},
			{qx, qy + qh},
			uv0,
			uv1,
			uv2,
			uv3,
			color,
		)
		pen_x += bc.xadvance * scale_font + spacing
	}
}

@(private = "file")
push_rect_solid :: proc(r: ^UI_Renderer, rect: ui.Rect, color: [4]u8) {
	if rect.width <= 0 || rect.height <= 0 {
		return
	}
	uv: [2]f32 = {0.5, 0.5}
	push_quad(
		r,
		{rect.x, rect.y},
		{rect.x + rect.width, rect.y},
		{rect.x + rect.width, rect.y + rect.height},
		{rect.x, rect.y + rect.height},
		uv,
		uv,
		uv,
		uv,
		color,
	)
}

@(private = "file")
push_circle_sector :: proc(
	r: ^UI_Renderer,
	center: [2]f32,
	radius: f32,
	start_angle_deg, end_angle_deg: f32,
	color: [4]u8,
) {
	if radius <= 0 {
		return
	}
	uv: [2]f32 = {0.5, 0.5}
	step := (end_angle_deg - start_angle_deg) / f32(ARC_SEGMENTS)
	center_idx := u16(len(r.vertices))
	append(&r.vertices, UI_Vertex{pos = center, uv = uv, color = color})

	for i in 0 ..= ARC_SEGMENTS {
		angle := math.to_radians_f32(start_angle_deg + f32(i) * step)
		pos :=
			center + [2]f32{math.cos(angle) * radius, math.sin(angle) * radius}
		append(&r.vertices, UI_Vertex{pos = pos, uv = uv, color = color})
	}

	for i in 0 ..< ARC_SEGMENTS {
		append(
			&r.indices,
			center_idx,
			center_idx + 1 + u16(i),
			center_idx + 2 + u16(i),
		)
		if len(r.batches) > 0 {
			r.batches[len(r.batches) - 1].num_elements += 3
		}
	}
}

@(private = "file")
push_ring_sector :: proc(
	r: ^UI_Renderer,
	center: [2]f32,
	inner_r, outer_r: f32,
	start_angle_deg, end_angle_deg: f32,
	color: [4]u8,
) {
	if outer_r <= 0 {
		return
	}
	uv: [2]f32 = {0.5, 0.5}
	step := (end_angle_deg - start_angle_deg) / f32(ARC_SEGMENTS)

	for i in 0 ..< ARC_SEGMENTS {
		a0 := math.to_radians_f32(start_angle_deg + f32(i) * step)
		a1 := math.to_radians_f32(start_angle_deg + f32(i + 1) * step)

		p0 := center + [2]f32{math.cos(a0) * outer_r, math.sin(a0) * outer_r}
		p1 := center + [2]f32{math.cos(a1) * outer_r, math.sin(a1) * outer_r}
		p2 := center + [2]f32{math.cos(a1) * inner_r, math.sin(a1) * inner_r}
		p3 := center + [2]f32{math.cos(a0) * inner_r, math.sin(a0) * inner_r}

		push_quad(r, p0, p1, p2, p3, uv, uv, uv, uv, color)
	}
}

@(private = "file")
render_rounded_rect_filled :: proc(
	r: ^UI_Renderer,
	rect: ui.Rect,
	color: [4]u8,
	rad: ui.UI_Corner_Radius,
) {
	w, h := rect.width, rect.height
	r_tl := clamp(rad.top_left, 0, min(w / 2, h / 2))
	r_tr := clamp(rad.top_right, 0, min(w / 2, h / 2))
	r_br := clamp(rad.bottom_right, 0, min(w / 2, h / 2))
	r_bl := clamp(rad.bottom_left, 0, min(w / 2, h / 2))

	if max(r_tl, r_tr, r_br, r_bl) == 0 {
		push_rect_solid(r, rect, color)
		return
	}

	top_h := max(r_tl, r_tr)
	bot_h := max(r_bl, r_br)
	mid_h := h - top_h - bot_h

	if mid_h > 0 {
		push_rect_solid(r, {rect.x, rect.y + top_h, w, mid_h}, color)
	}

	top_w := w - r_tl - r_tr
	if top_h > 0 && top_w > 0 {
		push_rect_solid(r, {rect.x + r_tl, rect.y, top_w, top_h}, color)
	}

	bot_w := w - r_bl - r_br
	if bot_h > 0 && bot_w > 0 {
		push_rect_solid(
			r,
			{rect.x + r_bl, rect.y + h - bot_h, bot_w, bot_h},
			color,
		)
	}

	if r_tl > 0 do push_circle_sector(r, {rect.x + r_tl, rect.y + r_tl}, r_tl, 180, 270, color)
	if r_tr > 0 do push_circle_sector(r, {rect.x + w - r_tr, rect.y + r_tr}, r_tr, 270, 360, color)
	if r_br > 0 do push_circle_sector(r, {rect.x + w - r_br, rect.y + h - r_br}, r_br, 0, 90, color)
	if r_bl > 0 do push_circle_sector(r, {rect.x + r_bl, rect.y + h - r_bl}, r_bl, 90, 180, color)
}

@(private = "file")
render_rounded_rect_border :: proc(
	r: ^UI_Renderer,
	rect: ui.Rect,
	color: [4]u8,
	rad: ui.UI_Corner_Radius,
	thickness: f32,
) {
	if thickness <= 0 do return
	w, h := rect.width, rect.height
	r_tl := clamp(rad.top_left, 0, min(w / 2, h / 2))
	r_tr := clamp(rad.top_right, 0, min(w / 2, h / 2))
	r_br := clamp(rad.bottom_right, 0, min(w / 2, h / 2))
	r_bl := clamp(rad.bottom_left, 0, min(w / 2, h / 2))

	if max(r_tl, r_tr, r_br, r_bl) == 0 {
		push_rect_solid(r, {rect.x, rect.y, w, thickness}, color)
		push_rect_solid(
			r,
			{rect.x, rect.y + h - thickness, w, thickness},
			color,
		)
		push_rect_solid(
			r,
			{rect.x, rect.y + thickness, thickness, h - 2 * thickness},
			color,
		)
		push_rect_solid(
			r,
			{
				rect.x + w - thickness,
				rect.y + thickness,
				thickness,
				h - 2 * thickness,
			},
			color,
		)
		return
	}

	inner_tl := max(0, r_tl - thickness)
	inner_tr := max(0, r_tr - thickness)
	inner_br := max(0, r_br - thickness)
	inner_bl := max(0, r_bl - thickness)

	if r_tl > 0 do push_ring_sector(r, {rect.x + r_tl, rect.y + r_tl}, inner_tl, r_tl, 180, 270, color)
	if r_tr > 0 do push_ring_sector(r, {rect.x + w - r_tr, rect.y + r_tr}, inner_tr, r_tr, 270, 360, color)
	if r_br > 0 do push_ring_sector(r, {rect.x + w - r_br, rect.y + h - r_br}, inner_br, r_br, 0, 90, color)
	if r_bl > 0 do push_ring_sector(r, {rect.x + r_bl, rect.y + h - r_bl}, inner_bl, r_bl, 90, 180, color)

	push_rect_solid(
		r,
		{rect.x + r_tl, rect.y, w - r_tl - r_tr, thickness},
		color,
	)
	push_rect_solid(
		r,
		{rect.x + r_bl, rect.y + h - thickness, w - r_bl - r_br, thickness},
		color,
	)
	push_rect_solid(
		r,
		{rect.x, rect.y + r_tl, thickness, h - r_tl - r_bl},
		color,
	)
	push_rect_solid(
		r,
		{rect.x + w - thickness, rect.y + r_tr, thickness, h - r_tr - r_br},
		color,
	)
}

@(private = "file")
set_active_batch :: proc(r: ^UI_Renderer, view: sg.View, scissor: ui.Rect) {
	if len(r.batches) > 0 {
		last := &r.batches[len(r.batches) - 1]
		if last.view.id == view.id && last.scissor == scissor {
			return
		}
	}

	element_base := i32(len(r.indices))
	append(
		&r.batches,
		Draw_Batch{
			view = view,
			scissor = scissor,
			element_base = element_base,
			num_elements = 0,
		},
	)
}

ui_renderer_render :: proc(
	r: ^UI_Renderer,
	ctx: ^ui.UI_Context,
	base_size: [2]f32,
	dest_rect: ui.Rect,
	scale: f32,
) {
	clear(&r.vertices)
	clear(&r.indices)
	clear(&r.batches)
	clear(&r.scissor_stack)

	base_scissor := dest_rect
	append(&r.scissor_stack, base_scissor)

	set_active_batch(r, r.white_view, base_scissor)

	for cmd in ctx.render_commands {
		switch c in cmd {
		case ui.UI_Push_Clip_Command:
			cur := r.scissor_stack[len(r.scissor_stack) - 1]
			screen_clip := ui.Rect {
				x      = dest_rect.x + c.rect.x * scale,
				y      = dest_rect.y + c.rect.y * scale,
				width  = c.rect.width * scale,
				height = c.rect.height * scale,
			}
			intersected, ok := ui.ui_intersect_rect(cur, screen_clip)
			if !ok do intersected = ui.Rect{}
			append(&r.scissor_stack, intersected)
			set_active_batch(
				r,
				r.batches[len(r.batches) - 1].view,
				intersected,
			)

		case ui.UI_Pop_Clip_Command:
			if len(r.scissor_stack) > 1 {
				pop(&r.scissor_stack)
			}
			cur := r.scissor_stack[len(r.scissor_stack) - 1]
			set_active_batch(r, r.batches[len(r.batches) - 1].view, cur)

		case ui.UI_Rect_Command:
			cur := r.scissor_stack[len(r.scissor_stack) - 1]
			set_active_batch(r, r.white_view, cur)
			render_rounded_rect_filled(r, c.rect, c.color, c.corner_radius)
			if c.border.thickness > 0 {
				render_rounded_rect_border(
					r,
					c.rect,
					c.border.color,
					c.corner_radius,
					c.border.thickness,
				)
			}

		case ui.UI_Image_Command:
			cur := r.scissor_stack[len(r.scissor_stack) - 1]
			view := r.white_view
			if c.texture != 0 {
				view = sg.View {
					id = u32(c.texture),
				}
			}
			set_active_batch(r, view, cur)
			uv0 := [2]f32{0, 0}
			uv1 := [2]f32{1, 0}
			uv2 := [2]f32{1, 1}
			uv3 := [2]f32{0, 1}
			push_quad(
				r,
				{c.dest.x, c.dest.y},
				{c.dest.x + c.dest.width, c.dest.y},
				{c.dest.x + c.dest.width, c.dest.y + c.dest.height},
				{c.dest.x, c.dest.y + c.dest.height},
				uv0,
				uv1,
				uv2,
				uv3,
				c.tint,
			)

		case ui.UI_Text_Command:
			cur := r.scissor_stack[len(r.scissor_stack) - 1]
			set_active_batch(r, r.font_view, cur)
			scale_font := c.font_size / r.font_base_size
			pen_x := c.rect.x
			pen_y := c.rect.y + c.font_size * 0.78

			lines := c.wrapped_lines
			if len(lines) == 0 {
				draw_text_line(
					r,
					c.content,
					pen_x,
					pen_y,
					scale_font,
					c.spacing,
					c.color,
				)
			} else {
				line_y := pen_y
				for line in lines {
					draw_text_line(
						r,
						line,
						pen_x,
						line_y,
						scale_font,
						c.spacing,
						c.color,
					)
					line_y += c.font_size + c.line_spacing
				}
			}
		}
	}

	if len(r.indices) == 0 do return

	sg.update_buffer(
		r.vertex_buffer,
		{
			ptr = raw_data(r.vertices),
			size = len(r.vertices) * size_of(UI_Vertex),
		},
	)
	sg.update_buffer(
		r.index_buffer,
		{ptr = raw_data(r.indices), size = len(r.indices) * size_of(u16)},
	)

	sg.apply_pipeline(r.pipeline)

	ortho := linalg.matrix_ortho3d_f32(0, base_size.x, base_size.y, 0, -1, 1)
	vs_params := Vs_Params {
		ortho_proj = ortho,
	}
	sg.apply_uniforms(
		UB_vs_params,
		{ptr = &vs_params, size = size_of(vs_params)},
	)

	for b in r.batches {
		if b.num_elements <= 0 do continue

		bindings: sg.Bindings = {
			vertex_buffers = {0 = r.vertex_buffer},
			index_buffer = r.index_buffer,
			views = {VIEW_tex = b.view},
			samplers = {SMP_smp = r.sampler},
		}
		sg.apply_bindings(bindings)

		sg.apply_scissor_rectf(
			b.scissor.x,
			b.scissor.y,
			b.scissor.width,
			b.scissor.height,
			true,
		)
		sg.draw(b.element_base, b.num_elements, 1)
	}
}

init :: ui_renderer_init
destroy :: ui_renderer_destroy
font :: ui_renderer_font
render :: ui_renderer_render
Renderer :: UI_Renderer
Vertex :: UI_Vertex
