package game

import "core:math/linalg"
import shaders "shaders"
import sg "sokol/gfx"

Pipeline_Type :: enum {
	Unlit_Triangles,
	Unlit_Lines,
}

Renderer :: struct {
	pipelines: [Pipeline_Type]sg.Pipeline,
	bindings:  sg.Bindings,
}

renderer_init :: proc(r: ^Renderer) {
	unlit_base_pip_desc: sg.Pipeline_Desc = {
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
	}

	for pip_type in Pipeline_Type {
		pip_desc := unlit_base_pip_desc

		switch pip_type {
		case .Unlit_Lines:
			{
				pip_desc.primitive_type = .LINES
				pip_desc.depth = {
					compare       = .LESS_EQUAL,
					write_enabled = true,
				}
				pip_desc.cull_mode = .NONE
			}
		case .Unlit_Triangles:
			{
				pip_desc.primitive_type = .TRIANGLES
				pip_desc.depth = {
					compare       = .LESS_EQUAL,
					write_enabled = true,
				}
				pip_desc.cull_mode = .BACK
			}
		}

		r.pipelines[pip_type] = sg.make_pipeline(pip_desc)
	}


	// Note: the image, view, and sampler here are not managed
	// and supposed to be cleaned up eventually when game ends
	white_pixel: [4]u8 = {255, 255, 255, 255}

	r.bindings.samplers[shaders.SMP_smp] = sg.make_sampler({})
	r.bindings.views[shaders.VIEW_tex] = sg.make_view({
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
}


Vertex :: struct {
	position: [3]f32,
	color:    [4]u8,
	uv:       [2]u16,
}

draw_debug_wire_mesh :: proc(
	mesh: Mesh,
	position: [3]f32 = {0, 0, 0},
	rotation: quaternion128 = linalg.QUATERNIONF32_IDENTITY,
) {
	draw_mesh_by_buffers(
		mesh.vertex_buffer,
		mesh.debug_wire_index_buffer,
		mesh.debug_wire_index_count,
		.Unlit_Lines,
		position,
		rotation,
	)
}

draw_mesh :: proc(
	mesh: Mesh,
	position: [3]f32 = {0, 0, 0},
	rotation: quaternion128 = linalg.QUATERNIONF32_IDENTITY,
) {
	draw_mesh_by_buffers(
		mesh.vertex_buffer,
		mesh.index_buffer,
		mesh.index_count,
		.Unlit_Triangles,
		position,
		rotation,
	)
}

@(private = "file")
draw_mesh_by_buffers :: proc(
	vbuffer: sg.Buffer,
	ibuffer: sg.Buffer,
	index_count: i32,
	pip_type: Pipeline_Type,
	position: [3]f32 = {0, 0, 0},
	rotation: quaternion128 = linalg.QUATERNIONF32_IDENTITY,
) {
	sg.apply_pipeline(g_state.renderer.pipelines[pip_type])

	model :=
		linalg.matrix4_translate_f32(position) *
		linalg.matrix4_from_quaternion(rotation)

	vs_params: shaders.Vs_Params = {
		mvp = camera_view_projection_matrix(
			g_state.camera,
			g_state.viewport,
		) * model,
	}
	sg.apply_uniforms(
		shaders.UB_vs_params,
		{ptr = &vs_params, size = size_of(vs_params)},
	)

	g_state.renderer.bindings.vertex_buffers[0] = vbuffer
	g_state.renderer.bindings.index_buffer = ibuffer

	sg.apply_bindings(g_state.renderer.bindings)

	sg.draw(0, index_count, 1)
}

mesh_generate_line_indices :: proc(
	tri_indices: []u16,
	allocator := context.temp_allocator,
) -> []u16 {
	tri_count := len(tri_indices) / 3
	line_indices := make([]u16, tri_count * 6, allocator)

	for i in 0 ..< tri_count {
		i0 := tri_indices[i * 3 + 0]
		i1 := tri_indices[i * 3 + 1]
		i2 := tri_indices[i * 3 + 2]

		line_indices[i * 6 + 0] = i0
		line_indices[i * 6 + 1] = i1
		line_indices[i * 6 + 2] = i1
		line_indices[i * 6 + 3] = i2
		line_indices[i * 6 + 4] = i2
		line_indices[i * 6 + 5] = i0
	}

	return line_indices
}
