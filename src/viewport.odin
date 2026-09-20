package game

import linalg "core:math/linalg"
import "shaders"
import sg "sokol/gfx"
import sglue "sokol/glue"

Rect :: struct {
	x:      f32,
	y:      f32,
	width:  f32,
	height: f32,
}

Viewport :: struct {
	base_size:       [2]f32,
	dest_rect:       Rect,
	scale:           f32,
	vmouse_position: [2]f32,
	bg_color:        [4]f32,
	bars_color:      [4]f32,
	bg_pipeline:     sg.Pipeline,
	bg_bindings:     sg.Bindings,
	white_image:     sg.Image,
	white_view:      sg.View,
}

viewport_init :: proc(
	vp: ^Viewport,
	base_size: [2]f32,
	bg_color: [4]f32 = {0.08, 0.10, 0.14, 1.0},
	bars_color: [4]f32 = {0.04, 0.04, 0.05, 1.0},
) {
	vp.base_size = base_size
	vp.vmouse_position = base_size * 0.5
	vp.bg_color = bg_color
	vp.bars_color = bars_color

	bg_pip_desc := sg.Pipeline_Desc {
		shader = sg.make_shader(shaders.unlit_shader_desc(sg.query_backend())),
		index_type = .UINT16,
		layout = {
			attrs = {
				shaders.ATTR_unlit_pos = {buffer_index = 0, format = .FLOAT3},
				shaders.ATTR_unlit_color0 = {
					buffer_index = 0,
					format = .UBYTE4N,
				},
				shaders.ATTR_unlit_texcoord0 = {
					buffer_index = 0,
					format = .SHORT2N,
				},
			},
		},
		cull_mode = .NONE,
		depth = {write_enabled = false, compare = .ALWAYS},
	}
	vp.bg_pipeline = sg.make_pipeline(bg_pip_desc)

	r := u8(clamp(bg_color.r * 255.0, 0, 255))
	g := u8(clamp(bg_color.g * 255.0, 0, 255))
	b := u8(clamp(bg_color.b * 255.0, 0, 255))
	a := u8(clamp(bg_color.a * 255.0, 0, 255))
	color_u32 := u32(r) | (u32(g) << 8) | (u32(b) << 16) | (u32(a) << 24)

	bg_vertices := [4]Vertex {
		{-1.0, -1.0, 0.0, color_u32, 0, 0},
		{1.0, -1.0, 0.0, color_u32, 0, 0},
		{1.0, 1.0, 0.0, color_u32, 0, 0},
		{-1.0, 1.0, 0.0, color_u32, 0, 0},
	}
	bg_indices := [6]u16{0, 1, 2, 0, 2, 3}

	vp.bg_bindings.vertex_buffers[0] = sg.make_buffer({
		data = {ptr = rawptr(&bg_vertices), size = size_of(bg_vertices)},
	})
	vp.bg_bindings.index_buffer = sg.make_buffer({
		usage = {index_buffer = true},
		data = {ptr = rawptr(&bg_indices), size = size_of(bg_indices)},
	})

	white_pixel: [4]u8 = {255, 255, 255, 255}
	vp.white_image = sg.make_image({
		width = 1,
		height = 1,
		pixel_format = .RGBA8,
		data = {
			mip_levels = {
				0 = {ptr = raw_data(white_pixel[:]), size = len(white_pixel)},
			},
		},
	})
	vp.white_view = sg.make_view({texture = {image = vp.white_image}})
	vp.bg_bindings.samplers[shaders.SMP_smp] = sg.make_sampler({})
	vp.bg_bindings.views[shaders.VIEW_tex] = vp.white_view
}

viewport_destroy :: proc(vp: ^Viewport) {
	sg.destroy_view(vp.white_view)
	sg.destroy_image(vp.white_image)
	sg.destroy_sampler(vp.bg_bindings.samplers[shaders.SMP_smp])
	sg.destroy_buffer(vp.bg_bindings.vertex_buffers[0])
	sg.destroy_buffer(vp.bg_bindings.index_buffer)
	sg.destroy_pipeline(vp.bg_pipeline)
}

viewport_update :: proc(vp: ^Viewport, window_size: [2]f32) {
	if window_size.x <= 0 || window_size.y <= 0 {
		return
	}

	vp.scale = min(
		window_size.x / vp.base_size.x,
		window_size.y / vp.base_size.y,
	)

	dest_size := vp.base_size * vp.scale

	vp.dest_rect = {
		x      = (window_size.x - dest_size.x) * 0.5,
		y      = (window_size.y - dest_size.y) * 0.5,
		width  = dest_size.x,
		height = dest_size.y,
	}
}

viewport_begin :: proc(vp: Viewport) {
	sg.begin_pass({
		action = {
			colors = {
				0 = {
					load_action = .CLEAR,
					clear_value = {
						vp.bars_color.r,
						vp.bars_color.g,
						vp.bars_color.b,
						vp.bars_color.a,
					},
				},
			},
		},
		swapchain = sglue.swapchain(),
	})

	viewport_apply(vp)

	bg_vs_params: shaders.Vs_Params = {
		mvp = linalg.MATRIX4F32_IDENTITY,
	}
	sg.apply_pipeline(vp.bg_pipeline)
	sg.apply_bindings(vp.bg_bindings)
	sg.apply_uniforms(
		shaders.UB_vs_params,
		{ptr = &bg_vs_params, size = size_of(bg_vs_params)},
	)
	sg.draw(0, 6, 1)
}

viewport_end :: proc(vp: Viewport) {
	sg.end_pass()
	sg.commit()
}

viewport_apply :: proc(vp: Viewport) {
	sg.apply_viewportf(
		vp.dest_rect.x,
		vp.dest_rect.y,
		vp.dest_rect.width,
		vp.dest_rect.height,
		true,
	)
	sg.apply_scissor_rectf(
		vp.dest_rect.x,
		vp.dest_rect.y,
		vp.dest_rect.width,
		vp.dest_rect.height,
		true,
	)
}

viewport_apply_hardware :: viewport_apply

viewport_handle_mouse_delta :: proc(vp: ^Viewport, delta: [2]f32) {
	if vp.scale <= 0 {
		return
	}
	scaled_delta := delta / vp.scale
	vp.vmouse_position += scaled_delta
	vp.vmouse_position.x = clamp(vp.vmouse_position.x, 0, vp.base_size.x)
	vp.vmouse_position.y = clamp(vp.vmouse_position.y, 0, vp.base_size.y)
}

viewport_screen_to_virtual :: proc(
	vp: Viewport,
	screen_pos: [2]f32,
) -> [2]f32 {
	if vp.scale <= 0 {
		return {}
	}
	vpos := (screen_pos - {vp.dest_rect.x, vp.dest_rect.y}) / vp.scale
	vpos.x = clamp(vpos.x, 0, vp.base_size.x)
	vpos.y = clamp(vpos.y, 0, vp.base_size.y)
	return vpos
}

viewport_get_mouse_position :: proc(vp: Viewport) -> [2]f32 {
	return vp.vmouse_position
}
