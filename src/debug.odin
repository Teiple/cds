package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import mem "core:mem"
import shaders "shaders"
import sg "sokol/gfx"

@(private)
g_track: mem.Tracking_Allocator

Debug_Vertex :: struct {
	pos   : [3]f32,
	color : [4]u8,
	uv    : [2]u16,
}

Debug_Drawer :: struct {
	lines_pipeline     : sg.Pipeline,
	triangles_pipeline : sg.Pipeline,
	lines_buffer       : sg.Buffer,
	triangles_buffer   : sg.Buffer,
	lines_capacity     : int,
	triangles_capacity : int,
	lines              : [dynamic]Debug_Vertex,
	triangles          : [dynamic]Debug_Vertex,
}

debug_track_allocator_init :: proc() {
	mem.tracking_allocator_init(&g_track, context.allocator)
	context.allocator = mem.tracking_allocator(&g_track)
	g_odin_ctx = context
}

debug_track_allocator_stop :: proc() {
	if len(g_track.allocation_map) > 0 {
		fmt.eprintf(
			"=== %v allocations not freed: ===\n",
			len(g_track.allocation_map),
		)
		for _, entry in g_track.allocation_map {
			fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
		}
	}
	if len(g_track.bad_free_array) > 0 {
		fmt.eprintf(
			"=== %v incorrect frees: ===\n",
			len(g_track.bad_free_array),
		)
		for entry in g_track.bad_free_array {
			fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
		}
	}
	mem.tracking_allocator_destroy(&g_track)
}

debug_drawer_init :: proc(d: ^Debug_Drawer, capacity: int = 16384) {

	d.lines_capacity = capacity
	d.triangles_capacity = capacity
	d.lines = make([dynamic]Debug_Vertex, 0, capacity)
	d.triangles = make([dynamic]Debug_Vertex, 0, capacity)

	shader := sg.make_shader(shaders.unlit_shader_desc(sg.query_backend()))

	lines_pip_desc: sg.Pipeline_Desc = {
		shader = shader,
		primitive_type = .LINES,
		depth = {
			compare       = .LESS_EQUAL,
			write_enabled = false,
		},
		cull_mode = .NONE,
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
	d.lines_pipeline = sg.make_pipeline(lines_pip_desc)

	tri_pip_desc: sg.Pipeline_Desc = {
		shader = shader,
		primitive_type = .TRIANGLES,
		depth = {
			compare       = .LESS_EQUAL,
			write_enabled = false,
		},
		cull_mode = .NONE,
		colors = {
			0 = {
				blend = {
					enabled = true,
					src_factor_rgb = .SRC_ALPHA,
					dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
					op_rgb = .ADD,
					src_factor_alpha = .ONE,
					dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
					op_alpha = .ADD,
				},
			},
		},
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
	d.triangles_pipeline = sg.make_pipeline(tri_pip_desc)

	d.lines_buffer = sg.make_buffer({
		usage = {vertex_buffer = true, dynamic_update = true},
		size = uint(capacity * size_of(Debug_Vertex)),
	})
	d.triangles_buffer = sg.make_buffer({
		usage = {vertex_buffer = true, dynamic_update = true},
		size = uint(capacity * size_of(Debug_Vertex)),
	})
}

debug_drawer_destroy :: proc(d: ^Debug_Drawer) {
	sg.destroy_pipeline(d.lines_pipeline)
	sg.destroy_pipeline(d.triangles_pipeline)
	sg.destroy_buffer(d.lines_buffer)
	sg.destroy_buffer(d.triangles_buffer)
	delete(d.lines)
	delete(d.triangles)
}

debug_draw_line :: proc(p0, p1: [3]f32, color: [4]u8 = {255, 255, 255, 255}) {
	d := &g_state.debug_drawer
	append(&d.lines, Debug_Vertex{pos = p0, color = color, uv = {0, 0}})
	append(&d.lines, Debug_Vertex{pos = p1, color = color, uv = {0, 0}})
}

debug_draw_ray :: proc(origin, dir: [3]f32, length: f32 = 1.0, color: [4]u8 = {255, 255, 255, 255}) {
	debug_draw_line(origin, origin + linalg.normalize(dir) * length, color)
}

debug_draw_triangle :: proc(p0, p1, p2: [3]f32, color: [4]u8 = {255, 255, 255, 255}) {
	d := &g_state.debug_drawer
	append(&d.triangles, Debug_Vertex{pos = p0, color = color, uv = {0, 0}})
	append(&d.triangles, Debug_Vertex{pos = p1, color = color, uv = {0, 0}})
	append(&d.triangles, Debug_Vertex{pos = p2, color = color, uv = {0, 0}})
}

debug_draw_quad :: proc(p0, p1, p2, p3: [3]f32, color: [4]u8 = {255, 255, 255, 255}) {
	debug_draw_triangle(p0, p1, p2, color)
	debug_draw_triangle(p0, p2, p3, color)
}

debug_draw_wire_box :: proc(
	center: [3]f32,
	size: [3]f32,
	rot: quaternion128 = linalg.QUATERNIONF32_IDENTITY,
	color: [4]u8 = {255, 255, 255, 255},
) {
	half := size * 0.5
	corners := [8][3]f32 {
		{-half.x, -half.y, -half.z},
		{ half.x, -half.y, -half.z},
		{ half.x,  half.y, -half.z},
		{-half.x,  half.y, -half.z},
		{-half.x, -half.y,  half.z},
		{ half.x, -half.y,  half.z},
		{ half.x,  half.y,  half.z},
		{-half.x,  half.y,  half.z},
	}

	rot_mat := linalg.matrix3_from_quaternion_f32(rot)
	for &c in corners {
		c = center + rot_mat * c
	}

	edges := [12][2]int {
		{0, 1}, {1, 2}, {2, 3}, {3, 0},
		{4, 5}, {5, 6}, {6, 7}, {7, 4},
		{0, 4}, {1, 5}, {2, 6}, {3, 7},
	}

	for e in edges {
		debug_draw_line(corners[e[0]], corners[e[1]], color)
	}
}

debug_draw_box :: proc(
	center: [3]f32,
	size: [3]f32,
	rot: quaternion128 = linalg.QUATERNIONF32_IDENTITY,
	color: [4]u8 = {255, 255, 255, 255},
) {
	half := size * 0.5
	corners := [8][3]f32 {
		{-half.x, -half.y, -half.z},
		{ half.x, -half.y, -half.z},
		{ half.x,  half.y, -half.z},
		{-half.x,  half.y, -half.z},
		{-half.x, -half.y,  half.z},
		{ half.x, -half.y,  half.z},
		{ half.x,  half.y,  half.z},
		{-half.x,  half.y,  half.z},
	}

	rot_mat := linalg.matrix3_from_quaternion_f32(rot)
	for &c in corners {
		c = center + rot_mat * c
	}

	debug_draw_quad(corners[4], corners[5], corners[6], corners[7], color)
	debug_draw_quad(corners[1], corners[0], corners[3], corners[2], color)
	debug_draw_quad(corners[3], corners[2], corners[6], corners[7], color)
	debug_draw_quad(corners[0], corners[1], corners[5], corners[4], color)
	debug_draw_quad(corners[1], corners[5], corners[6], corners[2], color)
	debug_draw_quad(corners[4], corners[0], corners[3], corners[7], color)
}

debug_draw_wire_sphere :: proc(
	center: [3]f32,
	radius: f32,
	segments: int = 24,
	color: [4]u8 = {255, 255, 255, 255},
) {
	step := (2.0 * math.PI) / f32(segments)

	for i in 0 ..< segments {
		a0 := f32(i) * step
		a1 := f32(i + 1) * step

		c0, s0 := math.cos(a0) * radius, math.sin(a0) * radius
		c1, s1 := math.cos(a1) * radius, math.sin(a1) * radius

		debug_draw_line(center + {c0, 0, s0}, center + {c1, 0, s1}, color)
		debug_draw_line(center + {c0, s0, 0}, center + {c1, s1, 0}, color)
		debug_draw_line(center + {0, c0, s0}, center + {0, c1, s1}, color)
	}
}

debug_draw_sphere :: proc(
	center: [3]f32,
	radius: f32,
	rings: int = 12,
	sectors: int = 16,
	color: [4]u8 = {255, 255, 255, 255},
) {
	r_step := math.PI / f32(rings)
	s_step := (2.0 * math.PI) / f32(sectors)

	for r in 0 ..< rings {
		lat0 := math.PI * 0.5 - f32(r) * r_step
		lat1 := math.PI * 0.5 - f32(r + 1) * r_step

		y0 := radius * math.sin(lat0)
		zr0 := radius * math.cos(lat0)

		y1 := radius * math.sin(lat1)
		zr1 := radius * math.cos(lat1)

		for s in 0 ..< sectors {
			lon0 := f32(s) * s_step
			lon1 := f32(s + 1) * s_step

			x00 := zr0 * math.cos(lon0)
			z00 := zr0 * math.sin(lon0)

			x10 := zr1 * math.cos(lon0)
			z10 := zr1 * math.sin(lon0)

			x01 := zr0 * math.cos(lon1)
			z01 := zr0 * math.sin(lon1)

			x11 := zr1 * math.cos(lon1)
			z11 := zr1 * math.sin(lon1)

			p00 := center + {x00, y0, z00}
			p10 := center + {x10, y1, z10}
			p01 := center + {x01, y0, z01}
			p11 := center + {x11, y1, z11}

			if r == 0 {
				debug_draw_triangle(p00, p10, p11, color)
			} else if r == rings - 1 {
				debug_draw_triangle(p00, p10, p01, color)
			} else {
				debug_draw_quad(p00, p10, p11, p01, color)
			}
		}
	}
}

debug_draw_grid :: proc(slices: int = 10, spacing: f32 = 1.0, color: [4]u8 = {100, 100, 100, 255}) {
	half_extent := f32(slices) * spacing * 0.5
	for i in 0 ..= slices {
		pos := -half_extent + f32(i) * spacing
		debug_draw_line({pos, 0, -half_extent}, {pos, 0, half_extent}, color)
		debug_draw_line({-half_extent, 0, pos}, {half_extent, 0, pos}, color)
	}
}

debug_render :: proc(d: ^Debug_Drawer, camera: ^Camera, vp: ^Viewport) {
	if len(d.triangles) == 0 && len(d.lines) == 0 do return

	vs_params: shaders.Vs_Params = {
		mvp = camera_view_projection_matrix(camera, vp),
	}

	if len(d.triangles) > 0 {
		if len(d.triangles) > d.triangles_capacity {
			sg.destroy_buffer(d.triangles_buffer)
			d.triangles_capacity = max(d.triangles_capacity * 2, len(d.triangles))
			d.triangles_buffer = sg.make_buffer({
				usage = {vertex_buffer = true, dynamic_update = true},
				size = uint(d.triangles_capacity * size_of(Debug_Vertex)),
			})
		}

		sg.update_buffer(
			d.triangles_buffer,
			{
				ptr = raw_data(d.triangles),
				size = size_of(Debug_Vertex) * len(d.triangles),
			},
		)

		sg.apply_pipeline(d.triangles_pipeline)
		sg.apply_uniforms(
			shaders.UB_vs_params,
			{ptr = &vs_params, size = size_of(vs_params)},
		)

		bindings := g_state.renderer.bindings
		bindings.vertex_buffers[0] = d.triangles_buffer
		bindings.index_buffer = {}
		sg.apply_bindings(bindings)

		sg.draw(0, i32(len(d.triangles)), 1)
		clear(&d.triangles)
	}

	if len(d.lines) > 0 {
		if len(d.lines) > d.lines_capacity {
			sg.destroy_buffer(d.lines_buffer)
			d.lines_capacity = max(d.lines_capacity * 2, len(d.lines))
			d.lines_buffer = sg.make_buffer({
				usage = {vertex_buffer = true, dynamic_update = true},
				size = uint(d.lines_capacity * size_of(Debug_Vertex)),
			})
		}

		sg.update_buffer(
			d.lines_buffer,
			{
				ptr = raw_data(d.lines),
				size = size_of(Debug_Vertex) * len(d.lines),
			},
		)

		sg.apply_pipeline(d.lines_pipeline)
		sg.apply_uniforms(
			shaders.UB_vs_params,
			{ptr = &vs_params, size = size_of(vs_params)},
		)

		bindings := g_state.renderer.bindings
		bindings.vertex_buffers[0] = d.lines_buffer
		bindings.index_buffer = {}
		sg.apply_bindings(bindings)

		sg.draw(0, i32(len(d.lines)), 1)
		clear(&d.lines)
	}
}
