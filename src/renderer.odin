package game

import "core:math/linalg"
import shaders "shaders"
import sg "sokol/gfx"

Pipeline_Type :: enum {
	Unlit_Triangles,
	Unlit_Lines,
	Skinned_Triangles,
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
		case .Skinned_Triangles:
			{
				pip_desc.shader = sg.make_shader(shaders.skinned_shader_desc(sg.query_backend()))
				pip_desc.primitive_type = .TRIANGLES
				pip_desc.depth = {
					compare       = .LESS_EQUAL,
					write_enabled = true,
				}
				pip_desc.cull_mode = .BACK
				pip_desc.layout = {
					attrs = {
						shaders.ATTR_skinned_pos = {buffer_index = 0, format = .FLOAT3},
						shaders.ATTR_skinned_color0 = {
							buffer_index = 0,
							format = .UBYTE4N,
						},
						shaders.ATTR_skinned_texcoord0 = {
							buffer_index = 0,
							format = .SHORT2N,
						},
						shaders.ATTR_skinned_joints = {
							buffer_index = 0,
							format = .FLOAT4,
						},
						shaders.ATTR_skinned_weights = {
							buffer_index = 0,
							format = .FLOAT4,
						},
					},
				}
			}
		}

		r.pipelines[pip_type] = sg.make_pipeline(pip_desc)
	}


	// Note: the image, view, and sampler here are not managed
	// and supposed to be cleaned up eventually when game ends
	white_pixel: [4]u8 = {255, 255, 255, 255}

	r.bindings.samplers[shaders.SMP_smp] = sg.make_sampler({})
	r.bindings.samplers[shaders.SMP_skinned_smp] = r.bindings.samplers[shaders.SMP_smp]
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
	r.bindings.views[shaders.VIEW_skinned_tex] = r.bindings.views[shaders.VIEW_tex]
}


Vertex :: struct {
	position: [3]f32,
	color:    [4]u8,
	uv:       [2]u16,
}

Skinned_Vertex :: struct {
	position: [3]f32,
	color:    [4]u8,
	uv:       [2]u16,
	joints:   [4]f32,
	weights:  [4]f32,
}

Skinned_Mesh :: struct {
	vertex_buffer: sg.Buffer,
	index_buffer:  sg.Buffer,
	index_count:   i32,
}

skinned_mesh_make_from_data :: proc(vertices: []Skinned_Vertex, indices: []u16) -> Skinned_Mesh {
	mesh: Skinned_Mesh

	mesh.vertex_buffer = sg.make_buffer({
		data = {
			ptr = raw_data(vertices),
			size = len(vertices) * size_of(Skinned_Vertex),
		},
	})

	mesh.index_buffer = sg.make_buffer({
		usage = {index_buffer = true},
		data = {ptr = raw_data(indices), size = len(indices) * size_of(u16)},
	})
	mesh.index_count = i32(len(indices))

	return mesh
}

skinned_mesh_destroy :: proc(m: ^Skinned_Mesh) {
	sg.destroy_buffer(m.vertex_buffer)
	sg.destroy_buffer(m.index_buffer)
}

draw_debug_wire_mesh :: proc(
	mesh: Mesh,
	camera: ^Camera,
	vp: ^Viewport,
	position: [3]f32 = {0, 0, 0},
	rotation: quaternion128 = linalg.QUATERNIONF32_IDENTITY,
) {
	draw_mesh_wireframe_matrix(
		mesh,
		linalg.matrix4_translate_f32(position) * linalg.matrix4_from_quaternion(rotation),
		camera,
		vp,
	)
}

draw_mesh :: proc(
	mesh: Mesh,
	camera: ^Camera,
	vp: ^Viewport,
	position: [3]f32 = {0, 0, 0},
	rotation: quaternion128 = linalg.QUATERNIONF32_IDENTITY,
) {
	draw_mesh_matrix(
		mesh,
		linalg.matrix4_translate_f32(position) * linalg.matrix4_from_quaternion(rotation),
		camera,
		vp,
	)
}

draw_mesh_matrix :: proc(
	mesh: Mesh,
	model_matrix: matrix[4, 4]f32,
	camera: ^Camera,
	vp: ^Viewport,
) {
	draw_mesh_by_buffers(
		mesh.vertex_buffer,
		mesh.index_buffer,
		mesh.index_count,
		.Unlit_Triangles,
		model_matrix,
		camera,
		vp,
	)
}

draw_mesh_wireframe_matrix :: proc(
	mesh: Mesh,
	model_matrix: matrix[4, 4]f32,
	camera: ^Camera,
	vp: ^Viewport,
) {
	draw_mesh_by_buffers(
		mesh.vertex_buffer,
		mesh.debug_wire_index_buffer,
		mesh.debug_wire_index_count,
		.Unlit_Lines,
		model_matrix,
		camera,
		vp,
	)
}

draw_skinned_mesh_matrix :: proc(
	mesh: Skinned_Mesh,
	model_matrix: matrix[4, 4]f32,
	bones: []matrix[4, 4]f32,
	camera: ^Camera,
	vp: ^Viewport,
) {
	sg.apply_pipeline(g_state.renderer.pipelines[.Skinned_Triangles])

	vs_params: shaders.Vs_Skinned_Params
	vs_params.mvp = camera_view_projection_matrix(camera, vp) * model_matrix

	bone_count := min(len(bones), 64)
	for i in 0 ..< bone_count {
		vs_params.bones[i] = bones[i]
	}

	sg.apply_uniforms(
		shaders.UB_vs_skinned_params,
		{ptr = &vs_params, size = size_of(vs_params)},
	)

	g_state.renderer.bindings.vertex_buffers[0] = mesh.vertex_buffer
	g_state.renderer.bindings.index_buffer = mesh.index_buffer

	sg.apply_bindings(g_state.renderer.bindings)

	sg.draw(0, mesh.index_count, 1)
}

@(private = "file")
draw_mesh_by_buffers :: proc(
	vbuffer: sg.Buffer,
	ibuffer: sg.Buffer,
	index_count: i32,
	pip_type: Pipeline_Type,
	model_matrix: matrix[4, 4]f32,
	camera: ^Camera,
	vp: ^Viewport,
) {
	sg.apply_pipeline(g_state.renderer.pipelines[pip_type])

	vs_params: shaders.Vs_Params = {
		mvp = camera_view_projection_matrix(camera, vp) * model_matrix,
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