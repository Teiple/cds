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

UI_Sokol_Font :: struct {
	image:     sg.Image,
	view:      sg.View,
	chardata:  [96]stbtt.bakedchar,
	base_size: f32,
	spacing:   f32,
}

UI_Renderer :: struct {
	pipeline:      sg.Pipeline,
	vertex_buffer: sg.Buffer,
	index_buffer:  sg.Buffer,
	sampler:       sg.Sampler,
	white_image:   sg.Image,
	white_view:    sg.View,
	fonts:         [dynamic]UI_Sokol_Font,
	vertices:      [dynamic]UI_Vertex,
	indices:       [dynamic]u16,
	batches:       [dynamic]Draw_Batch,
	scissor_stack: [dynamic]ui.Rect,
}

ui_renderer_init :: proc(
	r: ^UI_Renderer,
	max_vertices := 16384,
	max_indices := 32768,
) {
	r.vertices = make([dynamic]UI_Vertex, 0, max_vertices)
	r.indices = make([dynamic]u16, 0, max_indices)
	r.batches = make([dynamic]Draw_Batch, 0, 64)
	r.scissor_stack = make([dynamic]ui.Rect, 0, 16)
	r.fonts = make([dynamic]UI_Sokol_Font, 0, 4)

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

	// ui shader always sample images, incase we don't need images,
	// we sample this white 1-pixel image
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
}

UI_Font_Desc :: struct {
	font_ttf:  []byte,
	font_size: f32,
	spacing:   f32,
}

ui_renderer_make_fonts :: proc(
	r: ^UI_Renderer,
	font_descs: []UI_Font_Desc,
	allocator := context.temp_allocator,
) -> []ui.UI_Font {
	// ui itself will be responsible for delete this
	out := make([]ui.UI_Font, len(font_descs))
	for desc, i in font_descs {
		atlas_w, atlas_h := 512, 512
		alpha_bitmap := make([]u8, atlas_w * atlas_h)
		defer delete(alpha_bitmap)

		chardata: [96]stbtt.bakedchar
		stbtt.BakeFontBitmap(
			raw_data(desc.font_ttf),
			0,
			desc.font_size,
			raw_data(alpha_bitmap),
			i32(atlas_w),
			i32(atlas_h),
			32,
			96,
			raw_data(chardata[:]),
		)

		rgba_pixels := make([]u8, atlas_w * atlas_h * 4)
		defer delete(rgba_pixels)

		for px, idx in alpha_bitmap {
			rgba_pixels[idx * 4 + 0] = 255
			rgba_pixels[idx * 4 + 1] = 255
			rgba_pixels[idx * 4 + 2] = 255
			rgba_pixels[idx * 4 + 3] = px
		}

		font_image := sg.make_image({
			width = i32(atlas_w),
			height = i32(atlas_h),
			pixel_format = .RGBA8,
			data = {
				mip_levels = {
					0 = {ptr = raw_data(rgba_pixels), size = len(rgba_pixels)},
				},
			},
		})
		font_view := sg.make_view({texture = {image = font_image}})

		append(
			&r.fonts,
			UI_Sokol_Font{
				image = font_image,
				view = font_view,
				chardata = chardata,
				base_size = desc.font_size,
				spacing = desc.spacing,
			},
		)

		out[i] = ui.UI_Font {
			base_size = desc.font_size,
			spacing   = desc.spacing,
		}
		for g in 0 ..< 96 {
			out[i].glyphs[g].xadvance = chardata[g].xadvance
		}
	}

	return out
}

ui_renderer_destroy :: proc(r: ^UI_Renderer) {
	delete(r.vertices)
	delete(r.indices)
	delete(r.batches)
	delete(r.scissor_stack)

	for f in r.fonts {
		sg.destroy_view(f.view)
		sg.destroy_image(f.image)
	}
	delete(r.fonts)

	sg.destroy_pipeline(r.pipeline)
	sg.destroy_buffer(r.vertex_buffer)
	sg.destroy_buffer(r.index_buffer)
	sg.destroy_sampler(r.sampler)

	sg.destroy_view(r.white_view)
	sg.destroy_image(r.white_image)
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
push_sub_quad :: proc(
	r: ^UI_Renderer,
	px0, py0, px1, py1: f32,
	uv_x0, uv_y0, uv_x1, uv_y1: f32,
	color: [4]u8,
) {
	if px1 <= px0 || py1 <= py0 do return
	p0 := [2]f32{px0, py0}
	p1 := [2]f32{px1, py0}
	p2 := [2]f32{px1, py1}
	p3 := [2]f32{px0, py1}
	u0 := [2]f32{uv_x0, uv_y0}
	u1 := [2]f32{uv_x1, uv_y0}
	u2 := [2]f32{uv_x1, uv_y1}
	u3 := [2]f32{uv_x0, uv_y1}
	push_quad(r, p0, p1, p2, p3, u0, u1, u2, u3, color)
}

@(private = "file")
render_image :: proc(r: ^UI_Renderer, c: ui.UI_Image_Command, view: sg.View) {
	img := sg.query_view_image(view)
	desc := sg.query_image_desc(img)
	tex_w := f32(desc.width > 0 ? desc.width : 1)
	tex_h := f32(desc.height > 0 ? desc.height : 1)

	if npatch, ok := c.npatch.?; ok {
		src := npatch.source
		if src.width <= 0 || src.height <= 0 {
			src =
				c.source.width > 0 && c.source.height > 0 ? c.source : ui.Rect{0, 0, tex_w, tex_h}
		}

		left := f32(npatch.left)
		top := f32(npatch.top)
		right := f32(npatch.right)
		bottom := f32(npatch.bottom)

		dx0 := c.dest.x
		dx1 := dx0 + left
		dx2 := dx0 + c.dest.width - right
		dx3 := dx0 + c.dest.width

		dy0 := c.dest.y
		dy1 := dy0 + top
		dy2 := dy0 + c.dest.height - bottom
		dy3 := dy0 + c.dest.height

		u0 := src.x / tex_w
		u1 := (src.x + left) / tex_w
		u2 := (src.x + src.width - right) / tex_w
		u3 := (src.x + src.width) / tex_w

		v0 := src.y / tex_h
		v1 := (src.y + top) / tex_h
		v2 := (src.y + src.height - bottom) / tex_h
		v3 := (src.y + src.height) / tex_h

		switch npatch.layout {
		case .NINE_PATCH:
			push_sub_quad(r, dx0, dy0, dx1, dy1, u0, v0, u1, v1, c.tint)
			push_sub_quad(r, dx1, dy0, dx2, dy1, u1, v0, u2, v1, c.tint)
			push_sub_quad(r, dx2, dy0, dx3, dy1, u2, v0, u3, v1, c.tint)

			push_sub_quad(r, dx0, dy1, dx1, dy2, u0, v1, u1, v2, c.tint)
			push_sub_quad(r, dx1, dy1, dx2, dy2, u1, v1, u2, v2, c.tint)
			push_sub_quad(r, dx2, dy1, dx3, dy2, u2, v1, u3, v2, c.tint)

			push_sub_quad(r, dx0, dy2, dx1, dy3, u0, v2, u1, v3, c.tint)
			push_sub_quad(r, dx1, dy2, dx2, dy3, u1, v2, u2, v3, c.tint)
			push_sub_quad(r, dx2, dy2, dx3, dy3, u2, v2, u3, v3, c.tint)

		case .THREE_PATCH_HORIZONTAL:
			push_sub_quad(r, dx0, dy0, dx1, dy3, u0, v0, u1, v3, c.tint)
			push_sub_quad(r, dx1, dy0, dx2, dy3, u1, v0, u2, v3, c.tint)
			push_sub_quad(r, dx2, dy0, dx3, dy3, u2, v0, u3, v3, c.tint)

		case .THREE_PATCH_VERTICAL:
			push_sub_quad(r, dx0, dy0, dx3, dy1, u0, v0, u3, v1, c.tint)
			push_sub_quad(r, dx0, dy1, dx3, dy2, u0, v1, u3, v2, c.tint)
			push_sub_quad(r, dx0, dy2, dx3, dy3, u0, v2, u3, v3, c.tint)
		}
		return
	}

	src := c.source
	if src.width <= 0 || src.height <= 0 {
		src = ui.Rect{0, 0, tex_w, tex_h}
	}

	dest := c.dest
	u0 := src.x / tex_w
	v0 := src.y / tex_h
	u1 := (src.x + src.width) / tex_w
	v1 := (src.y + src.height) / tex_h

	switch c.fit {
	case .Stretch:
		push_sub_quad(
			r,
			dest.x,
			dest.y,
			dest.x + dest.width,
			dest.y + dest.height,
			u0,
			v0,
			u1,
			v1,
			c.tint,
		)

	case .Contain:
		src_aspect := src.height > 0 ? (src.width / src.height) : 1.0
		dest_aspect := dest.height > 0 ? (dest.width / dest.height) : 1.0
		render_w, render_h, render_x, render_y: f32
		if dest_aspect > src_aspect {
			render_h = dest.height
			render_w = dest.height * src_aspect
			render_x = dest.x + (dest.width - render_w) * 0.5
			render_y = dest.y
		} else {
			render_w = dest.width
			render_h = src_aspect > 0 ? (dest.width / src_aspect) : dest.height
			render_x = dest.x
			render_y = dest.y + (dest.height - render_h) * 0.5
		}
		push_sub_quad(
			r,
			render_x,
			render_y,
			render_x + render_w,
			render_y + render_h,
			u0,
			v0,
			u1,
			v1,
			c.tint,
		)

	case .Cover:
		src_aspect := src.height > 0 ? (src.width / src.height) : 1.0
		dest_aspect := dest.height > 0 ? (dest.width / dest.height) : 1.0
		nu0, nv0, nu1, nv1: f32
		if dest_aspect > src_aspect {
			visible_h :=
				dest_aspect > 0 ? (src.width / dest_aspect) : src.height
			crop_y := (src.height - visible_h) * 0.5
			nu0 = u0
			nu1 = u1
			nv0 = (src.y + crop_y) / tex_h
			nv1 = (src.y + crop_y + visible_h) / tex_h
		} else {
			visible_w := src.height * dest_aspect
			crop_x := (src.width - visible_w) * 0.5
			nu0 = (src.x + crop_x) / tex_w
			nu1 = (src.x + crop_x + visible_w) / tex_w
			nv0 = v0
			nv1 = v1
		}
		push_sub_quad(
			r,
			dest.x,
			dest.y,
			dest.x + dest.width,
			dest.y + dest.height,
			nu0,
			nv0,
			nu1,
			nv1,
			c.tint,
		)

	case .Center:
		render_w := min(src.width, dest.width)
		render_h := min(src.height, dest.height)
		render_x := dest.x + (dest.width - render_w) * 0.5
		render_y := dest.y + (dest.height - render_h) * 0.5
		crop_x := (src.width - render_w) * 0.5
		crop_y := (src.height - render_h) * 0.5
		nu0 := (src.x + crop_x) / tex_w
		nv0 := (src.y + crop_y) / tex_h
		nu1 := (src.x + crop_x + render_w) / tex_w
		nv1 := (src.y + crop_y + render_h) / tex_h
		push_sub_quad(
			r,
			render_x,
			render_y,
			render_x + render_w,
			render_y + render_h,
			nu0,
			nv0,
			nu1,
			nv1,
			c.tint,
		)
	}
}

@(private = "file")
draw_text_line :: proc(
	r: ^UI_Renderer,
	font: ^UI_Sokol_Font,
	text: string,
	start_x, start_y: f32,
	scale_font: f32,
	spacing: f32,
	color: [4]u8,
) {
	pen_x := start_x
	for ch in text {
		if ch < 32 || ch >= 128 do continue
		bc := font.chardata[ch - 32]
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
			render_image(r, c, view)

		case ui.UI_Text_Command:
			cur := r.scissor_stack[len(r.scissor_stack) - 1]
			font_idx := int(c.font)
			if font_idx < len(r.fonts) {
				font_obj := &r.fonts[font_idx]
				set_active_batch(r, font_obj.view, cur)
				scale_font :=
					font_obj.base_size > 0 ? (c.font_size / font_obj.base_size) : 1.0
				pen_x := c.rect.x
				pen_y := c.rect.y + c.font_size * 0.78

				lines := c.wrapped_lines
				if len(lines) == 0 {
					draw_text_line(
						r,
						font_obj,
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
							font_obj,
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
make_fonts :: ui_renderer_make_fonts
render :: ui_renderer_render
Renderer :: UI_Renderer
Vertex :: UI_Vertex
Font_Desc :: UI_Font_Desc
