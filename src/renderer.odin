package game

import shaders "shaders"
import sg "sokol/gfx"


Vertex :: struct {
	position: [3]f32,
	color:    [4]u8,
	uv:       [2]u16,
}

draw_mesh :: proc(bindings: ^sg.Bindings, mesh: Mesh) {
	bindings.vertex_buffers[0] = mesh.vertex_buffer
	bindings.index_buffer = mesh.index_buffer

	sg.apply_bindings(bindings^)

	sg.draw(0, mesh.index_count, 1)
}

make_default_pipeline_and_bindings :: proc(
) -> (
	pipeline: sg.Pipeline,
	bindings: sg.Bindings,
) {
	pipeline = sg.make_pipeline({
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
		cull_mode = .BACK,
		depth = {write_enabled = true, compare = .LESS_EQUAL},
	})

	// Note: the image, view, and sampler here are not managed
	// and supposed to be cleaned up eventually when game ends
	white_pixel: [4]u8 = {255, 255, 255, 255}

	bindings.samplers[shaders.SMP_smp] = sg.make_sampler({})
	bindings.views[shaders.VIEW_tex] = sg.make_view({
		texture = {
			image = sg.make_image({
				width = 1,
				height = 1,
				pixel_format = .RGBA8,
				data = {
					mip_levels = {
						0 = {
							ptr = raw_data(white_pixel[:]),
							size = len(white_pixel),
						},
					},
				},
			}),
		},
	})

	return pipeline, bindings
}
